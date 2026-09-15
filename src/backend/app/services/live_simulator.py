"""Makes the in-memory synthetic data feel alive without any external infra:
every ~13 seconds, `tick()` perturbs each asset's most recent sensor reading
by a small, bounded, mean-reverting random-walk delta.

No database, no cache-invalidation dance needed: data_loader.get_sensor_series
already returns the SAME list object held inside its lru_cache'd structure, so
mutating the dicts in that list in place is immediately visible to every
future call to risk_engine.compute_risk_breakdown / score_all_assets — the
next /assets fetch reflects the nudge with no process restart.

This is purely additive new randomness layered on top of the deterministic,
fixed-seed synthetic data generation in scripts/generate_synthetic_data.py
(which is a separate, one-off process and is never touched by this module).
Deltas are bounded per metric and mean-revert toward each asset's own 15-day
baseline so scores drift realistically instead of wandering off to nonsense
over a long-running process.
"""

import asyncio
import random
import statistics
from datetime import datetime, timezone

from app.services import data_loader

TICK_SECONDS = 13.0

# (low, high) plausible absolute bounds per metric, and the max per-tick step.
_METRIC_BOUNDS = {
    "temperature": (20.0, 160.0),
    "vibration": (0.0, 15.0),
    "partial_discharge": (0.0, 300.0),
    "oil_quality": (0.0, 100.0),
}
_METRIC_STEP = {
    "temperature": 0.6,
    "vibration": 0.08,
    "partial_discharge": 3.0,
    "oil_quality": 1.2,
}
_REVERSION_FRACTION = 0.05  # pull a small fraction of the way back toward baseline each tick

_last_updated: str | None = None


def get_last_updated() -> str | None:
    """ISO-8601 UTC timestamp of the last successful nudge cycle, or None if
    the background simulator hasn't ticked yet (e.g. app just started)."""
    return _last_updated


def _baseline_mean(series: list[dict], metric: str) -> float:
    values = [row[metric] for row in series]
    baseline = values[:15] if len(values) >= 15 else values
    return statistics.fmean(baseline) if baseline else 0.0


def tick() -> None:
    """One nudge pass over every asset's most recent sensor reading. Safe to
    call directly (e.g. once at startup) as well as from run_forever()."""
    global _last_updated
    for asset in data_loader.get_assets():
        series = data_loader.get_sensor_series(asset["asset_id"])
        if not series:
            continue
        latest = series[-1]
        for metric, (low, high) in _METRIC_BOUNDS.items():
            baseline = _baseline_mean(series, metric)
            step = _METRIC_STEP[metric]
            delta = random.uniform(-step, step)
            reverted = latest[metric] + delta + (baseline - latest[metric]) * _REVERSION_FRACTION
            latest[metric] = round(max(low, min(high, reverted)), 2)
    _last_updated = datetime.now(timezone.utc).isoformat()


async def run_forever(interval_seconds: float = TICK_SECONDS) -> None:
    """Background asyncio task: nudges the data every `interval_seconds`.
    Never raises out of the loop — a failed tick is logged and skipped so a
    transient bug here can't take the whole app down."""
    while True:
        await asyncio.sleep(interval_seconds)
        try:
            tick()
        except Exception as exc:  # noqa: BLE001 - deliberate: keep the loop alive
            print(f"[live_simulator] tick failed ({exc.__class__.__name__}): {exc}")
