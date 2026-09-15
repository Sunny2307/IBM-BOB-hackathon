"""Self-pings this app's own /health endpoint so a free-tier host that spins
down idle services (e.g. Render's free plan, which sleeps after ~15 min of
no inbound traffic) never sees the app go idle.

No-op by design unless a public URL is known: on Render, `RENDER_EXTERNAL_URL`
is set automatically for every web service, so this activates itself on
deploy with zero configuration. Locally (and on any host that doesn't set
that var or SELF_PING_URL), the loop exits immediately and does nothing —
local dev behavior is unchanged.
"""

import asyncio
import os

import httpx

PING_INTERVAL_SECONDS = 5 * 60


def _self_url() -> str | None:
    return os.getenv("SELF_PING_URL") or os.getenv("RENDER_EXTERNAL_URL")


async def run_forever(interval_seconds: float = PING_INTERVAL_SECONDS) -> None:
    base_url = _self_url()
    if not base_url:
        return  # no public URL configured (e.g. local dev) — nothing to keep alive

    health_url = base_url.rstrip("/") + "/health"
    async with httpx.AsyncClient(timeout=10.0) as client:
        while True:
            await asyncio.sleep(interval_seconds)
            try:
                await client.get(health_url)
            except Exception as exc:  # noqa: BLE001 - deliberate: keep the loop alive
                print(f"[keepalive] self-ping failed ({exc.__class__.__name__}): {exc}")
