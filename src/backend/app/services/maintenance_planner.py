"""Ranks assets into a prioritized, region-grouped maintenance and crew
pre-positioning plan. Priority = risk_score x grid_impact_severity, so a
highly-likely-to-fail asset that would strand a hospital ranks above an
equally-likely-to-fail asset serving a handful of low-priority customers.
"""

from datetime import date, timedelta

from app.services import data_loader, risk_engine

TOP_N_DEFAULT = 20
TIER_DEFAULT_OFFSET_DAYS = {"Critical": 1, "High": 5, "Medium": 14}


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
        forecast = data_loader.get_weather_forecast(region)
        storm_days = [d for d in forecast if d["storm_warning"]]
        if storm_days:
            weather_summary = (
                f"Storm warning on {storm_days[0]['date']} "
                f"(wind {storm_days[0]['wind_speed_mph']} mph, "
                f"{round(storm_days[0]['precip_probability'] * 100)}% precip probability)."
            )
        else:
            weather_summary = "No severe weather in the 7-day forecast."

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
