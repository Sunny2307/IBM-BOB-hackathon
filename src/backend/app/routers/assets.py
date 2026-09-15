from fastapi import APIRouter, HTTPException, Path

from app.services import risk_engine
from app.services import grid_tools

router = APIRouter(tags=["assets"])

AssetIdPath = Path(pattern=r"^AST-\d+$", description="Asset ID, e.g. AST-014")


@router.get("/assets")
def list_assets():
    return risk_engine.score_all_assets()


@router.get("/assets/{asset_id}")
def get_asset(asset_id: str = AssetIdPath):
    result = grid_tools.get_asset_detail(asset_id)
    if "error" in result:
        raise HTTPException(status_code=404, detail=result["error"])
    return result


@router.get("/assets/{asset_id}/risk-breakdown")
def get_risk_breakdown(asset_id: str = AssetIdPath):
    breakdown = risk_engine.compute_risk_breakdown(asset_id)
    if breakdown is None:
        raise HTTPException(status_code=404, detail=f"No asset found with id '{asset_id}'")
    return breakdown
