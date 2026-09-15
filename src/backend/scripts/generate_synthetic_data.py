"""
Generates internally-consistent synthetic data for Grid Failure Advisor:
  - assets.json              : 50 grid assets (transformers + substations)
  - sensor_readings.json     : 30-day daily sensor series per asset, with a
                                degrading trend injected into ~17% of assets
                                over the last 10-14 days (the "failure
                                signature weeks in advance" story)
  - weather_forecast.json    : 7-day forecast per region, with 1-2 severe
                                weather events deliberately placed in regions
                                that also contain degrading assets (the
                                "compounding risk" story)
  - historical_incidents.csv : 30-50 past incidents, weighted toward older /
                                higher-base-failure-rate assets

Deterministic (fixed seed) so the demo is reproducible and the narrative
(top-ranked asset has both a bad sensor trend AND an upcoming storm in its
region) is guaranteed to hold every time this is run.

Run: python scripts/generate_synthetic_data.py
"""

import json
import csv
import random
import math
from datetime import date, timedelta
from pathlib import Path

random.seed(42)

OUT_DIR = Path(__file__).resolve().parent.parent / "app" / "data" / "generated"
OUT_DIR.mkdir(parents=True, exist_ok=True)

TODAY = date.today()

REGION_COORDS = {
    "North Valley": (37.90, -121.30),
    "Riverside": (33.95, -117.40),
    "Eastgate": (39.10, -84.50),
    "Lakeshore": (41.90, -87.60),
    "Highland": (39.70, -104.90),
    "Bayview": (37.70, -122.40),
}
REGIONS = list(REGION_COORDS.keys())

CAUSES = ["equipment aging", "weather event", "mechanical failure", "electrical fault", "overload"]

N_ASSETS = 50
DEGRADING_FRACTION = 0.18
SENSOR_DAYS = 30
FORECAST_DAYS = 7


def jitter(v, spread):
    return v + random.uniform(-spread, spread)


def make_assets():
    assets = []
    region_counters = {r: 0 for r in REGIONS}
    for i in range(1, N_ASSETS + 1):
        region = random.choice(REGIONS)
        region_counters[region] += 1
        asset_type = "transformer" if random.random() < 0.7 else "substation"
        install_year = random.randint(1985, 2023)
        age = TODAY.year - install_year

        if asset_type == "transformer":
            capacity_mva = round(random.uniform(5, 50), 1)
            customers_served = random.randint(500, 15000)
        else:
            capacity_mva = round(random.uniform(50, 200), 1)
            customers_served = random.randint(5000, 60000)

        has_hospital_critical_load = random.random() < 0.08
        has_water_treatment_load = random.random() < 0.06
        has_redundancy = random.random() < 0.40

        # grid_impact_severity: log-scaled customers_served (dominant factor)
        # + bump for critical downstream loads - reduction if N-1 redundancy exists
        severity = 2.0 + 6.0 * (math.log10(customers_served + 1) / math.log10(60001))
        if has_hospital_critical_load:
            severity += 1.5
        if has_water_treatment_load:
            severity += 1.0
        if has_redundancy:
            severity -= 1.5
        severity = max(1, min(10, round(severity)))

        # base_failure_rate: older assets and substations skew higher
        base_failure_rate = round(
            0.015 + age * 0.0016 + (0.01 if asset_type == "substation" else 0.0), 4
        )

        base_lat, base_lon = REGION_COORDS[region]

        assets.append(
            {
                "asset_id": f"AST-{i:03d}",
                "name": f"{region} {asset_type.title()} {region_counters[region]:02d}",
                "type": asset_type,
                "lat": round(jitter(base_lat, 0.15), 4),
                "lon": round(jitter(base_lon, 0.15), 4),
                "region": region,
                "install_year": install_year,
                "capacity_mva": capacity_mva,
                "customers_served": customers_served,
                "grid_impact_severity": severity,
                "base_failure_rate": base_failure_rate,
                "has_hospital_critical_load": has_hospital_critical_load,
                "has_water_treatment_load": has_water_treatment_load,
                "has_redundancy": has_redundancy,
            }
        )
    return assets


def make_sensor_readings(assets):
    n_degrading = max(1, round(len(assets) * DEGRADING_FRACTION))
    degrading_ids = set(a["asset_id"] for a in random.sample(assets, n_degrading))

    readings = {}
    for asset in assets:
        aid = asset["asset_id"]
        is_degrading = aid in degrading_ids
        degrade_days = random.randint(10, 14) if is_degrading else 0

        temp_base = 45 + (5 if asset["type"] == "substation" else 0)
        vib_base = 2.0
        pd_base = 80.0
        oil_base = 85.0

        series = []
        for d_offset in range(SENSOR_DAYS - 1, -1, -1):
            day = TODAY - timedelta(days=d_offset)
            days_from_end = SENSOR_DAYS - 1 - d_offset  # 0 = oldest, 29 = today

            temperature = temp_base + random.gauss(0, 1.5)
            vibration = vib_base + random.gauss(0, 0.2)
            partial_discharge = pd_base + random.gauss(0, 8)
            oil_quality = oil_base + random.gauss(0, 3)

            if is_degrading:
                days_into_ramp = days_from_end - (SENSOR_DAYS - degrade_days)
                if days_into_ramp >= 0:
                    ramp = days_into_ramp / max(1, degrade_days - 1)  # 0..1
                    temperature += 18 * ramp
                    vibration += 2.5 * ramp
                    partial_discharge += 70 * ramp
                    oil_quality -= 35 * ramp

            oil_quality = max(0, min(100, oil_quality))
            vibration = max(0, vibration)
            partial_discharge = max(0, partial_discharge)

            series.append(
                {
                    "date": day.isoformat(),
                    "temperature": round(temperature, 1),
                    "vibration": round(vibration, 2),
                    "partial_discharge": round(partial_discharge, 1),
                    "oil_quality": round(oil_quality, 1),
                }
            )
        readings[aid] = series

    return readings, degrading_ids


def make_weather_forecast(assets, degrading_ids):
    # Count degrading assets per region to prioritize storm placement there
    degrading_region_counts = {}
    for a in assets:
        if a["asset_id"] in degrading_ids:
            degrading_region_counts[a["region"]] = degrading_region_counts.get(a["region"], 0) + 1

    storm_priority_regions = sorted(
        degrading_region_counts.keys(), key=lambda r: -degrading_region_counts[r]
    )
    storm_regions = set(storm_priority_regions[:2])
    while len(storm_regions) < 2:
        storm_regions.add(random.choice(REGIONS))

    forecast = {}
    for region in REGIONS:
        storm_day = random.randint(1, 4) if region in storm_regions else None
        days = []
        for offset in range(FORECAST_DAYS):
            day = TODAY + timedelta(days=offset)
            is_storm = storm_day is not None and offset == storm_day
            if is_storm:
                temp_high = round(random.uniform(58, 68), 1)
                wind_speed = round(random.uniform(45, 65), 1)
                precip_probability = round(random.uniform(0.80, 0.95), 2)
            else:
                temp_high = round(random.uniform(70, 95), 1)
                wind_speed = round(random.uniform(5, 15), 1)
                precip_probability = round(random.uniform(0.05, 0.30), 2)
            days.append(
                {
                    "date": day.isoformat(),
                    "temp_high_f": temp_high,
                    "wind_speed_mph": wind_speed,
                    "precip_probability": precip_probability,
                    "storm_warning": is_storm,
                }
            )
        forecast[region] = days

    return forecast


def make_historical_incidents(assets):
    weights = [max(a["base_failure_rate"], 0.001) for a in assets]
    n_incidents = random.randint(30, 50)
    rows = []
    for _ in range(n_incidents):
        asset = random.choices(assets, weights=weights, k=1)[0]
        days_ago = random.randint(1, 3 * 365)
        incident_date = TODAY - timedelta(days=days_ago)
        cause = random.choices(
            CAUSES, weights=[0.30, 0.25, 0.20, 0.15, 0.10], k=1
        )[0]

        if cause == "weather event":
            duration_hours = round(random.uniform(4, 72), 1)
        elif cause == "equipment aging":
            duration_hours = round(random.uniform(2, 24), 1)
        else:
            duration_hours = round(random.uniform(1, 12), 1)

        severity_fraction = random.uniform(0.10, 0.90)
        customers_affected = int(asset["customers_served"] * severity_fraction)
        estimated_cost_usd = round(
            customers_affected * duration_hours * random.uniform(80, 250), -2
        )

        rows.append(
            {
                "asset_id": asset["asset_id"],
                "date": incident_date.isoformat(),
                "cause": cause,
                "duration_hours": duration_hours,
                "customers_affected": customers_affected,
                "estimated_cost_usd": int(estimated_cost_usd),
            }
        )

    rows.sort(key=lambda r: r["date"])
    return rows


def main():
    assets = make_assets()
    sensor_readings, degrading_ids = make_sensor_readings(assets)
    weather_forecast = make_weather_forecast(assets, degrading_ids)
    historical_incidents = make_historical_incidents(assets)

    (OUT_DIR / "assets.json").write_text(json.dumps(assets, indent=2))
    (OUT_DIR / "sensor_readings.json").write_text(json.dumps(sensor_readings, indent=2))
    (OUT_DIR / "weather_forecast.json").write_text(json.dumps(weather_forecast, indent=2))

    with open(OUT_DIR / "historical_incidents.csv", "w", newline="") as f:
        writer = csv.DictWriter(
            f,
            fieldnames=[
                "asset_id",
                "date",
                "cause",
                "duration_hours",
                "customers_affected",
                "estimated_cost_usd",
            ],
        )
        writer.writeheader()
        writer.writerows(historical_incidents)

    print(f"Generated {len(assets)} assets ({len(degrading_ids)} with injected degrading sensor trends)")
    print(f"Sensor readings: {SENSOR_DAYS} days x {len(assets)} assets")
    print(f"Weather forecast: {FORECAST_DAYS} days x {len(REGIONS)} regions")
    print(f"Historical incidents: {len(historical_incidents)} rows")
    print(f"Written to: {OUT_DIR}")


if __name__ == "__main__":
    main()
