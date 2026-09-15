from fastapi import APIRouter, Query

from app.services import maintenance_planner

router = APIRouter(tags=["maintenance"])


@router.get("/maintenance-plan")
def get_maintenance_plan(region: str | None = Query(default=None)):
    return maintenance_planner.generate_maintenance_plan(region_filter=region)
