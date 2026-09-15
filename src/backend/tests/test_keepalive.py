"""Proves the self-ping keepalive is a true no-op in local dev (no
RENDER_EXTERNAL_URL / SELF_PING_URL set) and picks the right URL when one
is configured, without ever making a real network call."""

import asyncio

from app.services import keepalive


def test_no_op_without_a_public_url(monkeypatch):
    monkeypatch.delenv("RENDER_EXTERNAL_URL", raising=False)
    monkeypatch.delenv("SELF_PING_URL", raising=False)

    # Must return immediately rather than looping/pinging forever.
    asyncio.run(asyncio.wait_for(keepalive.run_forever(), timeout=1.0))


def test_self_ping_url_prefers_explicit_override(monkeypatch):
    monkeypatch.setenv("RENDER_EXTERNAL_URL", "https://render-assigned.onrender.com")
    monkeypatch.setenv("SELF_PING_URL", "https://explicit-override.example.com")

    assert keepalive._self_url() == "https://explicit-override.example.com"


def test_self_ping_url_falls_back_to_render_external_url(monkeypatch):
    monkeypatch.delenv("SELF_PING_URL", raising=False)
    monkeypatch.setenv("RENDER_EXTERNAL_URL", "https://render-assigned.onrender.com")

    assert keepalive._self_url() == "https://render-assigned.onrender.com"
