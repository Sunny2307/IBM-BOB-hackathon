"""Tests for the operator layer: auth, tenant isolation, alert idempotency.

The tenant-isolation test is the one that matters most. A multi-tenant system
that leaks across companies is worse than a single-tenant one, because it looks
safe. It is written first here on purpose.

These need a database. Without DATABASE_URL the whole module skips rather than
fails, so `pytest` still passes on a fresh clone with no Neon credentials —
matching how the app itself degrades.
"""

import os

import pytest
from dotenv import load_dotenv

load_dotenv()

from app import db  # noqa: E402
from app.services import auth, alert_monitor, grid_tools  # noqa: E402

pytestmark = pytest.mark.skipif(
    not os.getenv("DATABASE_URL"), reason="operator layer needs DATABASE_URL"
)

ALPHA = "__test_alpha_utilities"
BETA = "__test_beta_power"


@pytest.fixture(scope="module")
def tenants():
    """Two isolated companies with their own users and assignments, torn down
    afterwards so the demo seed data is never disturbed."""
    if not db.init():
        pytest.skip(f"database unavailable: {db.status()}")

    _purge()
    built = {}
    for company_name, email_prefix, region in (
        (ALPHA, "alpha", "North Valley"),
        (BETA, "beta", "Eastgate"),
    ):
        company = db.execute(
            "INSERT INTO companies (name) VALUES (%s) RETURNING id", (company_name,)
        )
        company_id = company["id"]

        users = {}
        for role in ("admin", "field"):
            pw_hash, pw_salt = auth.hash_password("TestPassword123")
            row = db.execute(
                """
                INSERT INTO users (company_id, email, full_name, password_hash,
                                   password_salt, role)
                VALUES (%s, %s, %s, %s, %s, %s) RETURNING id
                """,
                (company_id, f"{email_prefix}.{role}@test.invalid",
                 f"{email_prefix} {role}", pw_hash, pw_salt, role),
            )
            users[role] = row["id"]

        db.execute(
            "INSERT INTO assignments (company_id, user_id, scope_type, scope_value) "
            "VALUES (%s, %s, 'region', %s)",
            (company_id, users["field"], region),
        )
        built[company_name] = {"company_id": company_id, "users": users, "region": region}

    yield built
    _purge()


def _purge() -> None:
    db.execute("DELETE FROM companies WHERE name IN (%s, %s)", (ALPHA, BETA))


def _raise_alert(company_id: int, asset_id: str, region: str, tier: str = "Critical") -> int:
    row = db.execute(
        """
        INSERT INTO alerts (company_id, asset_id, asset_name, region, tier,
                            risk_score, headline)
        VALUES (%s, %s, %s, %s, %s, 91.0, 'test alert')
        RETURNING id
        """,
        (company_id, asset_id, f"Test {asset_id}", region, tier),
    )
    return row["id"]


# --------------------------------------------------------------- isolation


def test_a_company_cannot_see_another_companys_alerts(tenants):
    """THE test. Beta raises an alert; Alpha must not see it, in any role."""
    alpha, beta = tenants[ALPHA], tenants[BETA]
    _raise_alert(beta["company_id"], "AST-001", beta["region"])

    for role in ("admin", "field"):
        result = grid_tools.get_my_alerts(
            user_id=alpha["users"][role], company_id=alpha["company_id"], status="active"
        )
        assert result["count"] == 0, f"Alpha's {role} leaked a Beta alert"


def test_acknowledging_another_companys_alert_is_refused(tenants):
    """And it must fail as 'not visible', never 'forbidden' — a 403 would still
    confirm the row exists."""
    alpha, beta = tenants[ALPHA], tenants[BETA]
    alert_id = _raise_alert(beta["company_id"], "AST-002", beta["region"])

    result = grid_tools.acknowledge_alert(
        alert_id=alert_id, user_id=alpha["users"]["admin"], company_id=alpha["company_id"]
    )
    assert "error" in result

    still_open = db.query_one("SELECT status FROM alerts WHERE id = %s", (alert_id,))
    assert still_open["status"] == "open", "a cross-tenant ack mutated the row"


def test_field_crew_only_see_their_assigned_regions(tenants):
    """Same company, different scope: an unassigned region must not appear."""
    alpha = tenants[ALPHA]
    _raise_alert(alpha["company_id"], "AST-003", alpha["region"])
    _raise_alert(alpha["company_id"], "AST-004", "Riverside")  # not assigned to them

    field = grid_tools.get_my_alerts(
        user_id=alpha["users"]["field"], company_id=alpha["company_id"], status="active"
    )
    assert {a["region"] for a in field["alerts"]} == {alpha["region"]}

    admin = grid_tools.get_my_alerts(
        user_id=alpha["users"]["admin"], company_id=alpha["company_id"], status="active"
    )
    assert admin["count"] > field["count"], "admin should see the whole company"


# ------------------------------------------------------------------- auth


def test_password_round_trip_and_rejection():
    hashed, salt = auth.hash_password("correct horse battery staple")
    assert auth.verify_password("correct horse battery staple", hashed, salt)
    assert not auth.verify_password("Correct horse battery staple", hashed, salt)
    assert not auth.verify_password("", hashed, salt)


def test_password_hash_is_salted_per_user():
    """Two users with the same password must not share a digest, or one
    rainbow table lookup breaks every account at once."""
    first, _ = auth.hash_password("same-password")
    second, _ = auth.hash_password("same-password")
    assert first != second


def test_token_carries_identity_and_rejects_tampering():
    token = auth.create_token(
        {"id": 42, "company_id": 7, "role": "field", "email": "a@b.invalid"}
    )
    claims = auth.decode_token(token)
    assert claims["sub"] == "42"
    assert claims["company_id"] == 7
    assert claims["role"] == "field"

    from fastapi import HTTPException

    with pytest.raises(HTTPException) as excinfo:
        auth.decode_token(token[:-4] + "AAAA")
    assert excinfo.value.status_code == 401


def test_expired_token_is_rejected(monkeypatch):
    monkeypatch.setattr(auth, "TOKEN_TTL_HOURS", -1)
    token = auth.create_token(
        {"id": 1, "company_id": 1, "role": "admin", "email": "x@y.invalid"}
    )

    from fastapi import HTTPException

    with pytest.raises(HTTPException) as excinfo:
        auth.decode_token(token)
    assert excinfo.value.status_code == 401


def test_bad_login_returns_nothing_not_a_partial_user(tenants):
    assert auth.authenticate("alpha.admin@test.invalid", "wrong") is None
    assert auth.authenticate("nobody@test.invalid", "TestPassword123") is None
    assert auth.authenticate("alpha.admin@test.invalid", "TestPassword123") is not None


# -------------------------------------------------------- alert lifecycle


def test_monitor_raises_once_and_only_on_a_crossing(tenants):
    """The core claim: the fleet is re-scored every 13s, so a second pass over
    an unchanged fleet must raise nothing. Without this the app is a spam
    machine and every crew member mutes it."""
    alpha = tenants[ALPHA]
    db.execute("DELETE FROM alerts WHERE company_id = %s", (alpha["company_id"],))
    db.execute("DELETE FROM asset_tier_state WHERE company_id = %s", (alpha["company_id"],))

    first = alert_monitor.evaluate_company(alpha["company_id"])
    assert first["raised"] > 0, "expected some High/Critical assets in the demo fleet"

    second = alert_monitor.evaluate_company(alpha["company_id"])
    assert second["raised"] == 0, "a steady-state pass must not re-raise"
    assert second["unchanged"] > 0


def test_escalation_updates_in_place_rather_than_stacking(tenants):
    """High -> Critical is one alert that escalates, not two competing rows."""
    alpha = tenants[ALPHA]
    db.execute("DELETE FROM alerts WHERE company_id = %s", (alpha["company_id"],))
    db.execute("DELETE FROM asset_tier_state WHERE company_id = %s", (alpha["company_id"],))

    _raise_alert(alpha["company_id"], "AST-009", alpha["region"], tier="High")
    db.execute(
        "INSERT INTO asset_tier_state (company_id, asset_id, tier) VALUES (%s, 'AST-009', 'High')",
        (alpha["company_id"],),
    )

    open_rows = db.query(
        "SELECT id FROM alerts WHERE company_id = %s AND asset_id = 'AST-009' AND status <> 'resolved'",
        (alpha["company_id"],),
    )
    assert len(open_rows) == 1, "the partial unique index must allow only one open alert per asset"


def test_acknowledgement_records_who_and_when(tenants):
    alpha = tenants[ALPHA]
    alert_id = _raise_alert(alpha["company_id"], "AST-010", alpha["region"])

    result = grid_tools.acknowledge_alert(
        alert_id=alert_id, user_id=alpha["users"]["field"], company_id=alpha["company_id"]
    )
    assert result["status"] == "acknowledged"
    assert result["acknowledged_at"]

    row = db.query_one(
        "SELECT acknowledged_by, acknowledged_at FROM alerts WHERE id = %s", (alert_id,)
    )
    assert row["acknowledged_by"] == alpha["users"]["field"]
    assert row["acknowledged_at"] is not None


def test_assignments_drive_what_an_operator_owns(tenants):
    alpha = tenants[ALPHA]
    mine = grid_tools.get_my_assignments(
        user_id=alpha["users"]["field"], company_id=alpha["company_id"]
    )
    assert mine["count"] > 0
    assert mine["regions"] == [alpha["region"]]
    assert all(a["region"] == alpha["region"] for a in mine["assets"])
