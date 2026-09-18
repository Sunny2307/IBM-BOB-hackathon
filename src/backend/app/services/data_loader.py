"""Loads generated synthetic data into memory once at import time.

Zero-infra by design: no database, no network calls. Re-run
scripts/generate_synthetic_data.py to regenerate; restart the app to reload.

Dates are RE-ANCHORED TO TODAY at load (`_anchor_dates_to_today`). The
generator writes absolute dates as of the day it ran, and on a deployed
instance that is build time — so without this, every day after deploy pushes
one more "7-day forecast" day into the past, and the app ends up warning
about storms that already happened. Anchoring at load keeps the 30-day sensor
window ending today and the forecast starting today no matter how old the
build is.
"""

import csv
import json
from datetime import date, timedelta
from pathlib import Path
from functools import lru_cache

from app.services import weather_live

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

    _anchor_dates_to_today(sensor_readings, weather_forecast, incidents)

    assets_by_id = {a["asset_id"]: a for a in assets}

    return {
        "assets": assets,
        "assets_by_id": assets_by_id,
        "sensor_readings": sensor_readings,
        "weather_forecast": weather_forecast,
        "incidents": incidents,
    }


def _anchor_dates_to_today(
    sensor_readings: dict[str, list[dict]],
    weather_forecast: dict[str, list[dict]],
    incidents: list[dict],
) -> timedelta:
    """Shifts every date in the loaded data by one constant offset, chosen so
    the newest sensor reading lands on today. Mutates in place; returns the
    offset applied (zero if the data was generated today).

    One offset for all three datasets, so their relative alignment — the whole
    point of the seeded generator — is preserved exactly: a storm that was
    forecast two days after the last sensor reading still is.
    """
    all_days = [row["date"] for series in sensor_readings.values() for row in series]
    if not all_days:
        return timedelta(0)

    offset = date.today() - date.fromisoformat(max(all_days))
    if offset == timedelta(0):
        return offset

    def shift(iso: str) -> str:
        return (date.fromisoformat(iso) + offset).isoformat()

    for series in sensor_readings.values():
        for row in series:
            row["date"] = shift(row["date"])
    for days in weather_forecast.values():
        for day in days:
            day["date"] = shift(day["date"])
    for incident in incidents:
        incident["date"] = shift(incident["date"])

    print(f"[data_loader] Re-anchored dates to today (shifted by {offset.days:+d} days).")
    return offset


def get_assets() -> list[dict]:
    return _load_all()["assets"]


def get_asset(asset_id: str) -> dict | None:
    return _load_all()["assets_by_id"].get(asset_id)


def get_sensor_series(asset_id: str) -> list[dict]:
    return _load_all()["sensor_readings"].get(asset_id, [])


def _region_centroid(region: str) -> tuple[float, float] | None:
    """Mean lat/lon of the assets in a region — the point we ask Open-Meteo
    about. Derived from the asset data itself so there is no second copy of
    region coordinates to drift out of sync."""
    coords = [(a["lat"], a["lon"]) for a in get_assets() if a["region"] == region]
    if not coords:
        return None
    return (sum(c[0] for c in coords) / len(coords), sum(c[1] for c in coords) / len(coords))


def get_weather_forecast(region: str) -> list[dict]:
    """Live 7-day forecast for the region when available, otherwise the seeded
    synthetic one. Every weather consumer in the app — risk engine, maintenance
    planner, MCP tools, Copilot, UI — goes through here, so this single swap is
    what makes the whole system run on real weather."""
    centroid = _region_centroid(region)
    if centroid is not None:
        live = weather_live.fetch_forecast(region, centroid[0], centroid[1])
        if live:
            return live
    return _load_all()["weather_forecast"].get(region, [])


def weather_source() -> str:
    """Which forecast the app is actually serving right now — reported by
    /health and shown in the UI so nobody has to guess."""
    regions = get_regions()
    any_live = any(
        (c := _region_centroid(r)) and weather_live.fetch_forecast(r, c[0], c[1])
        for r in regions
    )
    return weather_live.source_name(any_live)


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
