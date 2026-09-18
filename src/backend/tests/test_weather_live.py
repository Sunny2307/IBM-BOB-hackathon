"""Offline tests for the live-weather path and the continuous weather risk
term. No network: the Open-Meteo response is a fixture, and the risk-term
tests build forecasts by hand.

These cover the two things that could silently break the app: the mapping from
Open-Meteo's response onto the app's WeatherDay shape, and the fallback to the
seeded synthetic forecast when the live fetch fails.
"""

from datetime import date, timedelta

from app.services import data_loader, risk_engine, weather_live

# Trimmed real response shape from api.open-meteo.com/v1/forecast
OPEN_METEO_DAILY = {
    "time": ["2026-09-18", "2026-09-19", "2026-09-20"],
    "temperature_2m_max": [85.1, 91.0, 98.6],
    "wind_speed_10m_max": [9.7, 11.0, 30.0],
    "wind_gusts_10m_max": [17.9, 22.1, 48.0],
    "precipitation_probability_max": [0, 5, 85],
}


def _forecast(days: list[dict]) -> list[dict]:
    """Builds a forecast starting today from partial day specs."""
    today = date.today()
    return [
        {
            "date": (today + timedelta(days=i)).isoformat(),
            "temp_high_f": spec.get("temp_high_f", 70.0),
            "wind_speed_mph": spec.get("wind_speed_mph", 5.0),
            "precip_probability": spec.get("precip_probability", 0.0),
            "storm_warning": spec.get("storm_warning", False),
        }
        for i, spec in enumerate(days)
    ]


def _asset(**overrides) -> dict:
    base = {
        "asset_id": "AST-TEST",
        "region": "Testville",
        "install_year": date.today().year - 5,
        "has_redundancy": False,
    }
    base.update(overrides)
    return base


def test_open_meteo_response_maps_onto_the_apps_weather_shape():
    days = weather_live._to_weather_days(OPEN_METEO_DAILY)

    assert len(days) == 3
    assert set(days[0]) == {
        "date", "temp_high_f", "wind_speed_mph", "precip_probability", "storm_warning"
    }, "must match the WeatherDay schema the whole app already consumes"
    # precipitation_probability_max is a percentage upstream, a fraction here
    assert days[2]["precip_probability"] == 0.85
    # wind_speed_mph carries the GUST, not the sustained average
    assert days[2]["wind_speed_mph"] == 48.0


def test_storm_warning_is_derived_from_real_thresholds():
    days = weather_live._to_weather_days(OPEN_METEO_DAILY)
    assert days[0]["storm_warning"] is False, "calm, dry day is not a storm"
    assert days[1]["storm_warning"] is False
    assert days[2]["storm_warning"] is True, "48 mph gusts + 85% precip is a storm"


def test_live_fetch_failure_falls_back_to_the_synthetic_forecast(monkeypatch):
    """The whole app reads weather through data_loader.get_weather_forecast, so
    this is what guarantees a network outage can never empty the risk model."""
    monkeypatch.setattr(weather_live, "is_enabled", lambda: True)
    monkeypatch.setattr(
        weather_live, "fetch_forecast", lambda region, lat, lon: None
    )
    data_loader._load_all.cache_clear()

    region = data_loader.get_regions()[0]
    forecast = data_loader.get_weather_forecast(region)

    assert forecast, "must fall back to the seeded forecast, not return empty"
    assert len(forecast) == 7


def _weather_points(monkeypatch, forecast: list[dict], asset: dict) -> float:
    monkeypatch.setattr(data_loader, "get_weather_forecast", lambda region: forecast)
    return risk_engine.compute_weather_component(asset)["contribution"]


def test_heat_alone_registers_as_weather_risk(monkeypatch):
    """The old binary model scored a 104F heat wave at zero, because no storm
    flag was set — exactly the compounding case the problem statement calls
    out ("a heat wave pushes already-stressed equipment closer to its thermal
    limit")."""
    calm = _weather_points(monkeypatch, _forecast([{"temp_high_f": 70.0}]), _asset())
    heatwave = _weather_points(monkeypatch, _forecast([{"temp_high_f": 104.0}]), _asset())

    assert calm < 1.0
    assert heatwave > 10.0, "a 104F day must carry real weather risk with no storm flagged"


def test_an_imminent_threat_outscores_the_same_threat_days_away(monkeypatch):
    """A storm on Friday is not as actionable as the same storm tomorrow; the
    old model gave both the identical 25 points."""
    storm = {"wind_speed_mph": 60.0, "precip_probability": 0.9, "storm_warning": True}
    calm_day = {"wind_speed_mph": 5.0}

    tomorrow = _weather_points(monkeypatch, _forecast([storm] + [calm_day] * 5), _asset())
    next_week = _weather_points(monkeypatch, _forecast([calm_day] * 5 + [storm]), _asset())

    assert tomorrow > next_week


def test_redundant_asset_carries_less_weather_risk_than_an_ageing_one(monkeypatch):
    """Same region, same forecast, different consequence — the old flat regional
    term could not tell these two apart."""
    storm = _forecast([{"wind_speed_mph": 55.0, "precip_probability": 0.9, "storm_warning": True}])

    resilient = _weather_points(
        monkeypatch, storm, _asset(install_year=date.today().year - 2, has_redundancy=True)
    )
    fragile = _weather_points(
        monkeypatch, storm, _asset(install_year=date.today().year - 40, has_redundancy=False)
    )

    assert fragile > resilient


def test_weather_contribution_never_exceeds_its_budget(monkeypatch):
    """The score's explainability depends on each term staying inside the
    budget the docs claim for it."""
    extreme = _forecast(
        [{"temp_high_f": 120.0, "wind_speed_mph": 90.0, "precip_probability": 1.0, "storm_warning": True}] * 7
    )
    points = _weather_points(
        monkeypatch, extreme, _asset(install_year=date.today().year - 40)
    )
    assert 0.0 <= points <= risk_engine.WEATHER_MAX
