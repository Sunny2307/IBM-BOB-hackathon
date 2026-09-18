"""Explainable composite risk scoring — deliberately NOT a trained ML model.

Why rule-based: it's defensible under judge Q&A in one sentence ("z-score
anomaly on each sensor's own 15-day baseline, plus a weather-severity term,
plus a historical-incident-rate term for similar assets"), needs no training
data legitimacy argument, and every number on screen traces back to a named,
inspectable component. See docs/solution-overview.md for the write-up.

Score = base_floor + sensor_anomaly (0-55) + weather_risk (0-25) +
        historical_base_rate (0-20), clipped to [0, 100].

Explicitly upgradeable: swap this module for a trained model once real
historical failure labels exist — callers only depend on compute_risk_score's
return shape, not its internals.
"""

import statistics
from datetime import date, datetime

from app.services import data_loader

Z_CAP = 4.0
BASE_FLOOR = 5.0

SENSOR_WEIGHTS = {
    "partial_discharge": 18.0,
    "oil_quality": 18.0,
    "vibration": 10.0,
    "temperature": 9.0,
}
SENSOR_LABELS = {
    "partial_discharge": "Partial Discharge",
    "oil_quality": "Oil Quality",
    "vibration": "Vibration",
    "temperature": "Temperature",
}
# Direction of "bad" change for each metric
BAD_DIRECTION_IS_INCREASE = {
    "partial_discharge": True,
    "oil_quality": False,  # bad = decreasing
    "vibration": True,
    "temperature": True,
}

WEATHER_MAX = 25.0
# Onset -> saturation for each weather threat. Below the first number the
# threat adds nothing; at the second it is at full weight.
WIND_GUST_MPH_RANGE = (20.0, 60.0)      # overhead-line / structure damage
PRECIP_PROBABILITY_RANGE = (0.10, 0.80)  # flashover, flooding, access loss
HEAT_F_RANGE = (85.0, 110.0)             # thermal derating on loaded equipment
# A threat 6 days out is real but less actionable than one tomorrow.
PROXIMITY_DECAY_PER_DAY = 0.08

HISTORICAL_MAX = 20.0
BASE_FAILURE_RATE_NORMALIZER = 0.09


def _age_bucket(asset: dict) -> str:
    age = date.today().year - asset["install_year"]
    if age < 10:
        return "new"
    if age < 25:
        return "mid"
    return "old"


def _metric_anomaly(series: list[dict], metric: str) -> tuple[float, float, float, float]:
    """Returns (anomaly_fraction 0-1, pct_change, baseline_mean, recent_mean)."""
    values = [row[metric] for row in series]
    if len(values) < 6:
        return 0.0, 0.0, 0.0, 0.0

    baseline = values[:15] if len(values) >= 15 else values[: len(values) // 2]
    recent = values[-3:]

    baseline_mean = statistics.fmean(baseline)
    baseline_std = statistics.pstdev(baseline) if len(baseline) > 1 else 0.0
    recent_mean = statistics.fmean(recent)

    epsilon = max(baseline_std, 0.05 * max(abs(baseline_mean), 1.0))
    bad_is_increase = BAD_DIRECTION_IS_INCREASE[metric]
    raw_z = (recent_mean - baseline_mean) / epsilon if bad_is_increase else (baseline_mean - recent_mean) / epsilon

    anomaly_fraction = max(0.0, min(1.0, raw_z / Z_CAP))
    pct_change = ((recent_mean - baseline_mean) / baseline_mean * 100) if baseline_mean else 0.0
    return anomaly_fraction, pct_change, baseline_mean, recent_mean


def compute_sensor_components(asset_id: str) -> list[dict]:
    series = data_loader.get_sensor_series(asset_id)
    components = []
    for metric, weight in SENSOR_WEIGHTS.items():
        anomaly_fraction, pct_change, baseline_mean, recent_mean = _metric_anomaly(series, metric)
        contribution = round(anomaly_fraction * weight, 1)
        label = SENSOR_LABELS[metric]

        if anomaly_fraction > 0.55:
            direction = "risen" if pct_change >= 0 else "fallen"
            explanation = (
                f"{label} has {direction} {abs(round(pct_change))}% versus its 15-day "
                f"baseline ({baseline_mean:.1f} → {recent_mean:.1f}), consistent with "
                f"developing equipment stress."
            )
        elif anomaly_fraction > 0.2:
            explanation = f"{label} shows a mild deviation from baseline; worth monitoring, not yet alarming."
        else:
            explanation = f"{label} is stable within its normal operating range."

        components.append(
            {
                "factor": f"Sensor Anomaly — {label}",
                "contribution": contribution,
                "explanation": explanation,
            }
        )
    return components


def _ramp(value: float, low: float, high: float) -> float:
    """0 below `low`, 1 at/above `high`, linear between. The shape every
    weather threat uses, so one function covers all three."""
    if high <= low:
        return 0.0
    return max(0.0, min(1.0, (value - low) / (high - low)))


def _day_threat(day: dict) -> tuple[float, str]:
    """Severity 0-1 for one forecast day, plus the name of what drives it.

    The worst single threat governs, with a smaller additive allowance for the
    others — a day that is both windy and soaking is worse than either alone,
    but not double.
    """
    threats = {
        "wind": _ramp(day["wind_speed_mph"], *WIND_GUST_MPH_RANGE),
        "precipitation": _ramp(day["precip_probability"], *PRECIP_PROBABILITY_RANGE),
        "heat": _ramp(day.get("temp_high_f", 0.0), *HEAT_F_RANGE),
    }
    driver = max(threats, key=threats.get)
    worst = threats[driver]
    others = sum(v for k, v in threats.items() if k != driver)
    return min(1.0, worst + 0.25 * others), driver


def _weather_vulnerability(asset: dict) -> float:
    """How much harder the same weather hits THIS asset. An N-1-redundant
    substation riding out a storm is not the same risk as a 40-year-old
    transformer with no backup, and a flat regional weather score cannot tell
    them apart."""
    age = date.today().year - asset["install_year"]
    factor = 1.0
    if age >= 25:
        factor += 0.15
    if asset.get("has_redundancy"):
        factor -= 0.25
    return max(0.6, min(1.25, factor))


def compute_weather_component(asset: dict) -> dict:
    """Continuous weather risk for one asset, from its region's 7-day forecast.

    Deliberately NOT a binary "storm somewhere this week -> full points": that
    gave every asset in a region the same 25 points whether the storm was
    tomorrow or Friday, and whether the asset was a new redundant substation
    or a 40-year-old transformer. Here severity scales with how bad the worst
    day is, how soon it is, and how vulnerable this particular asset is --
    and heat counts, because a heat wave pushing loaded equipment toward its
    thermal limit is a real failure driver even when the sky is clear.
    """
    region = asset["region"]
    forecast = data_loader.get_weather_forecast(region)
    if not forecast:
        return {
            "factor": "Weather Risk",
            "contribution": 0.0,
            "explanation": f"No forecast data available for {region}.",
        }

    vulnerability = _weather_vulnerability(asset)

    best_day, best_weighted, best_driver = None, 0.0, "wind"
    for day_index, day in enumerate(forecast):
        severity, driver = _day_threat(day)
        weighted = severity * max(0.4, 1.0 - PROXIMITY_DECAY_PER_DAY * day_index)
        if weighted >= best_weighted:
            best_day, best_weighted, best_driver = day, weighted, driver

    contribution = round(min(WEATHER_MAX, WEATHER_MAX * best_weighted * vulnerability), 1)

    if contribution <= 1.0:
        explanation = f"Benign 7-day forecast for {region}; negligible added weather risk."
    else:
        driver_phrase = {
            "wind": f"wind gusting to {best_day['wind_speed_mph']} mph",
            "precipitation": f"{round(best_day['precip_probability'] * 100)}% precipitation probability",
            "heat": f"a {best_day['temp_high_f']}°F high driving thermal stress on loaded equipment",
        }[best_driver]
        storm_note = "Storm-level conditions" if best_day["storm_warning"] else "Elevated conditions"
        vuln_note = ""
        if vulnerability > 1.0:
            vuln_note = " This asset is weighted up as ageing with no redundancy."
        elif vulnerability < 1.0:
            vuln_note = " This asset is weighted down for having N-1 redundancy."
        explanation = (
            f"{storm_note} forecast for {region} on {best_day['date']}: {driver_phrase}"
            f" — compounds any existing equipment stress.{vuln_note}"
        )

    return {"factor": "Weather Risk", "contribution": contribution, "explanation": explanation}


def compute_historical_component(asset: dict) -> dict:
    base_rate = asset["base_failure_rate"]
    normalized = max(0.0, min(1.0, base_rate / BASE_FAILURE_RATE_NORMALIZER))
    contribution = round(normalized * HISTORICAL_MAX, 1)

    bucket = _age_bucket(asset)
    similar_incidents = data_loader.get_incidents_by_type_and_age(asset["type"], bucket)
    age = date.today().year - asset["install_year"]

    explanation = (
        f"{asset['type'].title()}s of similar age ({age} yrs, '{bucket}' bracket) show "
        f"{len(similar_incidents)} historical incidents in the record; base failure rate "
        f"estimated at {base_rate * 100:.1f}%/yr from age and asset class."
    )
    return {"factor": "Historical Incident Rate", "contribution": contribution, "explanation": explanation}


def compute_risk_breakdown(asset_id: str) -> dict | None:
    asset = data_loader.get_asset(asset_id)
    if asset is None:
        return None

    sensor_components = compute_sensor_components(asset_id)
    weather_component = compute_weather_component(asset)
    historical_component = compute_historical_component(asset)

    base_component = {
        "factor": "Baseline Operational Risk",
        "contribution": BASE_FLOOR,
        "explanation": "Fixed floor reflecting that any energized grid asset carries nonzero risk.",
    }

    components = [base_component] + sensor_components + [weather_component, historical_component]
    raw_score = sum(c["contribution"] for c in components)
    risk_score = round(max(0.0, min(100.0, raw_score)), 1)

    series = data_loader.get_sensor_series(asset_id)
    sensor_series = {
        "temperature": [{"date": r["date"], "value": r["temperature"]} for r in series],
        "vibration": [{"date": r["date"], "value": r["vibration"]} for r in series],
        "partial_discharge": [{"date": r["date"], "value": r["partial_discharge"]} for r in series],
        "oil_quality": [{"date": r["date"], "value": r["oil_quality"]} for r in series],
    }
    weather_context = {
        "region": asset["region"],
        "forecast": data_loader.get_weather_forecast(asset["region"]),
    }

    return {
        "asset_id": asset_id,
        "risk_score": risk_score,
        "risk_tier": risk_tier_for(risk_score),
        "components": components,
        "sensor_series": sensor_series,
        "weather_context": weather_context,
    }


def risk_tier_for(risk_score: float) -> str:
    if risk_score >= 75:
        return "Critical"
    if risk_score >= 50:
        return "High"
    if risk_score >= 25:
        return "Medium"
    return "Low"


def compute_risk_score(asset_id: str) -> float:
    breakdown = compute_risk_breakdown(asset_id)
    return breakdown["risk_score"] if breakdown else 0.0


def score_all_assets() -> list[dict]:
    """Returns every asset dict enriched with risk_score + risk_tier — the
    shape consumed by the /assets endpoint and the dashboard."""
    scored = []
    for asset in data_loader.get_assets():
        breakdown = compute_risk_breakdown(asset["asset_id"])
        enriched = dict(asset)
        enriched["risk_score"] = breakdown["risk_score"]
        enriched["risk_tier"] = breakdown["risk_tier"]
        scored.append(enriched)
    return scored
