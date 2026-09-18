"""Forces a fresh alert so you can show the notification on demand.

Alerts normally fire only when an asset genuinely drifts UP a risk tier, which
is the correct behaviour and completely useless for a live demo — you cannot
schedule a transformer to degrade during your four-minute slot. This script
makes that crossing happen now, through the real code path: it resolves the
asset's current alert, forgets its remembered tier, and runs one real
alert_monitor pass. Nothing is faked; the monitor raises the alert itself.

Usage:
    python scripts/trigger_demo_alert.py                  # auto-pick the worst asset
    python scripts/trigger_demo_alert.py AST-022          # a specific asset
    python scripts/trigger_demo_alert.py --for ravi@grid.demo   # one on THEIR phone

The phone then shows it within one poll cycle (<=30s). Make sure the app is
signed in and has already polled once — the first poll of a session is
deliberately silent so opening the app does not fire your whole backlog.
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from dotenv import load_dotenv

load_dotenv()

from app import db  # noqa: E402
from app.services import alert_monitor, risk_engine  # noqa: E402


def pick_asset(company_id: int, for_email: str | None) -> str:
    """The highest-risk asset that will actually reach the person you name."""
    scored = sorted(risk_engine.score_all_assets(), key=lambda a: -a["risk_score"])
    candidates = [a for a in scored if a["risk_tier"] in ("High", "Critical")]
    if not candidates:
        raise SystemExit("No asset is currently High or Critical — nothing would be raised.")

    if for_email:
        user = db.query_one(
            "SELECT id, full_name FROM users WHERE lower(email) = lower(%s) AND company_id = %s",
            (for_email, company_id),
        )
        if user is None:
            raise SystemExit(f"No user {for_email} in company {company_id}.")
        regions = {
            r["scope_value"]
            for r in db.query(
                "SELECT scope_value FROM assignments WHERE user_id = %s AND scope_type = 'region'",
                (user["id"],),
            )
        }
        scoped = [a for a in candidates if a["region"] in regions]
        if not scoped:
            raise SystemExit(
                f"{user['full_name']} owns {sorted(regions) or 'no regions'}, "
                "none of which currently hold a High/Critical asset."
            )
        candidates = scoped

    return candidates[0]["asset_id"]


def main() -> None:
    args = [a for a in sys.argv[1:]]
    for_email = None
    if "--for" in args:
        index = args.index("--for")
        for_email = args[index + 1]
        del args[index : index + 2]
    asset_id = args[0].upper() if args else None

    if not db.init():
        raise SystemExit(f"Database not available: {db.status()}")

    company = db.query_one("SELECT id, name FROM companies ORDER BY id LIMIT 1")
    if company is None:
        raise SystemExit("No company yet — run scripts/seed_operators.py first.")
    company_id = company["id"]

    asset_id = asset_id or pick_asset(company_id, for_email)
    asset = next(
        (a for a in risk_engine.score_all_assets() if a["asset_id"] == asset_id), None
    )
    if asset is None:
        raise SystemExit(f"No such asset: {asset_id}")
    if asset["risk_tier"] not in ("High", "Critical"):
        raise SystemExit(
            f"{asset_id} is {asset['risk_tier']}; the monitor only alerts on High/Critical. "
            "Pick another asset, or let the simulator push this one up."
        )

    # Clear the two pieces of state that make the monitor idempotent, so the
    # very next pass sees a genuine crossing rather than a steady state.
    db.execute(
        "UPDATE alerts SET status = 'resolved', resolved_at = now() "
        "WHERE company_id = %s AND asset_id = %s AND status <> 'resolved'",
        (company_id, asset_id),
    )
    db.execute(
        "DELETE FROM asset_tier_state WHERE company_id = %s AND asset_id = %s",
        (company_id, asset_id),
    )

    counts = alert_monitor.evaluate_company(company_id)

    raised = db.query_one(
        "SELECT id, asset_name, tier, headline FROM alerts "
        "WHERE company_id = %s AND asset_id = %s AND status = 'open' "
        "ORDER BY id DESC LIMIT 1",
        (company_id, asset_id),
    )

    if raised is None:
        raise SystemExit(f"Monitor ran {counts} but raised nothing for {asset_id}.")

    recipients = db.query(
        """
        SELECT u.full_name, u.email, u.role
        FROM users u
        WHERE u.company_id = %s
          AND (u.role = 'admin' OR EXISTS (
                SELECT 1 FROM assignments a
                WHERE a.user_id = u.id
                  AND ((a.scope_type = 'region' AND a.scope_value = %s)
                    OR (a.scope_type = 'asset'  AND a.scope_value = %s))))
        ORDER BY u.role, u.full_name
        """,
        (company_id, asset["region"], asset_id),
    )

    print(f"Raised alert #{raised['id']} — {raised['tier']} on {raised['asset_name']}")
    print(f"  {raised['headline']}")
    print(f"  monitor pass: {counts}")
    print("\nWill appear for:")
    for person in recipients:
        print(f"  {person['full_name']:14} {person['email']:20} ({person['role']})")
    print("\nThe phone polls every 30s — the notification lands within that.")

    db.close()


if __name__ == "__main__":
    main()
