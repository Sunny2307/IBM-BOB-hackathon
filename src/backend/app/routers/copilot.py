from fastapi import APIRouter

from app.models.schemas import CopilotRequest
from app.services import copilot_service

router = APIRouter(tags=["copilot"])


@router.post("/copilot/ask")
def ask_copilot(request: CopilotRequest):
    return copilot_service.ask(request.question)
