# Grid Failure Advisor — Build Notes

Built 2026-09-15 for the IBM BoB AI Innovation Hackathon 2026 (deadline
11:45 PM same day, U1 problem statement — Power Outage Prediction & Grid
Equipment Failure Advisor). See [u1-grid-failure-advisor.md](../../../u1-grid-failure-advisor.md)
for the original execution plan.

## Stack
Python FastAPI backend (`src/backend`) + React/Vite/TS frontend
(`src/frontend`), synthetic data (deterministic generator, seed 42), MCP
server for IBM Bob integration.

## Key decisions and why
- **Rule-based risk scoring, not ML** — explainability and speed under time
  pressure; every point of the 0-100 score traces to a named factor. See
  `app/services/risk_engine.py`.
- **MCP server and the in-app Copilot share one implementation**
  (`app/services/grid_tools.py`) — this is what makes "IBM Bob integration"
  load-bearing rather than name-dropped. Verified: `mcp.call_tool()` returns
  the same numbers the dashboard shows.
- **Deterministic Copilot, no LLM key required** — protects the live demo
  from Wi-Fi/API-key failures.
- **mcp pinned to `>=1.28.1,<2.0.0`** — mcp 2.x renamed `FastMCP` to
  `MCPServer` (breaking API change); pinned below that line to keep the
  patched-CVE 1.x line without a rewrite under time pressure.

## Verification performed (not just "should work")
- Backend: curl against every endpoint with real generated data
- MCP: `asyncio.run(mcp.call_tool(...))` returns real, matching data
- Frontend: Playwright drove the actual running app (dashboard → asset
  detail → maintenance plan → copilot), screenshotted all 4 states, zero
  console errors, confirmed no "DEMO DATA" fallback banner anywhere
- Security: pip-audit + npm audit run, real CVEs found (starlette/mcp/
  python-dotenv/setuptools) and fixed by upgrading; re-verified nothing
  broke; independent security-auditor agent pass found only two
  low-severity/non-exploitable input-constraint items, which were hardened
  anyway (Pydantic `Field` + `Path` regex)

## What's NOT done (human-only, cannot be automated)
1. Real team name and roster (placeholder: "Grid Failure Advisors" /
   Malay Sheta, inferred from session email — needs confirmation)
2. Demo video recording — `demo/demo-video-link.txt` still has the
   template's placeholder URL; this is the one item that will fail the
   repo's `validate.yml` GitHub Action until fixed
3. `git add`/commit/push — nothing has been pushed; local verification only

## 2026-09-15 follow-up: Copilot LLM upgrade + UI/dynamism revamp

User feedback after the initial build: the app looked generic/AI-generated,
the Copilot gave irrelevant answers, and the UI felt "fully static." Full
task record: [2026-09-15-copilot-and-ui-revamp.md](../tasks/2026-09-15-copilot-and-ui-revamp.md).

### What changed
- **Copilot is no longer purely deterministic.** It now tries a
  **Groq-powered, tool-calling LLM** first (`app/services/llm_copilot.py`),
  grounded on the same `grid_tools.py` functions the deterministic router
  and MCP server already use — so it can't invent asset IDs/scores, only
  report what a tool call actually returned. `.env.example`'s
  `GROQ_API_KEY`/`GROQ_MODEL`/`LLM_PROVIDER=groq|none` replace the old
  unimplemented `LLM_API_KEY` stub. **The original deterministic router is
  the fallback for ANY failure** (no key, timeout, malformed response) —
  the "zero dependency on a live API key" demo-resilience decision from the
  original build is preserved, not undone.
- **Groq was chosen over a paid provider** because the user had no paid API
  key — it's free-tier, no credit card, fast open models, OpenAI-compatible
  endpoint (easy to swap providers later via the same `LLM_PROVIDER` env
  pattern).
- **Data is no longer frozen at process start.** `app/services/live_simulator.py`
  runs a background asyncio task every ~13s that nudges sensor readings with
  a small bounded, mean-reverting random walk, mutating the same list object
  `data_loader` caches (no cache-invalidation dance needed). `/health` now
  reports `last_updated`.
- **Frontend gained a map** (`GridMap.tsx`, react-leaflet + free OSM tiles,
  no API key) — assets were always geo-tagged (`lat`/`lon`) but nothing
  rendered them; this was flagged as a specific missed opportunity. Also
  added: stat tiles, skeleton loaders, CSS-only page transitions, a
  hand-rolled bold/bullet formatter for LLM answers (`FormattedAnswer.tsx`,
  deliberately not `dangerouslySetInnerHTML` — verified by security review),
  and an unmissable full-width banner when mock-data fallback is showing
  (previously an easy-to-miss small banner, which is likely why connectivity
  hiccups "felt static").
- Design direction was **explicitly picked to avoid generic-AI-template
  tells** (no bento grids, no glassmorphism, no mesh gradients, no default
  dark+neon) — kept the existing Carbon-token/IBM Plex base but sharpened
  it: smaller corner radii, risk-tier colors used as bold accents (map pins,
  card borders, stat tiles) rather than just small badges.

### How this was built (process note, useful if repeating the pattern)
Two agents ran **concurrently** — one on `src/backend`, one on
`src/frontend` — since the file trees don't overlap. Both were told the
exact shared contract in advance (history as
`{role: "user"|"assistant", content: string}[]`) so they didn't need to run
sequentially. This worked, with one caveat below.

### A real bug this process caught (worth remembering)
The security-gate pass added a size cap to the backend's new
`CopilotRequest.history` (`max_length=20`, to stop unbounded history from
becoming a cost/DoS vector against the Groq key) — a fix made *after* the
frontend agent had already finished and had no way to know about it. Result:
`CopilotPanel.tsx` kept sending its full, ever-growing history, and any chat
session's 11th exchange got a real `422` that the UI misreported as "backend
unreachable." **Caught by post-task-review**, not by either implementation
agent's own testing, because neither side had a test at the actual HTTP
route/schema layer — both existing test suites (backend unit tests, frontend
build) passed the whole time despite the bug being real and reproducible.
Fixed by capping `toHistory()` client-side to the last 10 turns, and closed
the test gap with `tests/test_copilot_route.py` (4 new tests hitting the
real route via `TestClient`, not just `copilot_service.ask()` directly).
**Lesson**: when two agents build opposite sides of one contract in
parallel, and a *third*, later change (like a security fix) touches that
same contract, explicitly re-check both sides against each other before
calling it done — don't assume "both test suites are green" means the
contract between them still holds.

### Verification performed
- Backend: 23/23 pytest passing (19 original + 4 new route-level history
  tests), `pip-audit` clean, manual curl against `/health` showed
  `last_updated` advancing and an asset's risk score drifting after 15s
  with zero restart.
- Frontend: `npm run build` clean (tsc + vite, zero type errors), `npm run
  lint` clean (one pre-existing, intentional, non-blocking warning), dev
  server smoke-tested (every changed route/module returned 200).
- Security: independent security-auditor agent pass on the new LLM/tool-
  calling attack surface — tool whitelist is hardcoded/closed (no dynamic
  dispatch the LLM could exploit), round-cap on the tool-calling loop
  genuinely enforced (`MAX_TOOL_ROUNDS=3`), API key verified never logged or
  returned, no XSS vector in the new answer-formatting component, CORS
  unchanged. Two low-severity warnings found and fixed (history/content size
  caps; broadened tool-argument exception handling).

## 2026-09-15 follow-up: live public-URL deployment setup

Task record: [2026-09-15-live-deploy-setup.md](../tasks/2026-09-15-live-deploy-setup.md).
User wanted a real public URL (submission's `known_limitations` previously
said "no live deployment") without disturbing local dev.

### What changed
- **Render (backend) + Vercel (frontend)** chosen — the standard free-tier
  pairing, inferred directly from the user's own instruction to add a
  self-ping so the backend doesn't sleep (that workaround is specifically
  a Render free-plan issue; Railway/Fly.io don't need it the same way).
- **`app/services/keepalive.py`** — new background asyncio task (same shape
  as `live_simulator.run_forever()`), pings its own `/health` every 5 min.
  Reads `RENDER_EXTERNAL_URL` (Render sets this automatically — zero config
  on deploy) or an explicit `SELF_PING_URL` override. **True no-op locally**:
  if neither is set, it returns immediately — verified both by a live run
  (clean startup, no ping activity) and unit tests
  (`tests/test_keepalive.py`).
- **`main.py` CORS** — `FRONTEND_ORIGIN` is now comma-separated-aware so the
  deployed Vercel origin can be added alongside the local dev origin instead
  of replacing it.
- **`render.yaml`** (repo root, Blueprint) — backend as a free web service;
  build command installs deps + regenerates the synthetic data (data dir is
  gitignored, so this has to happen at build time on Render's ephemeral
  disk — safe because generation is deterministic, seed 42).
  `GROQ_API_KEY` is `sync: false` so it's never committed, set only in the
  Render dashboard.
- **`src/frontend/vercel.json`** — pins Vite build/output settings for the
  monorepo (Vercel project's Root Directory still needs to be set to
  `src/frontend` by hand in the dashboard — that field isn't controllable
  from this file).
- **`docs/setup-guide.md`** — new "Deploy live" section appended; every
  existing local-dev section left untouched.

### What could NOT be automated (needs the user's own accounts)
Connecting the GitHub repo to Render and to Vercel and clicking deploy —
both require the user's own OAuth-linked dashboard session, which this
agent has no access to. Everything up to that point (code, config, docs) is
done; the account-linking + deploy click + final CORS URL round-trip is a
manual step-by-step in `docs/setup-guide.md`.

### A wrinkle worth remembering
Several edits to `main.py` and both `.env.example` files silently reverted
to their pre-edit content between tool calls, more than once, with no error
reported by the edit itself — root cause not confirmed, but the repo lives
under `OneDrive\Desktop\...`, so OneDrive re-syncing a stale cloud copy (or
an editor tab holding a stale buffer and autosaving over the change) is the
leading suspect. **Lesson**: after any edit to a file in this repo, re-read
or grep it back before relying on the change — don't trust a successful
Edit/Write result alone as proof the content is actually on disk.

### Verification performed
- Backend: fresh server start on a clean port, `/health` and `/assets` both
  responded correctly; `keepalive.run_forever()` confirmed to return
  immediately with no env vars set; full suite 26/26 pytest passing (23
  pre-existing + 3 new keepalive tests).
- Config: `render.yaml` parsed as valid YAML, `vercel.json` parsed as valid
  JSON.
- Security gate (FEATURE, 7-point): PASSED — no new inputs/endpoints/deps,
  no secrets committed, ping URL never attacker-controlled. One pre-existing,
  unrelated warning noted (no npm install cooldown configured).
