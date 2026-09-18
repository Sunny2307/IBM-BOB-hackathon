-- Operator layer: the people and workflow around the risk engine.
--
-- Deliberately NOT here: assets, sensor readings, weather, risk scores. Those
-- stay in memory where they already work; this schema only answers "who owns
-- what, what just went wrong, and did a human take it". The join back to the
-- risk engine is the asset_id string (AST-0NN), which is stable because the
-- data generator is seeded.
--
-- Applied idempotently at startup by app/db.py. No migration tool: four tables
-- do not justify Alembic for this MVP.

CREATE TABLE IF NOT EXISTS companies (
    id          SERIAL PRIMARY KEY,
    name        TEXT NOT NULL UNIQUE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS users (
    id             SERIAL PRIMARY KEY,
    company_id     INTEGER NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    email          TEXT NOT NULL UNIQUE,
    full_name      TEXT NOT NULL,
    -- scrypt digest + its per-user salt. Never a plaintext password, and never
    -- logged; see app/services/auth.py.
    password_hash  TEXT NOT NULL,
    password_salt  TEXT NOT NULL,
    role           TEXT NOT NULL CHECK (role IN ('admin', 'field')),
    is_active      BOOLEAN NOT NULL DEFAULT TRUE,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_users_company ON users(company_id);

-- Who is responsible for which assets. scope_type='region' covers a whole
-- region in one row (the usable granularity on a phone); scope_type='asset'
-- pins a single asset. One table serves both.
CREATE TABLE IF NOT EXISTS assignments (
    id           SERIAL PRIMARY KEY,
    company_id   INTEGER NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    user_id      INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    scope_type   TEXT NOT NULL CHECK (scope_type IN ('region', 'asset')),
    scope_value  TEXT NOT NULL,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (user_id, scope_type, scope_value)
);

CREATE INDEX IF NOT EXISTS idx_assignments_company ON assignments(company_id);

-- One row per UPWARD crossing into High/Critical. Not one row per evaluation:
-- the live simulator re-scores every 13 seconds, so "insert when tier is
-- Critical" would generate thousands of duplicates and train users to ignore
-- the app. previous_tier records what it crossed from, which is what makes the
-- alert readable ("Medium -> Critical").
CREATE TABLE IF NOT EXISTS alerts (
    id               SERIAL PRIMARY KEY,
    company_id       INTEGER NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    asset_id         TEXT NOT NULL,
    asset_name       TEXT NOT NULL,
    region           TEXT NOT NULL,
    tier             TEXT NOT NULL CHECK (tier IN ('High', 'Critical')),
    previous_tier    TEXT,
    risk_score       REAL NOT NULL,
    headline         TEXT NOT NULL,
    status           TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'acknowledged', 'resolved')),
    raised_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    acknowledged_by  INTEGER REFERENCES users(id) ON DELETE SET NULL,
    acknowledged_at  TIMESTAMPTZ,
    resolved_at      TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_alerts_company_status ON alerts(company_id, status);

-- Only one alert may be open per asset per company at a time. This is the
-- database enforcing idempotency rather than trusting the monitor loop to get
-- it right under a restart or two workers.
CREATE UNIQUE INDEX IF NOT EXISTS idx_alerts_one_open_per_asset
    ON alerts(company_id, asset_id) WHERE status <> 'resolved';

-- The monitor's memory of what tier each asset was in last time it looked.
-- Without this there is no way to tell a crossing from a steady state.
CREATE TABLE IF NOT EXISTS asset_tier_state (
    company_id  INTEGER NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    asset_id    TEXT NOT NULL,
    tier        TEXT NOT NULL,
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (company_id, asset_id)
);
