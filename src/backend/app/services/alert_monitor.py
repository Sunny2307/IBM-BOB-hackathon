"""Raises an alert when an asset CROSSES UP into High or Critical.

This distinction is the whole feature. `live_simulator` re-scores every asset
every 13 seconds, so a naive "insert a row whenever tier == Critical" would
produce thousands of duplicate alerts a day and train every crew member to
swipe the app away. Instead the monitor remembers the tier each asset was in
last time it looked (`asset_tier_state`) and acts only on a transition:

    Medium -> High      -> raise
    High   -> Critical  -> raise (escalation; replaces the open alert's tier)
    Critical -> Medium  -> resolve the open alert
    Critical -> Critical-> nothing

Idempotency is enforced twice on purpose: this loop checks the stored tier, AND
the database holds a partial unique index allowing only one non-resolved alert
per asset per company. Belt and braces, because a restart mid-loop or a second
worker process would otherwise double-alert.

Runs as a background asyncio task alongside live_simulator and keepalive, on
the same never-raise-out-of-the-loop pattern: a transient failure here must not
take down the API.
"""

import asyncio
from datetime import datetime, timezone

from app import db
from app.services import risk_engine

TICK_SECONDS = 60.0

# An alert is never auto-resolved before this much time has passed since it was
# raised.
#
# Without it the feature flaps: live_simulator nudges every score every 13
# seconds, so an asset sitting near the High boundary (50) crosses back and
# forth, and the monitor raises then resolves an alert on almost every tick.
# The observed damage was four raise/resolve cycles on one asset, and a
# hand-raised alert disappearing ~60s after an admin sent it — before the
# recipient's phone had polled. A crew member must have time to actually see
# an alert; a risk that genuinely subsides will still resolve on a later tick.
RESOLVE_GRACE_SECONDS = 600

# Tiers worth waking a human for, and their ordering. Anything below High is
# tracked but never alerted.
ALERTABLE = {"High", "Critical"}
TIER_RANK = {"Low": 0, "Medium": 1, "High": 2, "Critical": 3}

_last_run: str | None = None


def get_last_run() -> str | None:
    return _last_run


def _headline(asset: dict, previous_tier: str | None) -> str:
    """The one line a crew member reads on a lock screen. It has to say what
    changed, where, and how bad — in that order."""
    movement = f"{previous_tier} to {asset['risk_tier']}" if previous_tier else asset["risk_tier"]
    return (
        f"{asset['name']} ({asset['region']}) moved {movement} — "
        f"risk {asset['risk_score']}/100, {asset['customers_served']:,} customers downstream."
    )


def evaluate_company(company_id: int) -> dict[str, int]:
    """One pass over the fleet for one company. Returns a small counts dict so
    callers and tests can assert on what happened rather than scrape logs."""
    counts = {"raised": 0, "escalated": 0, "resolved": 0, "unchanged": 0}

    previous = {
        row["asset_id"]: row["tier"]
        for row in db.query(
            "SELECT asset_id, tier FROM asset_tier_state WHERE company_id = %s",
            (company_id,),
        )
    }

    for asset in risk_engine.score_all_assets():
        asset_id = asset["asset_id"]
        tier = asset["risk_tier"]
        previous_tier = previous.get(asset_id)

        if previous_tier == tier:
            counts["unchanged"] += 1
            continue

        rose = previous_tier is None or TIER_RANK[tier] > TIER_RANK.get(previous_tier, -1)

        if tier in ALERTABLE and rose:
            # ON CONFLICT covers the partial unique index: if an alert is
            # already open for this asset, escalate it in place instead of
            # stacking a second one.
            existing = db.query_one(
                "SELECT id, tier FROM alerts WHERE company_id = %s AND asset_id = %s "
                "AND status <> 'resolved'",
                (company_id, asset_id),
            )
            if existing is None:
                db.execute(
                    """
                    INSERT INTO alerts (company_id, asset_id, asset_name, region, tier,
                                        previous_tier, risk_score, headline)
                    VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
                    RETURNING id
                    """,
                    (company_id, asset_id, asset["name"], asset["region"], tier,
                     previous_tier, asset["risk_score"], _headline(asset, previous_tier)),
                )
                counts["raised"] += 1
            elif TIER_RANK[tier] > TIER_RANK.get(existing["tier"], -1):
                db.execute(
                    """
                    UPDATE alerts
                       SET tier = %s, risk_score = %s, headline = %s,
                           previous_tier = %s, status = 'open',
                           acknowledged_by = NULL, acknowledged_at = NULL
                     WHERE id = %s
                    """,
                    (tier, asset["risk_score"], _headline(asset, previous_tier),
                     previous_tier, existing["id"]),
                )
                # An escalation un-acknowledges: "I've seen the High" is not
                # the same as "I've seen the Critical".
                counts["escalated"] += 1

        elif tier not in ALERTABLE and previous_tier in ALERTABLE:
            resolved = db.execute(
                """
                UPDATE alerts SET status = 'resolved', resolved_at = now()
                 WHERE company_id = %s AND asset_id = %s AND status <> 'resolved'
                   AND raised_at < now() - make_interval(secs => %s)
                 RETURNING id
                """,
                (company_id, asset_id, RESOLVE_GRACE_SECONDS),
            )
            if resolved:
                counts["resolved"] += 1
            else:
                # Still inside the grace window. Leave the alert standing AND
                # leave asset_tier_state alone, so the next tick re-evaluates
                # this same transition instead of recording the drop and
                # never resolving the alert at all.
                counts["unchanged"] += 1
                continue

        db.execute(
            """
            INSERT INTO asset_tier_state (company_id, asset_id, tier)
            VALUES (%s, %s, %s)
            ON CONFLICT (company_id, asset_id)
            DO UPDATE SET tier = EXCLUDED.tier, updated_at = now()
            """,
            (company_id, asset_id, tier),
        )

    return counts


def tick() -> dict[str, int]:
    """One pass for every company. Safe to call directly (tests, startup)."""
    global _last_run
    totals = {"raised": 0, "escalated": 0, "resolved": 0, "unchanged": 0}

    for company in db.query("SELECT id FROM companies"):
        counts = evaluate_company(company["id"])
        for key in totals:
            totals[key] += counts[key]

    _last_run = datetime.now(timezone.utc).isoformat()
    return totals


async def run_forever(interval_seconds: float = TICK_SECONDS) -> None:
    """Background task. Never raises out of the loop — a DB blip must not take
    the API down with it."""
    while True:
        await asyncio.sleep(interval_seconds)
        if not db.is_available():
            continue
        try:
            counts = tick()
            if counts["raised"] or counts["escalated"] or counts["resolved"]:
                print(f"[alert_monitor] {counts}")
        except Exception as exc:  # noqa: BLE001 - deliberate: keep the loop alive
            print(f"[alert_monitor] tick failed ({exc.__class__.__name__}): {exc}")

# ---------------------------------------------------------------------------
# Manual raise — the admin "Send alert" button.
#
# Lives here, next to the automatic monitor, so a hand-raised alert is
# indistinguishable from a monitored one: same headline wording, same table,
# same one-open-alert-per-asset rule. A separate "test notification" path would
# have drifted from the real thing and proved nothing.
# ---------------------------------------------------------------------------


def scope_for_user(user_id: int, company_id: int) -> tuple[set[str], set[str]]:
    rows = db.query(
        "SELECT scope_type, scope_value FROM assignments WHERE user_id = %s AND company_id = %s",
        (user_id, company_id),
    )
    regions = {r["scope_value"] for r in rows if r["scope_type"] == "region"}
    asset_ids = {r["scope_value"] for r in rows if r["scope_type"] == "asset"}
    return regions, asset_ids


def assets_visible_to(user_id: int, company_id: int) -> list[dict]:
    """Every asset this user is on the hook for, highest risk first.

    An admin with no assignments is treated as seeing the whole fleet, matching
    how get_my_alerts already treats admins.
    """
    role_row = db.query_one(
        "SELECT role FROM users WHERE id = %s AND company_id = %s", (user_id, company_id)
    )
    scored = sorted(risk_engine.score_all_assets(), key=lambda a: a["risk_score"], reverse=True)

    regions, asset_ids = scope_for_user(user_id, company_id)
    if not regions and not asset_ids:
        if role_row is not None and role_row["role"] == "admin":
            return scored
        return []
    return [a for a in scored if a["region"] in regions or a["asset_id"] in asset_ids]


def raise_alert_for_user(user_id: int, company_id: int, asset_id: str | None = None) -> dict:
    """Raises (or escalates) one alert on an asset the target user can see.

    Returns the alert row. Raises ValueError with a message meant to be shown
    to the admin verbatim — the failure modes here are all things the admin can
    actually fix (no assignments, wrong asset), so a vague 400 would be unkind.
    """
    visible = assets_visible_to(user_id, company_id)
    if not visible:
        raise ValueError(
            "That user has no assignments yet, so no alert can reach them. "
            "Assign them a region first, then send again."
        )

    if asset_id is None:
        asset = visible[0]
    else:
        asset = next((a for a in visible if a["asset_id"] == asset_id), None)
        if asset is None:
            raise ValueError(
                f"{asset_id} is outside that user's assignments, so they would "
                "never see the alert. Pick an asset in a region assigned to them."
            )

    # Hand-raised alerts always read as at least High — below that the crew app
    # deliberately does not notify, so a 'sent' alert that silently vanished
    # would be worse than an error.
    tier = asset["risk_tier"] if asset["risk_tier"] in ALERTABLE else "High"
    previous_tier = (
        db.query_one(
            "SELECT tier FROM asset_tier_state WHERE company_id = %s AND asset_id = %s",
            (company_id, asset["asset_id"]),
        )
        or {}
    ).get("tier")

    existing = db.query_one(
        "SELECT id, tier FROM alerts WHERE company_id = %s AND asset_id = %s "
        "AND status <> 'resolved'",
        (company_id, asset["asset_id"]),
    )

    # "moved Critical to Critical" is nonsense on a hand-raised alert for an
    # asset that was already there; drop the from-tier when nothing changed.
    movement_from = previous_tier if previous_tier != tier else None
    headline = _headline({**asset, "risk_tier": tier}, movement_from)

    if existing is None:
        row = db.execute(
            """
            INSERT INTO alerts (company_id, asset_id, asset_name, region, tier,
                                previous_tier, risk_score, headline)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
            RETURNING id, asset_id, asset_name, region, tier, risk_score, headline,
                      status, raised_at
            """,
            (company_id, asset["asset_id"], asset["name"], asset["region"], tier,
             previous_tier, asset["risk_score"], headline),
        )
    else:
        # Re-open rather than stack a duplicate: the partial unique index only
        # allows one live alert per asset.
        #
        # `raised_at = now()` is load-bearing, not cosmetic. The crew app
        # de-duplicates notifications by (id, raised_at, tier), so without this
        # bump a re-sent alert keeps the id it already had, looks like an alert
        # the phone has seen before, and silently fires nothing — which is
        # exactly the bug an admin pressing "Send alert" would report.
        row = db.execute(
            """
            UPDATE alerts
               SET tier = %s, risk_score = %s, headline = %s, status = 'open',
                   acknowledged_by = NULL, acknowledged_at = NULL, resolved_at = NULL,
                   raised_at = now()
             WHERE id = %s
            RETURNING id, asset_id, asset_name, region, tier, risk_score, headline,
                      status, raised_at
            """,
            (tier, asset["risk_score"], headline, existing["id"]),
        )

    # Keep the monitor's memory in step, or its next tick would see this as an
    # unchanged tier and never resolve the alert afterwards.
    db.execute(
        """
        INSERT INTO asset_tier_state (company_id, asset_id, tier)
        VALUES (%s, %s, %s)
        ON CONFLICT (company_id, asset_id)
        DO UPDATE SET tier = EXCLUDED.tier, updated_at = now()
        """,
        (company_id, asset["asset_id"], tier),
    )

    return row
