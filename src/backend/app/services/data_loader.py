"""Loads generated synthetic data into memory once at import time.

Zero-infra by design: no database, no network calls. Re-run
scripts/generate_synthetic_data.py to regenerate; restart the app to reload.
"""

import csv
import json
from pathlib import Path
from functools import lru_cache

DATA_DIR = Path(__file__).resolve().parent.parent / "data" / "generated"


class MissingDataError(RuntimeError):
    pass


@lru_cache(maxsize=1)
def _load_all() -> dict:
    assets_path = DATA_DIR / "assets.json"
    sensors_path = DATA_DIR / "sensor_readings.json"
    weather_path = DATA_DIR / "weather_forecast.json"
    incidents_path = DATA_DIR / "historical_incidents.csv"

    if not assets_path.exists():
        raise MissingDataError(
            f"No generated data found at {DATA_DIR}. "
            "Run: python scripts/generate_synthetic_data.py"
        )

    assets = json.loads(assets_path.read_text())
    sensor_readings = json.loads(sensors_path.read_text())
    weather_forecast = json.loads(weather_path.read_text())

    incidents = []
    with open(incidents_path, newline="") as f:
        reader = csv.DictReader(f)
        for row in reader:
            row["duration_hours"] = float(row["duration_hours"])
            row["customers_affected"] = int(row["customers_affected"])
            row["estimated_cost_usd"] = int(row["estimated_cost_usd"])
            incidents.append(row)

    assets_by_id = {a["asset_id"]: a for a in assets}

    return {
        "assets": assets,
        "assets_by_id": assets_by_id,
        "sensor_readings": sensor_readings,
        "weather_forecast": weather_forecast,
        "incidents": incidents,
    }


def get_assets() -> list[dict]:
    return _load_all()["assets"]


def get_asset(asset_id: str) -> dict | None:
    return _load_all()["assets_by_id"].get(asset_id)


def get_sensor_series(asset_id: str) -> list[dict]:
    return _load_all()["sensor_readings"].get(asset_id, [])


def get_weather_forecast(region: str) -> list[dict]:
    return _load_all()["weather_forecast"].get(region, [])


def get_regions() -> list[str]:
    return sorted(_load_all()["weather_forecast"].keys())


def get_incidents_for_asset(asset_id: str) -> list[dict]:
    return [row for row in _load_all()["incidents"] if row["asset_id"] == asset_id]


def get_incidents_by_type_and_age(asset_type: str, age_bucket: str) -> list[dict]:
    """age_bucket: 'new' (<10y), 'mid' (10-25y), 'old' (25y+) — used to compute
    a historical base rate for assets of a similar profile, since a single
    asset rarely has its own incident history."""
    all_assets = _load_all()["assets_by_id"]
    matching_ids = {
        aid
        for aid, a in all_assets.items()
        if a["type"] == asset_type and _age_bucket(a) == age_bucket
    }
    return [row for row in _load_all()["incidents"] if row["asset_id"] in matching_ids]


def _age_bucket(asset: dict) -> str:
    from datetime import date

    age = date.today().year - asset["install_year"]
    if age < 10:
        return "new"
    if age < 25:
        return "mid"
    return "old"


def warm_up() -> int:
    """Call at app startup to fail fast if data is missing, and to pay the
    load cost once instead of on the first request."""
    return len(get_assets())
