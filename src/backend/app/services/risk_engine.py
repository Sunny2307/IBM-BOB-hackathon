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
WEATHER_STORM_CEILING = 25.0
WEATHER_CALM_CEILING = 15.0

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


def compute_weather_component(region: str) -> dict:
    forecast = data_loader.get_weather_forecast(region)
    storm_days = [d for d in forecast if d["storm_warning"]]

    if storm_days:
        storm = storm_days[0]
        contribution = WEATHER_STORM_CEILING
        explanation = (
            f"Storm warning forecast for {region} on {storm['date']}: wind "
            f"{storm['wind_speed_mph']} mph, precipitation probability "
            f"{round(storm['precip_probability'] * 100)}% — compounds any existing "
            f"equipment stress in this region."
        )
    else:
        max_wind = max((d["wind_speed_mph"] for d in forecast), default=0.0)
        max_precip = max((d["precip_probability"] for d in forecast), default=0.0)
        severity = max(0.0, min(1.0, 0.4 * (max_wind / 30.0) + 0.6 * (max_precip / 0.5)))
        contribution = round(severity * WEATHER_CALM_CEILING, 1)
        if severity > 0.4:
            explanation = (
                f"No storm warning for {region}, but elevated wind/precipitation in the "
                f"7-day forecast add modest risk."
            )
        else:
            explanation = f"Calm 7-day forecast for {region}; minimal added weather risk."

    return {"factor": "Weather Risk", "contribution": round(contribution, 1), "explanation": explanation}


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
    weather_component = compute_weather_component(asset["region"])
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
