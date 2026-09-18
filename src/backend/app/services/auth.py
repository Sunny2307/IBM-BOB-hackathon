"""Authentication and role enforcement for the operator layer.

Password hashing uses stdlib `hashlib.scrypt` — a memory-hard KDF, per-user
random salt, no third-party dependency. This is not a shortcut: scrypt is the
right primitive, and skipping passlib removes a dependency that has a long
history of breaking against new bcrypt releases.

The one rule that matters most here: **company_id comes from the token, never
from the request.** A multi-tenant system that trusts a client-supplied tenant
id is worse than a single-tenant one, because it looks safe. Every operator
query downstream filters on the value this module extracts.
"""

import hashlib
import hmac
import os
import secrets
from datetime import datetime, timedelta, timezone
from typing import Any

import jwt
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from app import db

# scrypt cost parameters. n=2**14 keeps a hash around ~100ms on typical
# hardware — slow enough to make offline cracking expensive, fast enough that
# a login does not feel broken.
_SCRYPT_N = 2**14
_SCRYPT_R = 8
_SCRYPT_P = 1
_SCRYPT_DKLEN = 64

TOKEN_TTL_HOURS = 12
_ALGORITHM = "HS256"

_bearer = HTTPBearer(auto_error=False)


def _secret() -> str:
    """JWT signing key. Falls back to a per-process random value if JWT_SECRET
    is unset: tokens then stop working across a restart, which is a visible
    nuisance rather than the silent catastrophe of shipping a hardcoded
    default secret that anyone reading the repo could forge tokens with."""
    configured = os.getenv("JWT_SECRET")
    if configured:
        return configured
    global _ephemeral_secret
    try:
        return _ephemeral_secret
    except NameError:
        _ephemeral_secret = secrets.token_urlsafe(48)
        print("[auth] JWT_SECRET unset — using an ephemeral per-process secret. "
              "Sessions will not survive a restart. Set JWT_SECRET in .env.")
        return _ephemeral_secret


def hash_password(password: str) -> tuple[str, str]:
    """Returns (hash_hex, salt_hex). Salt is fresh per user."""
    salt = secrets.token_bytes(16)
    digest = hashlib.scrypt(
        password.encode("utf-8"), salt=salt,
        n=_SCRYPT_N, r=_SCRYPT_R, p=_SCRYPT_P, dklen=_SCRYPT_DKLEN,
    )
    return digest.hex(), salt.hex()


def verify_password(password: str, hash_hex: str, salt_hex: str) -> bool:
    """Constant-time comparison — a timing-variable check on a password digest
    is a real (if slow) oracle."""
    try:
        salt = bytes.fromhex(salt_hex)
    except ValueError:
        return False
    digest = hashlib.scrypt(
        password.encode("utf-8"), salt=salt,
        n=_SCRYPT_N, r=_SCRYPT_R, p=_SCRYPT_P, dklen=_SCRYPT_DKLEN,
    )
    return hmac.compare_digest(digest.hex(), hash_hex)


def create_token(user: dict[str, Any]) -> str:
    now = datetime.now(timezone.utc)
    payload = {
        "sub": str(user["id"]),
        "company_id": user["company_id"],
        "role": user["role"],
        "email": user["email"],
        "iat": now,
        "exp": now + timedelta(hours=TOKEN_TTL_HOURS),
    }
    return jwt.encode(payload, _secret(), algorithm=_ALGORITHM)


def decode_token(token: str) -> dict[str, Any]:
    """Raises 401 on anything wrong — expired, tampered, malformed. The caller
    never gets a partially-trusted token."""
    try:
        return jwt.decode(token, _secret(), algorithms=[_ALGORITHM])
    except jwt.ExpiredSignatureError:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Session expired; sign in again.")
    except jwt.InvalidTokenError:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Invalid authentication token.")


def authenticate(email: str, password: str) -> dict[str, Any] | None:
    """Returns the user row on success, None on any failure. Deliberately does
    not distinguish 'no such user' from 'wrong password' to the caller, so the
    route cannot leak which emails are registered."""
    user = db.query_one(
        """
        SELECT u.id, u.company_id, u.email, u.full_name, u.role, u.is_active,
               u.password_hash, u.password_salt, c.name AS company_name
        FROM users u JOIN companies c ON c.id = u.company_id
        WHERE lower(u.email) = lower(%s)
        """,
        (email,),
    )
    if user is None or not user["is_active"]:
        return None
    if not verify_password(password, user["password_hash"], user["password_salt"]):
        return None
    return user


def current_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(_bearer),
) -> dict[str, Any]:
    """FastAPI dependency. Returns {user_id, company_id, role, email} taken
    from the SIGNED token — this is the only trusted source of company_id in
    the whole application."""
    if credentials is None:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Authentication required.")
    claims = decode_token(credentials.credentials)
    return {
        "user_id": int(claims["sub"]),
        "company_id": claims["company_id"],
        "role": claims["role"],
        "email": claims.get("email", ""),
    }


def require_admin(user: dict[str, Any] = Depends(current_user)) -> dict[str, Any]:
    """Enforced server-side on every /admin route. Hiding a button in the UI is
    not access control."""
    if user["role"] != "admin":
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Administrator role required.")
    return user
