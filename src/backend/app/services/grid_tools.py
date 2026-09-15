"""The four Grid Advisor tools, defined ONCE here and consumed by two callers:

  1. app/mcp/server.py    - wraps each function as an MCP tool, callable by
                             IBM Bob or any MCP client, independently of the
                             web app.
  2. app/services/copilot_service.py - the in-app "Grid Copilot" chat routes
                             questions to these same functions.

This is the concrete mechanism that makes the Bob/MCP integration
load-bearing rather than cosmetic: there is exactly one implementation of
"what counts as at-risk", not a UI version and a separate Bob-demo version.
"""

from app.services import data_loader, risk_engine, maintenance_planner

TIER_RANK = {"Critical": 3, "High": 2, "Medium": 1, "Low": 0}


def get_at_risk_assets(region: str | None = None, min_tier: str = "Medium", limit: int = 10) -> dict:
    """Returns the highest-risk assets, optionally filtered by region and a
    minimum risk tier (Critical/High/Medium/Low)."""
    scored = risk_engine.score_all_assets()

    if region:
        scored = [a for a in scored if a["region"].lower() == region.lower()]

    min_rank = TIER_RANK.get(min_tier, 1)
    scored = [a for a in scored if TIER_RANK.get(a["risk_tier"], 0) >= min_rank]

    scored.sort(key=lambda a: a["risk_score"], reverse=True)
    top = scored[:limit]

    return {
        "count": len(top),
        "region_filter": region,
        "min_tier": min_tier,
        "assets": [
            {
                "asset_id": a["asset_id"],
                "name": a["name"],
                "region": a["region"],
                "type": a["type"],
                "risk_score": a["risk_score"],
                "risk_tier": a["risk_tier"],
                "grid_impact_severity": a["grid_impact_severity"],
                "customers_served": a["customers_served"],
            }
            for a in top
        ],
    }


def get_asset_detail(asset_id: str) -> dict:
    """Returns full metadata + current risk score/tier for one asset."""
    asset = data_loader.get_asset(asset_id)
    if asset is None:
        return {"error": f"No asset found with id '{asset_id}'"}

    risk_score = risk_engine.compute_risk_score(asset_id)
    enriched = dict(asset)
    enriched["risk_score"] = risk_score
    enriched["risk_tier"] = risk_engine.risk_tier_for(risk_score)
    return enriched


def explain_asset_risk(asset_id: str) -> dict:
    """Returns the full explainable risk breakdown for one asset: every
    scoring component with its point contribution and a plain-language
    explanation, plus the sensor/weather data behind it."""
    breakdown = risk_engine.compute_risk_breakdown(asset_id)
    if breakdown is None:
        return {"error": f"No asset found with id '{asset_id}'"}
    return breakdown


def get_maintenance_plan(region: str | None = None, top_n: int = 10) -> dict:
    """Returns the prioritized, region-grouped maintenance and crew
    pre-positioning plan, optionally filtered to one region."""
    return maintenance_planner.generate_maintenance_plan(region_filter=region, top_n=top_n)


def list_regions() -> dict:
    return {"regions": data_loader.get_regions()}
