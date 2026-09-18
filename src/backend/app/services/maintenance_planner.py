"""Ranks assets into a prioritized, region-grouped maintenance and crew
pre-positioning plan. Priority = risk_score x grid_impact_severity, so a
highly-likely-to-fail asset that would strand a hospital ranks above an
equally-likely-to-fail asset serving a handful of low-priority customers.
"""

from datetime import date, timedelta

from app.services import data_loader, risk_engine

TOP_N_DEFAULT = 20
TIER_DEFAULT_OFFSET_DAYS = {"Critical": 1, "High": 5, "Medium": 14}


def _weather_summary(region: str) -> str:
    """One line describing what the weather is actually doing in this region.

    Reuses the risk engine's own day-threat scoring rather than only looking at
    the storm flag, so a 100F heat wave or a 38 mph gust day reads as the real
    risk driver it is instead of showing up as "no severe weather".
    """
    forecast = data_loader.get_weather_forecast(region)
    if not forecast:
        return "No forecast data available for this region."

    storm_days = [d for d in forecast if d["storm_warning"]]
    if storm_days:
        storm = storm_days[0]
        return (
            f"Storm warning on {storm['date']} (wind {storm['wind_speed_mph']} mph, "
            f"{round(storm['precip_probability'] * 100)}% precip probability)."
        )

    worst, severity, driver = None, 0.0, "wind"
    for day in forecast:
        day_severity, day_driver = risk_engine._day_threat(day)
        if day_severity > severity:
            worst, severity, driver = day, day_severity, day_driver

    if worst is None or severity < 0.1:
        return "Benign 7-day forecast; no weather-driven risk."

    phrase = {
        "wind": f"wind gusting to {worst['wind_speed_mph']} mph",
        "precipitation": f"{round(worst['precip_probability'] * 100)}% precipitation probability",
        "heat": f"a {worst['temp_high_f']}°F high stressing loaded equipment",
    }[driver]
    return f"No storm warning, but elevated conditions on {worst['date']}: {phrase}."


def _recommended_action(tier: str) -> str:
    return {
        "Critical": "Dispatch crew for emergency inspection now; pre-stage replacement parts/transformer.",
        "High": "Schedule priority inspection within days; order replacement parts if degradation confirmed.",
        "Medium": "Schedule inspection in the next routine maintenance window; increase monitoring cadence.",
    }.get(tier, "Continue routine calendar-based monitoring.")


def _recommended_by_date(region: str, tier: str) -> tuple[str, str]:
    """Returns (date_iso, rationale_snippet). If a storm is forecast for the
    asset's region, the date is pulled in to land BEFORE the storm — this is
    the concrete "weather + sensor data combined in time to act" mechanism
    the problem statement asks for."""
    today = date.today()
    default_days = TIER_DEFAULT_OFFSET_DAYS.get(tier, 30)
    default_date = today + timedelta(days=default_days)

    forecast = data_loader.get_weather_forecast(region)
    storm_days = [d for d in forecast if d["storm_warning"]]

    if storm_days:
        storm_date = date.fromisoformat(storm_days[0]["date"])
        pre_storm_date = max(today + timedelta(days=1), storm_date - timedelta(days=1))
        if pre_storm_date <= default_date or tier in ("Critical", "High"):
            return (
                pre_storm_date.isoformat(),
                f"pre-positioned ahead of the {storm_days[0]['date']} storm warning in {region}",
            )

    return default_date.isoformat(), f"per standard {tier.lower()}-tier response window"


def generate_maintenance_plan(region_filter: str | None = None, top_n: int = TOP_N_DEFAULT) -> dict:
    scored_assets = risk_engine.score_all_assets()
    scored_assets = [a for a in scored_assets if a["risk_tier"] != "Low"]

    if region_filter:
        scored_assets = [a for a in scored_assets if a["region"] == region_filter]

    for a in scored_assets:
        a["priority_score"] = round(a["risk_score"] * a["grid_impact_severity"], 1)

    scored_assets.sort(key=lambda a: a["priority_score"], reverse=True)
    top_assets = scored_assets[:top_n]

    by_region: dict[str, list[dict]] = {}
    for a in top_assets:
        by_region.setdefault(a["region"], []).append(a)

    regions_out = []
    for region, assets_in_region in by_region.items():
        weather_summary = _weather_summary(region)

        items = []
        for a in sorted(assets_in_region, key=lambda x: x["priority_score"], reverse=True):
            by_date, rationale_snippet = _recommended_by_date(region, a["risk_tier"])
            items.append(
                {
                    "asset_id": a["asset_id"],
                    "asset_name": a["name"],
                    "risk_score": a["risk_score"],
                    "risk_tier": a["risk_tier"],
                    "priority_score": a["priority_score"],
                    "recommended_action": _recommended_action(a["risk_tier"]),
                    "recommended_by_date": by_date,
                    "rationale": (
                        f"Risk score {a['risk_score']} ({a['risk_tier']}) x grid impact severity "
                        f"{a['grid_impact_severity']}/10 ({a['customers_served']:,} customers served); "
                        f"{rationale_snippet}."
                    ),
                }
            )

        regions_out.append({"region": region, "weather_summary": weather_summary, "items": items})

    regions_out.sort(
        key=lambda r: max((i["priority_score"] for i in r["items"]), default=0),
        reverse=True,
    )

    return {
        "generated_at": date.today().isoformat(),
        "regions": regions_out,
    }
