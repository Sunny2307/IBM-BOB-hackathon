"""Sign-in for the operator layer.

Only two routes: exchange credentials for a token, and read back who the token
says you are. Everything else that needs identity takes it from the token via
`auth.current_user`, never from a request body.
"""

from fastapi import APIRouter, Depends, HTTPException, status

from app import db
from app.models.schemas import LoginRequest, LoginResponse
from app.services import auth

router = APIRouter(tags=["auth"])


@router.post("/auth/login", response_model=LoginResponse)
def login(request: LoginRequest):
    if not db.is_available():
        raise HTTPException(
            status.HTTP_503_SERVICE_UNAVAILABLE,
            f"Sign-in needs a database; it is {db.status()}.",
        )

    user = auth.authenticate(request.email, request.password)
    if user is None:
        # One message for both "no such account" and "wrong password", so this
        # route cannot be used to enumerate who has an account.
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Incorrect email or password.")

    return LoginResponse(
        access_token=auth.create_token(user),
        user_id=user["id"],
        email=user["email"],
        full_name=user["full_name"],
        role=user["role"],
        company_id=user["company_id"],
        company_name=user["company_name"],
    )


@router.get("/auth/me")
def me(user: dict = Depends(auth.current_user)):
    """Lets a client validate a stored token on launch without guessing."""
    return user
