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
                 RETURNING id
                """,
                (company_id, asset_id),
            )
            if resolved:
                counts["resolved"] += 1

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
