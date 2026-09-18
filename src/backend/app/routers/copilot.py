from fastapi import APIRouter, Depends
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from app.models.schemas import CopilotRequest
from app.services import auth, copilot_service

router = APIRouter(tags=["copilot"])

# auto_error=False: a token is OPTIONAL here. The public web dashboard calls
# this endpoint with no account and must keep working; a signed-in operator
# gets the same endpoint plus their own alerts and the ability to acknowledge.
_optional_bearer = HTTPBearer(auto_error=False)


@router.post("/copilot/ask")
async def ask_copilot(
    request: CopilotRequest,
    credentials: HTTPAuthorizationCredentials | None = Depends(_optional_bearer),
):
    history = [msg.model_dump() for msg in request.history]

    actor = None
    if credentials is not None:
        # A malformed or expired token is a real 401, not a silent downgrade to
        # anonymous — otherwise a user whose session lapsed would quietly stop
        # seeing their own alerts with no explanation.
        claims = auth.decode_token(credentials.credentials)
        actor = {
            "user_id": int(claims["sub"]),
            "company_id": claims["company_id"],
            "role": claims["role"],
            "email": claims.get("email", ""),
        }

    return await copilot_service.ask(request.question, history=history, actor=actor)
