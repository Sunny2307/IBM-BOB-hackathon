"""Postgres access for the operator layer — connection pool, query helpers,
and idempotent schema setup.

DEGRADES BY DESIGN. If DATABASE_URL is unset, or Neon is unreachable, or the
schema fails to apply, the app still boots and every pre-existing route
(/assets, /maintenance-plan, /copilot/ask, /health) keeps working exactly as
before. Only the operator routes go dark, with a clean 503. This is the same
discipline as weather_live.py falling back to the seeded forecast: a hackathon
demo must never be one flaky dependency away from a blank screen.

No ORM on purpose: four tables and a dozen queries do not justify SQLAlchemy
plus a schema DSL, and raw SQL keeps every query inspectable. Parameters are
always passed as psycopg placeholders, never string-formatted, so there is no
injection surface.
"""

import os
from pathlib import Path
from typing import Any

from psycopg.rows import dict_row
from psycopg_pool import ConnectionPool

SCHEMA_PATH = Path(__file__).resolve().parent / "schema.sql"

_pool: ConnectionPool | None = None
_init_error: str | None = None


class DatabaseUnavailable(RuntimeError):
    """Raised by query/execute when there is no usable database. Routers turn
    this into a 503 rather than a 500 — it is a missing dependency, not a bug
    in the request."""


def is_available() -> bool:
    return _pool is not None


def status() -> str:
    """Human-readable DB state for /health, so 'why is login failing' is one
    curl away instead of a log dig."""
    if _pool is not None:
        return "connected"
    return _init_error or "not configured (DATABASE_URL unset)"


def init() -> bool:
    """Opens the pool and applies schema.sql. Returns True on success. Never
    raises — callers (app startup) must not die because the DB is down."""
    global _pool, _init_error

    database_url = os.getenv("DATABASE_URL")
    if not database_url:
        _init_error = "not configured (DATABASE_URL unset)"
        return False

    try:
        pool = ConnectionPool(
            database_url,
            min_size=1,
            max_size=5,
            open=True,
            timeout=10.0,
            # Neon closes idle connections (it scales to zero between bursts),
            # so a pooled socket that sat overnight is dead on arrival. Without
            # `check` the pool hands those out anyway and every operator route
            # — sign-in included — starts failing with PoolTimeout until
            # someone restarts the process. That was a real outage, not a
            # theoretical one.
            #
            # `check_connection` validates a connection before lending it and
            # quietly replaces a dead one; `max_idle` retires idle connections
            # on our own schedule rather than waiting for Neon to cut them.
            check=ConnectionPool.check_connection,
            max_idle=120.0,
            kwargs={"row_factory": dict_row},
        )
        with pool.connection() as conn:
            conn.execute(SCHEMA_PATH.read_text())
    except Exception as exc:  # noqa: BLE001 - deliberate: a dead DB must not stop startup
        _init_error = f"unavailable ({exc.__class__.__name__}: {exc})"
        _pool = None
        return False

    _pool = pool
    _init_error = None
    return True


def close() -> None:
    global _pool
    if _pool is not None:
        _pool.close()
        _pool = None


def _require_pool() -> ConnectionPool:
    if _pool is None:
        raise DatabaseUnavailable(
            f"Operator features need a database; it is {status()}. "
            "Set DATABASE_URL and restart. The risk engine and dashboard are unaffected."
        )
    return _pool


def query(sql: str, params: tuple | dict | None = None) -> list[dict[str, Any]]:
    with _require_pool().connection() as conn:
        with conn.cursor() as cur:
            cur.execute(sql, params)
            return cur.fetchall()


def query_one(sql: str, params: tuple | dict | None = None) -> dict[str, Any] | None:
    rows = query(sql, params)
    return rows[0] if rows else None


def execute(sql: str, params: tuple | dict | None = None) -> dict[str, Any] | None:
    """Runs a write. Returns the first row when the statement RETURNS, else None."""
    with _require_pool().connection() as conn:
        with conn.cursor() as cur:
            cur.execute(sql, params)
            if cur.description is None:
                return None
            row = cur.fetchone()
            return row
