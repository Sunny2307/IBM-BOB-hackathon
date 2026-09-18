"""Live 7-day weather per region from Open-Meteo — the one genuinely real,
continuously-changing data source in the app.

Why this matters beyond freshness: the generated forecast is fixed at build
time, so "storm in 3 days" is a fact about when someone ran a script. This
module makes the weather half of the risk model reflect the actual sky.

Design notes:
  - No API key, no account, no rate-limit signup (Open-Meteo's free tier).
  - Region coordinates are the CENTROID OF THE ASSETS IN THAT REGION, taken
    from the already-loaded asset list — no second copy of REGION_COORDS to
    drift out of sync with the data.
  - `wind_speed_mph` carries the daily max GUST, not the sustained average:
    gusts are what actually bring down overhead lines and stress substation
    structures, so it is the number the risk model should see.
  - Every failure path (no network, timeout, non-2xx, malformed body) returns
    None so `data_loader.get_weather_forecast` falls back to the seeded
    synthetic forecast. Same never-breaks discipline as the LLM copilot path.
  - Set WEATHER_SOURCE=synthetic to pin the demo to the seeded forecast (e.g.
    if the real forecast is calm everywhere on demo day).
"""

import os
import time

import httpx

API_URL = "https://api.open-meteo.com/v1/forecast"
REQUEST_TIMEOUT_SECONDS = 6.0
CACHE_TTL_SECONDS = 30 * 60
FORECAST_DAYS = 7

# Thresholds that mark a day as a storm warning. Tuned to overhead-line
# damage: sustained damage to distribution hardware starts around 40 mph
# gusts, and heavy-precipitation days drive flashover/flooding risk.
STORM_GUST_MPH = 40.0
STORM_PRECIP_PROBABILITY = 0.70

_cache: dict[str, tuple[float, list[dict]]] = {}


def is_enabled() -> bool:
    return os.getenv("WEATHER_SOURCE", "live").lower() == "live"


def source_name(region_has_live_data: bool) -> str:
    """Label for /health and the UI, so nobody has to guess what they're looking at."""
    if not is_enabled():
        return "synthetic (WEATHER_SOURCE=synthetic)"
    return "live · Open-Meteo" if region_has_live_data else "synthetic (live fetch unavailable)"


def _to_weather_days(daily: dict) -> list[dict]:
    """Maps Open-Meteo's column-oriented response onto the app's existing
    WeatherDay shape, so no consumer downstream changes."""
    days = []
    for i, day in enumerate(daily["time"]):
        gust = float(daily["wind_gusts_10m_max"][i] or 0.0)
        precip = float(daily["precipitation_probability_max"][i] or 0.0) / 100.0
        days.append(
            {
                "date": day,
                "temp_high_f": round(float(daily["temperature_2m_max"][i] or 0.0), 1),
                "wind_speed_mph": round(gust, 1),
                "precip_probability": round(precip, 2),
                "storm_warning": gust >= STORM_GUST_MPH or precip >= STORM_PRECIP_PROBABILITY,
            }
        )
    return days


def fetch_forecast(region: str, lat: float, lon: float) -> list[dict] | None:
    """Returns a 7-day forecast in the app's WeatherDay shape, or None on any
    failure so the caller can fall back to the synthetic forecast."""
    if not is_enabled():
        return None

    cached = _cache.get(region)
    if cached and (time.monotonic() - cached[0]) < CACHE_TTL_SECONDS:
        return cached[1]

    params = {
        "latitude": lat,
        "longitude": lon,
        "daily": "temperature_2m_max,wind_speed_10m_max,wind_gusts_10m_max,precipitation_probability_max",
        "forecast_days": FORECAST_DAYS,
        "timezone": "auto",
        "wind_speed_unit": "mph",
        "temperature_unit": "fahrenheit",
    }
    try:
        response = httpx.get(API_URL, params=params, timeout=REQUEST_TIMEOUT_SECONDS)
        response.raise_for_status()
        days = _to_weather_days(response.json()["daily"])
    except Exception as exc:  # noqa: BLE001 - deliberate: any failure falls back to synthetic
        print(f"[weather_live] {region}: live fetch failed ({exc.__class__.__name__}: {exc}); using synthetic forecast.")
        return None

    if not days:
        return None
    _cache[region] = (time.monotonic(), days)
    return days


async def refresh_forever(interval_seconds: float = CACHE_TTL_SECONDS) -> None:
    """Keeps every region's forecast warm in the background.

    Without this, the first request after a cache expiry pays the fetch — and
    on an `async def` route (the Copilot) a sync httpx call would block the
    event loop for every other request too. Fetching in a thread, ahead of
    demand, means no request ever waits on the weather API.
    """
    import asyncio

    from app.services import data_loader

    while True:
        if is_enabled():
            for region in data_loader.get_regions():
                centroid = data_loader._region_centroid(region)
                if centroid:
                    await asyncio.to_thread(fetch_forecast, region, *centroid)
        await asyncio.sleep(interval_seconds)
