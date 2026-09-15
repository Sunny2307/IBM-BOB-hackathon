"""Smoke tests proving the specific claims made in docs/solution-overview.md
and README.md are actually true of the running code — not just asserted.

Run: cd src/backend && pytest
"""

import statistics
from datetime import date

from app.services import data_loader, risk_engine, maintenance_planner, grid_tools


def test_risk_tier_thresholds():
    assert risk_engine.risk_tier_for(100) == "Critical"
    assert risk_engine.risk_tier_for(75) == "Critical"
    assert risk_engine.risk_tier_for(74.9) == "High"
    assert risk_engine.risk_tier_for(50) == "High"
    assert risk_engine.risk_tier_for(49.9) == "Medium"
    assert risk_engine.risk_tier_for(25) == "Medium"
    assert risk_engine.risk_tier_for(24.9) == "Low"
    assert risk_engine.risk_tier_for(0) == "Low"


def test_top_ranked_asset_has_the_compounding_risk_narrative():
    """The synthetic data generator deliberately guarantees this; this test
    proves it holds through the actual scoring pipeline, not just in the
    generator's own logic."""
    scored = risk_engine.score_all_assets()
    top = max(scored, key=lambda a: a["risk_score"])
    breakdown = risk_engine.compute_risk_breakdown(top["asset_id"])

    storm_days = [d for d in breakdown["weather_context"]["forecast"] if d["storm_warning"]]
    assert storm_days, (
        f"Top-ranked asset {top['asset_id']} should have a storm forecast in its "
        f"region within 7 days (the 'weather compounds sensor risk' story)"
    )

    sensor_factors = [
        c for c in breakdown["components"]
        if c["factor"].startswith("Sensor Anomaly") and c["contribution"] > 5
    ]
    assert sensor_factors, (
        f"Top-ranked asset {top['asset_id']} should show at least one meaningfully "
        f"anomalous sensor reading, not just a weather/historical score"
    )


def test_critical_tier_has_more_sensor_anomaly_than_low_tier():
    """Confirms the risk tiers are actually discriminating on sensor
    behavior, not just noise."""
    scored = risk_engine.score_all_assets()
    critical = [a for a in scored if a["risk_tier"] == "Critical"]
    low = [a for a in scored if a["risk_tier"] == "Low"]
    assert critical and low, "generated data should contain both Critical and Low tier assets"

    def sensor_contribution(asset_id: str) -> float:
        breakdown = risk_engine.compute_risk_breakdown(asset_id)
        return sum(
            c["contribution"] for c in breakdown["components"]
            if c["factor"].startswith("Sensor Anomaly")
        )

    avg_critical = statistics.fmean(sensor_contribution(a["asset_id"]) for a in critical)
    avg_low = statistics.fmean(sensor_contribution(a["asset_id"]) for a in low)
    assert avg_critical > avg_low, "Critical-tier assets should show more sensor anomaly than Low-tier assets"


def test_maintenance_plan_dates_precede_forecast_storms():
    """Proves the 'weather-timed' claim: Critical/High items in a region
    with a forecast storm are scheduled on or before the storm date."""
    plan = maintenance_planner.generate_maintenance_plan()
    checked_any = False

    for region_block in plan["regions"]:
        forecast = data_loader.get_weather_forecast(region_block["region"])
        storm_days = [d for d in forecast if d["storm_warning"]]
        if not storm_days:
            continue
        storm_date = date.fromisoformat(storm_days[0]["date"])

        for item in region_block["items"]:
            if item["risk_tier"] in ("Critical", "High"):
                by_date = date.fromisoformat(item["recommended_by_date"])
                assert by_date <= storm_date, (
                    f"{item['asset_id']} ({item['risk_tier']}) recommended_by_date "
                    f"{by_date} should be on/before the {storm_date} storm in "
                    f"{region_block['region']}"
                )
                checked_any = True

    assert checked_any, "expected at least one Critical/High item in a storm-affected region to check"


def test_grid_tools_returns_same_top_asset_as_the_dashboard():
    """This is the concrete 'load-bearing MCP integration' claim: grid_tools
    (used by both the MCP server and the in-app Copilot) must return the
    exact same top-ranked asset and score as risk_engine (used by the
    dashboard's /assets endpoint)."""
    scored = risk_engine.score_all_assets()
    scored.sort(key=lambda a: a["risk_score"], reverse=True)
    expected = scored[0]

    result = grid_tools.get_at_risk_assets(min_tier="Low", limit=1)
    actual = result["assets"][0]

    assert actual["asset_id"] == expected["asset_id"]
    assert actual["risk_score"] == expected["risk_score"]
