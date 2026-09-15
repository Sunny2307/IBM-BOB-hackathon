# Task: Live public-URL deployment setup

Date: 2026-09-15
Flow: FEATURE (opted out of brainstorm/plan gate — user gave explicit
build instructions across two messages: "set up for it without affecting
anything our existing things" + concrete self-ping directive + "then make
the setup")

## Brainstorm
N/A — user opted out (explicit "do that" / "then make the setup" directives).
Platform choice inferred from user's own self-ping hint (Render free-tier
sleep behavior is the only common host that needs a self-ping workaround) +
tech stack (FastAPI backend, Vite/React frontend) → Render (backend) +
Vercel (frontend), both free tier, both deploy straight from the existing
GitHub repo (origin: Sunny2307/bob-ai-hackathon-Fantsactic_Four).

## Plan
1. `app/services/keepalive.py` — new background asyncio task, same shape as
   `live_simulator.run_forever()`, pings its own `/health` every 5 min via
   httpx. No-ops locally (only runs if `RENDER_EXTERNAL_URL` or
   `SELF_PING_URL` env var is set) — zero effect on local dev.
2. Wire it into `main.py` lifespan alongside the existing nudger task.
3. `main.py` CORS: `FRONTEND_ORIGIN` becomes comma-separated-aware so a
   deployed Vercel origin can be added without removing the local ones.
4. `render.yaml` (Blueprint) at repo root — backend web service, free plan,
   build = install + generate synthetic data, start = uvicorn on `$PORT`.
5. `src/frontend/vercel.json` — minimal Vite framework config.
6. `docs/setup-guide.md` — append a new "Deploy live" section (existing
   sections untouched).
7. `.env.example` (backend + frontend) — document the new/changed vars.

## Constraint
Cannot create Render/Vercel accounts or click deploy on the user's behalf —
final connect-repo-and-deploy step is manual, documented step by step.

## Security Gate
Status: PASSED
Findings:
- ✅ No new user inputs / injection surface
- ✅ No auth/permission bypass (app has no auth system — pre-existing, unrelated)
- ✅ No new API endpoints
- ✅ No new dependencies
- ✅ keepalive ping URL comes only from platform/deployer-set env vars, never attacker input
- ✅ GROQ_API_KEY stays uncommitted (`sync: false` in render.yaml)
- ✅ No hardcoded secrets
- 🟡 WARNING: npm install cooldown not configured in src/frontend (pre-existing, unrelated — suggest `/npm-protect` separately)

## Code Review
Status: APPROVED
Notes:
- ✅ keepalive no-ops locally with zero overhead (live-verified + unit tested)
- ✅ CORS origin handling is backward-compatible (comma-separated, existing single-origin .env files still work)
- ✅ render.yaml / vercel.json syntactically valid
- ✅ Full test suite green: 26/26 (23 pre-existing + 3 new)
- ✅ docs/setup-guide.md local-dev sections untouched, new section appended
- ✅ No secrets committed

## Files changed
- src/backend/app/services/keepalive.py (new)
- src/backend/app/main.py (wire in keepalive task, comma-separated FRONTEND_ORIGIN)
- src/backend/.env.example (SELF_PING_URL, updated FRONTEND_ORIGIN comment)
- src/backend/tests/test_keepalive.py (new)
- src/frontend/.env.example (production VITE_API_BASE_URL comment)
- src/frontend/vercel.json (new)
- render.yaml (new, repo root)
- docs/setup-guide.md (new "Deploy live" section appended)

## Remaining manual steps (cannot be automated — require the user's own accounts)
1. Render dashboard: New Blueprint Instance -> connect repo -> deploy backend
2. Vercel dashboard: import repo, root dir = src/frontend -> deploy frontend
3. Set VITE_API_BASE_URL on Vercel to the Render URL
4. Set FRONTEND_ORIGIN on Render to include the Vercel URL
5. Update demo/live-demo-url.txt with the final public URL

## Verification
Status: PASSED (code side)
Command: pytest (src/backend)
Exit code: 0
Output: 26 passed (23 pre-existing + 3 new), 0 failed
Config validation: render.yaml (valid YAML, exit 0), vercel.json (valid JSON, exit 0)
Smoke check: PASSED — fresh uvicorn start, /health + /assets responded correctly,
keepalive confirmed to no-op locally with zero background activity
Not verifiable here: actual Render/Vercel deploy (requires user's own account login)

## Status
DONE (code + config + docs + gates + verification). BLOCKED only on the
manual account-linked deploy steps above, which require the user's own
Render/Vercel login — see docs/setup-guide.md "Deploy live" section.
Completed: 2026-09-15
