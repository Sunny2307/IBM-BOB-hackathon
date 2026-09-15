from fastapi import APIRouter

from app.models.schemas import CopilotRequest
from app.services import copilot_service

router = APIRouter(tags=["copilot"])


@router.post("/copilot/ask")
async def ask_copilot(request: CopilotRequest):
    history = [msg.model_dump() for msg in request.history]
    return await copilot_service.ask(request.question, history=history)
