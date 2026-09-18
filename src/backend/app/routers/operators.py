"""Operator layer routes: admin user/assignment management, and the crew-facing
alert inbox.

Every query in this file filters on `user["company_id"]`, which comes from the
signed JWT — never from a path, query or body parameter. That is the single
invariant that makes multi-tenancy real rather than decorative, and it has a
dedicated test.
"""

from fastapi import APIRouter, Depends, HTTPException, Query, status

from app import db
from app.models.schemas import CreateAssignmentRequest, CreateUserRequest
from app.services import auth, grid_tools

router = APIRouter(tags=["operators"])


def _guard_db() -> None:
    if not db.is_available():
        raise HTTPException(
            status.HTTP_503_SERVICE_UNAVAILABLE,
            f"Operator features need a database; it is {db.status()}. "
            "The dashboard, risk engine and copilot are unaffected.",
        )


# ---------------------------------------------------------------- admin


@router.get("/admin/users")
def list_users(user: dict = Depends(auth.require_admin)):
    _guard_db()
    return db.query(
        "SELECT id, email, full_name, role, is_active FROM users "
        "WHERE company_id = %s ORDER BY role, full_name",
        (user["company_id"],),
    )


@router.post("/admin/users", status_code=status.HTTP_201_CREATED)
def create_user(request: CreateUserRequest, user: dict = Depends(auth.require_admin)):
    _guard_db()
    if db.query_one("SELECT id FROM users WHERE lower(email) = lower(%s)", (request.email,)):
        raise HTTPException(status.HTTP_409_CONFLICT, "That email already has an account.")

    password_hash, password_salt = auth.hash_password(request.password)
    created = db.execute(
        """
        INSERT INTO users (company_id, email, full_name, password_hash, password_salt, role)
        VALUES (%s, %s, %s, %s, %s, %s)
        RETURNING id, email, full_name, role, is_active
        """,
        (user["company_id"], request.email, request.full_name,
         password_hash, password_salt, request.role),
    )
    return created


@router.get("/admin/assignments")
def list_assignments(user: dict = Depends(auth.require_admin)):
    _guard_db()
    return db.query(
        """
        SELECT a.id, a.user_id, u.full_name AS user_name, a.scope_type, a.scope_value
        FROM assignments a JOIN users u ON u.id = a.user_id
        WHERE a.company_id = %s
        ORDER BY u.full_name, a.scope_value
        """,
        (user["company_id"],),
    )


@router.post("/admin/assignments", status_code=status.HTTP_201_CREATED)
def create_assignment(request: CreateAssignmentRequest, user: dict = Depends(auth.require_admin)):
    _guard_db()
    # Confirm the target user is in the ADMIN'S OWN company before assigning —
    # otherwise an admin could hand their regions to a stranger's account.
    target = db.query_one(
        "SELECT id FROM users WHERE id = %s AND company_id = %s",
        (request.user_id, user["company_id"]),
    )
    if target is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "No such user in your company.")

    created = db.execute(
        """
        INSERT INTO assignments (company_id, user_id, scope_type, scope_value)
        VALUES (%s, %s, %s, %s)
        ON CONFLICT (user_id, scope_type, scope_value) DO NOTHING
        RETURNING id, user_id, scope_type, scope_value
        """,
        (user["company_id"], request.user_id, request.scope_type, request.scope_value),
    )
    if created is None:
        raise HTTPException(status.HTTP_409_CONFLICT, "That assignment already exists.")
    return created


@router.delete("/admin/assignments/{assignment_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_assignment(assignment_id: int, user: dict = Depends(auth.require_admin)):
    _guard_db()
    db.execute(
        "DELETE FROM assignments WHERE id = %s AND company_id = %s",
        (assignment_id, user["company_id"]),
    )


# ---------------------------------------------------------------- crew


@router.get("/alerts/mine")
def my_alerts(
    status_filter: str = Query(default="open", alias="status"),
    user: dict = Depends(auth.current_user),
):
    """The crew inbox — and the endpoint the mobile app polls to decide whether
    to fire a local notification."""
    _guard_db()
    return grid_tools.get_my_alerts(
        user_id=user["user_id"], company_id=user["company_id"], status=status_filter
    )


@router.get("/alerts/{alert_id}")
def alert_detail(alert_id: int, user: dict = Depends(auth.current_user)):
    _guard_db()
    result = grid_tools.get_alert_detail(
        alert_id=alert_id, user_id=user["user_id"], company_id=user["company_id"]
    )
    if "error" in result:
        raise HTTPException(status.HTTP_404_NOT_FOUND, result["error"])
    return result


@router.post("/alerts/{alert_id}/ack")
def acknowledge(alert_id: int, user: dict = Depends(auth.current_user)):
    _guard_db()
    result = grid_tools.acknowledge_alert(
        alert_id=alert_id, user_id=user["user_id"], company_id=user["company_id"]
    )
    if "error" in result:
        raise HTTPException(status.HTTP_404_NOT_FOUND, result["error"])
    return result


@router.get("/assignments/mine")
def my_assignments(user: dict = Depends(auth.current_user)):
    _guard_db()
    return grid_tools.get_my_assignments(
        user_id=user["user_id"], company_id=user["company_id"]
    )
