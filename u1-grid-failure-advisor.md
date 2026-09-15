# U1 — Grid Failure Advisor: Hackathon Execution Plan

> IBM BoB AI Innovation Hackathon 2026, First Round. Deadline **2026-09-15, 11:45 PM**.
> Mode: same-day sprint, checkpoint-based (not clock-anchored — use whatever hours you actually have left).

---

## 🔴 IMMEDIATE ACTION ITEMS (do these before anything else, ~5 min)

1. **Decide the team name right now.** Every reference below uses the placeholder
   `[TEAM_NAME — fill in before submitting]`. Once decided, replace it in `submission.yaml`,
   `README.md`, and (if you rename the GitHub repo) the repo name
   (`bob-ai-hackathon-[your-team-name]`). This is the single most common "we forgot" item.
2. **Confirm team roster + emails** for `submission.yaml` (`team.lead`, `team.members`).
   Session context suggests the lead may be `malay.sheta@devxlabs.ai` — confirm this is
   correct with the actual person before it goes in the submission; do not assume.
3. **Check the clock now.** Deadline is 11:45 PM. Count remaining hours and pick a tier from
   the [Time Budget & Compression Guide](#time-budget--compression-guide) below — do this as
   a team, out loud, so everyone commits to the same scope.
4. **Time-box a 15-minute check** (technical lead) on how IBM Bob actually registers/calls
   external tools (hackathon portal/docs, if available). This plan defaults to a standard
   **MCP server** as the integration mechanism — that is the correct, defensible choice if
   nothing more specific is found in 15 minutes. Do not let this research task expand past
   15 minutes; proceed with the plan below regardless.

---

## Overview

**Problem (why it matters, not just what the spec says):** Utilities still run
calendar-based maintenance — replace transformer parts every N years regardless of actual
condition. This wastes money on healthy assets and misses failing ones between cycles.
Meanwhile, condition-monitoring sensors (temperature, vibration, partial discharge, oil
quality) already show degradation signatures **weeks before failure**, and weather forecasts
already show which regions face compounding stress (heat waves overload transformers, storms
snap lines near already-weak equipment). The gap isn't sensing — it's that sensor data,
weather forecasts, and historical incident records live in separate systems and are never
fused into a single ranked, actionable plan before the outage happens. A single major
transformer/substation failure costs $1M+/hour and can affect hundreds of thousands of
customers; a crew pre-positioned one day ahead is proactive, the same crew dispatched after
a call from an angry city council member is not.

**Solution:** Grid Failure Advisor ingests synthetic (but internally consistent) asset
sensor telemetry, weather forecasts, and historical incident records; computes an
**explainable** composite risk score per asset (not a black box); ranks assets by grid
impact severity; and outputs a prioritized maintenance + crew pre-positioning plan. A
**Grid Copilot** lets an operator — or a judge, or IBM Bob itself via MCP — ask natural
language questions that are answered from the same underlying risk data via callable tools,
not from a hallucinated LLM guess.

## Project Type

**WEB** (data-intensive full-stack app) — Python FastAPI backend + React frontend, per
locked decisions. **Track:** `AI` (submission.yaml `team.track`).

## Success Criteria (measurable — this is "done")

- [ ] A judge clones the repo, follows `docs/setup-guide.md` only, and has the app running
      locally in **under 10 minutes**.
- [ ] Dashboard shows 40+ synthetic assets, sorted/filterable by risk score and tier
      (Critical/High/Medium/Low).
- [ ] Clicking an asset shows its 4 sensor trend charts, relevant weather forecast, and a
      plain-language breakdown of **why** it scored the way it did.
- [ ] A "Maintenance & Crew Pre-Positioning Plan" view shows a ranked, region-grouped
      7-day action list tied to weather timing (e.g., "pre-position crew in Region X by
      Thursday, storm arrives Friday").
- [ ] Grid Copilot answers a natural-language question (e.g., "which assets are highest
      risk this week near Houston?") in under 5 seconds, grounded in real data returned
      from MCP tool calls — not a canned string.
- [ ] The MCP server can be started independently and an external MCP client (or Bob) can
      call at least 2 tools and get real data back — documented, reproducible steps in
      `docs/architecture.md`. This is the concrete proof Bob integration is load-bearing.
- [ ] Zero placeholder text anywhere in `README.md`, `submission.yaml`, `docs/*.md`,
      `demo/*`. GitHub Action "Validate Submission" is green. Repo is public.

## Tech Stack (with rationale)

| Layer | Choice | Why (given today's constraints) |
|---|---|---|
| Backend | Python 3.11 + FastAPI + Uvicorn | Locked decision; fast to scaffold, async, auto OpenAPI docs judges can poke at directly |
| Data storage | JSON/CSV files under `src/backend/app/data/generated/`, loaded into memory at startup | Zero infra setup, zero moving parts to break during demo, fully reproducible from a committed generator script — a real DB (Postgres) buys nothing today and adds failure risk |
| Risk scoring | Rule-based / statistical (z-score & trend-slope anomaly detection over each asset's own baseline), explicitly **not** a trained ML model | Explainable to judges in one sentence, no training-data legitimacy questions, fast to build and to defend under Q&A — framed honestly as "upgradeable to ML with real historical labels" |
| Bob integration | MCP server (Python `mcp` SDK) wrapping the same service functions used by the REST API | Standard, judge-verifiable protocol; genuinely load-bearing because the copilot endpoint calls the *same* functions, not a duplicate demo stub |
| Frontend | React 18 + Vite + TypeScript, Tailwind CSS, Recharts for charts | Fast scaffold (`npm create vite@latest`), good visual polish fast, no backend coupling issues |
| Map/geo | Skipped for MVP — table/list grouped by region. If time remains: `react-simple-maps` (pure SVG, **no API key**, no network dependency) | Leaflet/Mapbox tile servers + API keys are a classic live-demo failure point; not worth the risk today |
| Deployment | Local only for MVP (`demo/live-demo-url.txt` = "NOT DEPLOYED — run locally using docs/setup-guide.md") | Deploying under time pressure is a common way to lose the "working demo" score; only attempt in the stretch phase if genuinely ahead |

---

## Scope: MVP IN vs CUT (be decisive)

### IN — must work end-to-end, no exceptions
1. Synthetic data generator: assets (lat/lon, type, grid impact severity), sensor readings
   (temperature, vibration, partial discharge, oil quality) with injected degrading trends,
   7-day weather forecast with 1-2 severe events, historical incident records.
2. Risk engine: explainable composite score = sensor anomaly + weather multiplier +
   historical base rate, scaled by grid impact severity.
3. FastAPI REST API: `/assets`, `/assets/{id}`, `/assets/{id}/risk-breakdown`,
   `/maintenance-plan`, `/copilot/ask`.
4. React dashboard: risk-ranked, sortable/filterable asset list with tier badges.
5. Asset detail view: 4 sensor trend charts + weather context + "why this score" breakdown.
6. Maintenance & crew pre-positioning plan view: ranked, region-grouped, weather-timed.
7. Grid Copilot: NL question box → backend → MCP tool calls → grounded answer (deterministic
   keyword-routing baseline; optional LLM phrasing layered on top only if time and a key
   are available).
8. MCP server exposing the same functions as independently callable tools.
9. All 8 repo template files filled with real, specific content — zero brackets.
10. Demo video, 3+ screenshots, slide deck.

### CUT — explicitly out of scope (state honestly in `known_limitations`)
- Interactive tiled map (Leaflet/Mapbox) — API-key/network risk not worth it today.
- Trained ML/time-series forecasting model — rule-based scoring is faster, safer, and
  more defensible under judge questioning.
- Auth/user accounts, multi-tenant anything.
- Real database (Postgres/Redis) — in-memory/JSON is sufficient and more reliable.
- WebSockets/real-time streaming — static load or simple polling is enough for a demo.
- Public cloud deployment — only attempt in the stretch phase (Phase 5) if ahead of
  schedule; default to "NOT DEPLOYED."
- Notifications/Slack integration, mobile responsiveness beyond "doesn't look broken."

---

## Architecture

```
                     ┌────────────────────────┐
                     │  React Frontend (Vite)  │
                     │  Dashboard / AssetDetail│
                     │  MaintenancePlan / Chat │
                     └───────────┬─────────────┘
                                 │ REST (fetch)
                     ┌───────────▼─────────────┐
                     │   FastAPI Backend        │
                     │   routers: assets,        │
                     │   maintenance, copilot    │
                     └───────────┬─────────────┘
                                 │ calls
                     ┌───────────▼─────────────┐
                     │   Service Layer (pure)   │
                     │  risk_engine.py           │
                     │  maintenance_planner.py   │
                     │  copilot_service.py       │
                     └───────┬───────────┬───────┘
                             │           │
              ┌──────────────▼──┐   ┌────▼─────────────────────┐
              │ data_loader.py   │   │  MCP Server (mcp/server.py)│
              │ reads generated  │   │  tools: get_at_risk_assets,│
              │ JSON/CSV at      │   │  get_asset_detail,         │
              │ startup          │   │  explain_asset_risk,       │
              └────────┬─────────┘   │  get_maintenance_plan      │
                       │             │  ← callable by Bob or any  │
       ┌───────────────▼─────────┐  │    MCP client, independently│
       │ scripts/generate_       │  └────────────────────────────┘
       │ synthetic_data.py       │
       │ → data/generated/*.json │
       └──────────────────────────┘
```

**Key architectural decision — MCP tools are shared code, not a demo stub.** The
`/copilot/ask` endpoint and the standalone MCP server both import the exact same functions
from `risk_engine.py` / `maintenance_planner.py`. This is what makes the Bob integration
"load-bearing": a judge can independently start the MCP server, connect any MCP client (or
Bob), call `get_at_risk_assets`, and get the same real numbers the UI shows — it is not a
separate mocked path.

**Resilience decision — the Copilot never depends on a live LLM key at demo time.**
`copilot_service.py` uses a deterministic keyword/intent router (regex/keyword matching →
tool call → templated natural-language response). If a watsonx.ai or other LLM API key is
available and there is spare time, it can be layered on top purely to improve phrasing —
never as the only path to a correct answer. This directly protects the "Working Demo &
Functionality" score against Wi-Fi/API-key failures on demo day.

### Components

| Component | Technology | Responsibility |
|---|---|---|
| Frontend | React 18 + Vite + TS + Tailwind + Recharts | Dashboard, asset detail, maintenance plan, copilot chat UI |
| Backend API | FastAPI | REST endpoints, request validation, orchestration |
| Risk Engine | Python (pandas/numpy, no ML training) | Composite explainable risk scoring |
| Maintenance Planner | Python | Ranking, regional clustering, weather-timed recommendations |
| MCP Server | Python `mcp` SDK | Exposes risk/maintenance functions as Bob-callable tools |
| Synthetic Data Generator | Python script | Produces internally consistent assets/sensors/weather/incidents |
| Data Store | JSON/CSV files, in-memory at runtime | Zero-infra, fully reproducible |

### Data Flow

1. `scripts/generate_synthetic_data.py` runs once (and is committed + re-runnable) to
   produce `assets.json`, `sensor_readings.json`, `weather_forecast.json`,
   `historical_incidents.csv` under `src/backend/app/data/generated/`.
2. On FastAPI startup, `data_loader.py` reads all four files into memory.
3. `risk_engine.py` computes, per asset: a sensor anomaly score (baseline z-score/trend
   slope across temperature, vibration, partial discharge, oil quality), a weather risk
   multiplier (from the asset's region forecast), and a historical incident base rate
   (by asset type/age) — combined into one explainable composite score, scaled by the
   asset's grid impact severity.
4. `maintenance_planner.py` ranks assets by `risk_score × grid_impact_severity`, groups
   the top N by region, and attaches a recommended action + timing tied to the weather
   forecast for that region.
5. The React frontend calls `/assets`, `/assets/{id}/risk-breakdown`, and
   `/maintenance-plan` to render the dashboard, detail view, and plan view.
6. The Grid Copilot sends a question to `/copilot/ask`; `copilot_service.py` routes it to
   one or more of the same MCP tool functions and returns a grounded, templated answer.
7. Independently, `python -m app.mcp.server` starts the MCP server so any MCP client
   (or Bob) can call the same tools directly — this is the judge-verifiable integration
   point.

### Security Considerations
- All data is synthetic — no real customer/PII/utility data anywhere.
- `.env` is git-ignored; only `.env.example` (no real values) is committed.
- No secrets are required for the MVP to run (no live LLM key needed — see resilience
  decision above). If an optional key is used, it is read from environment variables only.

### Scalability Notes
- The FastAPI backend is stateless per request; horizontally scalable behind a load
  balancer. Swap the in-memory JSON store for a real time-series DB (e.g., TimescaleDB)
  and the composite risk formula for a trained model once real historical failure labels
  exist — the service-layer function signatures would not need to change.

---

## File Structure (target, under `src/` — top-level repo structure is unchanged)

```
src/
  backend/
    app/
      main.py                     # FastAPI app, CORS, router registration
      routers/
        assets.py                 # /assets, /assets/{id}, /assets/{id}/risk-breakdown
        maintenance.py            # /maintenance-plan
        copilot.py                # /copilot/ask
      services/
        data_loader.py            # loads generated JSON/CSV into memory
        risk_engine.py            # composite explainable risk scoring
        maintenance_planner.py    # ranking, regional clustering, timing
        copilot_service.py        # keyword-intent router + (optional) LLM polish
      mcp/
        server.py                 # MCP server: exposes the 4 tools
      models/
        schemas.py                # Pydantic request/response models
      data/
        generated/
          assets.json
          sensor_readings.json
          weather_forecast.json
          historical_incidents.csv
    scripts/
      generate_synthetic_data.py
    requirements.txt               # fastapi, uvicorn[standard], pydantic, mcp, pandas, numpy, python-dotenv
    .env.example
  frontend/
    src/
      pages/  (Dashboard.tsx, AssetDetail.tsx, MaintenancePlan.tsx)
      components/ (RiskBadge, SensorChart, CopilotPanel, AssetTable, RegionGroup)
      api/ (client.ts — fetch wrapper)
      App.tsx, main.tsx
    package.json
    vite.config.ts
  README.md                        # already exists — keep, points into backend/frontend
  .env.example                     # already exists at src/ root
```

---

## Team Roles & Parallelization (works for 3-5 members)

| Role | Owns | If team = 3, merge with |
|---|---|---|
| **Backend/Data Lead** | Synthetic data generator, risk engine, maintenance planner, FastAPI routers | — |
| **Frontend Lead** | React scaffold, Dashboard, AssetDetail, MaintenancePlan, CopilotPanel UI | — |
| **Integration/MCP** | MCP server, `/copilot/ask`, wiring the two together | Merge into Backend/Data Lead |
| **Docs & QA (non-technical)** | `submission.yaml`, `docs/*.md`, testing/fresh-clone verification, screenshots | Merge into whichever human is free first |
| **Presentation & Demo (non-technical)** | `presentation/` slides, video script/storyboard, recording, README polish | Merge into Docs & QA if team = 3 |

**Parallelization principle:** two tracks run simultaneously from minute one —

- **Technical Track:** data generation → backend → frontend → MCP/copilot (sequential
  dependencies within the track, but starts immediately).
- **Narrative Track (non-technical members, no idle time):** research utility maintenance
  economics for `docs/problem-statement.md`, draft `submission.yaml` skeleton, storyboard
  the demo video, build the slide deck skeleton, and later take screenshots and run the
  fresh-clone verification test. This track needs no code to start — it starts at
  Checkpoint 0 and runs continuously.

---

## Time Budget & Compression Guide

Don't anchor to a specific start time — use **checkpoints**. Check the clock now, note hours
remaining until 11:45 PM, and pick a tier:

| Tier | Hours remaining | Guidance |
|---|---|---|
| **Full** | 8h+ | Run all phases 0-7 including Phase 5 stretch items if you finish early |
| **Standard** | 5-7h | Run phases 0-4 and 6-7 fully; skip Phase 5 entirely |
| **Crunch** | 3-4h | Cut further: smaller synthetic dataset (20-25 assets), skip charts (plain numbers table instead of Recharts), MCP server ships with just 2 tools instead of 4, copilot answers 3 hardcoded-but-real question patterns instead of a general router, no deploy attempt, screenshots doubled as demo-video B-roll to save time |
| **<3h** | Emergency | Backend + one working endpoint + dashboard list view + MCP server with 1 tool + fill every doc file honestly (including `known_limitations` describing what's missing) — a smaller thing that runs beats a bigger thing that's broken. Do not skip Phase 7 (verification) under any tier — an unsubmittable repo scores zero regardless of code quality. |

**Non-negotiable regardless of tier:** Phase 0 (5 min), Phase 7 (verification, 20-30 min),
and having *something* real behind the Bob/MCP integration (even 1 tool that returns real
data beats zero).

---

## Phase-by-Phase Task Breakdown

### Checkpoint 0 — Kickoff & Setup (~15-20 min, everyone)

| Task | Owner | Input → Output | Verify |
|---|---|---|---|
| Decide team name, confirm roster/emails | Docs & QA lead | Team discussion → filled-in team info | Everyone agrees; written down for `submission.yaml` |
| 15-min Bob/MCP mechanism check | Backend/Integration | Hackathon portal/docs → confirmed approach or "proceed with plan default" | Decision logged, timer respected |
| Confirm repo hygiene | Docs & QA | `git status` → confirm no `.env` tracked, repo is Public | `git ls-files \| grep .env` shows only `.env.example` |
| Assign roles per table above | Everyone | — | Each person names their track |

### Checkpoint 1 — Foundations (parallel)

**Track A — Backend/Data Lead:**
- Scaffold `src/backend` (FastAPI skeleton, `requirements.txt`, `uvicorn app.main:app --reload` runs and returns 200 on a health route).
- Write `scripts/generate_synthetic_data.py` producing:
  - `assets.json`: 40-60 assets (transformers + substations), fields: `asset_id`, `name`, `type`, `lat`, `lon`, `region`, `install_year`, `capacity_mva`, `customers_served`, `grid_impact_severity` (1-10, weighted by customers served + downstream criticality e.g. hospital/water-treatment flags + redundancy/N-1 status), `base_failure_rate`.
  - `sensor_readings.json`: 30-day daily series per asset for temperature, vibration, partial discharge, oil quality. Inject a degrading trend (rising partial discharge, falling oil quality) into ~15-20% of assets over the last 10-14 days — this is the "failure signature weeks in advance" story.
  - `weather_forecast.json`: 7-day forecast per region (5-8 regions): temp high, wind speed, precipitation probability, storm warning flag. Inject 1-2 severe weather events hitting a region that also contains some of the degrading assets — this is the "compounding risk" story judges will probe.
  - `historical_incidents.csv`: 30-50 past incidents (asset_id, date, cause, duration_hours, customers_affected, estimated_cost_usd) over ~3 years, statistically consistent with asset type/age.
- INPUT → OUTPUT: none → 4 generated files under `src/backend/app/data/generated/`, generator re-runnable.
- VERIFY: `python scripts/generate_synthetic_data.py` runs clean; spot-check that assets with injected degrading sensors correlate with a plausible historical incident type for their asset type.

**Track B — Frontend Lead:**
- `npm create vite@latest frontend -- --template react-ts`, add Tailwind, add Recharts, add React Router.
- Build the shell: 3 tabs/routes (Dashboard, Asset Detail, Maintenance Plan) plus a persistent Copilot panel, wired to mock JSON for now.
- INPUT → OUTPUT: none → navigable shell at `localhost:5173`.
- VERIFY: `npm run dev`, all tabs render without console errors.

**Track C — Docs & QA (non-technical):**
- Fill `submission.yaml` skeleton: `team.name`, `team.track: "AI"`, `team.lead`, `team.members`, draft `submission.title`, `problem_statement`, `solution_summary`.
- Start `docs/problem-statement.md` with real research: calendar-based vs. condition-based maintenance economics, the $1M+/hour blackout cost framing, why weeks-of-lead-time matters financially.
- INPUT → OUTPUT: template files → real drafts, zero brackets in the sections touched.
- VERIFY: submission.yaml parses (`yq '.' submission.yaml` if available, or any online YAML validator); no `[` placeholder brackets left in the sections written so far.

**Track D — Presentation & Demo (non-technical):**
- Build `presentation/` slide skeleton in the required order: Problem → Solution →
  Demo/Architecture → IBM tech integration → Impact.
- Draft a 3-5 minute video storyboard: hook → problem → live dashboard walkthrough →
  copilot query → architecture/MCP callout → impact statement.
- VERIFY: 5 sections present, in that exact order.

### Checkpoint 2 — Core Backend Logic

**Backend/Integration:**
- `risk_engine.py`: sensor anomaly score (z-score/trend-slope vs each asset's own 15-day
  baseline across the 4 metrics), weather risk multiplier (from the asset's region
  forecast), historical incident base rate (by asset type/age) → documented composite
  formula in code comments, scaled by `grid_impact_severity`.
- `maintenance_planner.py`: rank by `risk_score × grid_impact_severity`, group top N by
  region, attach recommended action + timing tied to the region's weather event dates.
- Wire FastAPI routers: `/assets`, `/assets/{id}`, `/assets/{id}/risk-breakdown`,
  `/maintenance-plan`.
- INPUT → OUTPUT: generated data files → live JSON from all 4 endpoints.
- VERIFY: `curl localhost:8000/assets` etc. return real computed data; the top-ranked
  asset visibly has both a bad sensor trend AND an upcoming severe weather event in its
  region (confirms the compounding-risk story is actually true in the data, not just
  claimed).

**Docs & QA (parallel):** write real `docs/solution-overview.md` (plain-language
explanation of the risk formula, no code); start `docs/architecture.md` Components/Data
Flow sections (can adapt directly from this plan's Architecture section above).

### Checkpoint 3 — Frontend Wiring

**Frontend Lead:**
- Connect Dashboard to `/assets`: sortable table, risk tier color badges
  (Critical/High/Medium/Low).
- Connect Asset Detail to `/assets/{id}` + `/risk-breakdown`: Recharts trend lines for
  the 4 sensors, plus a plain-language "why this score" bullet list.
- Connect Maintenance Plan to `/maintenance-plan`: ranked cards grouped by region with
  recommended crew timing.
- VERIFY: click through all 3 tabs in the browser, no console errors, numbers match a
  manual `curl` check against the same endpoint.

**Docs & QA (parallel):** capture early rough screenshots as the UI comes online (redo
later if needed); start drafting `docs/setup-guide.md` prerequisites/install sections as
the real commands solidify.

### Checkpoint 4 — MCP Server & Grid Copilot (the Bob load-bearing feature — protect this time)

**Backend/Integration:**
- Build `app/mcp/server.py` using the `mcp` Python SDK, wrapping the risk/maintenance
  service functions as 4 tools: `get_at_risk_assets`, `get_asset_detail`,
  `explain_asset_risk`, `get_maintenance_plan`.
- Build `/copilot/ask`: deterministic keyword-intent router calling the **same** service
  functions (not a duplicate implementation) + templated response formatting; layer an
  optional LLM call on top only for phrasing, only if a key and time are available.
- INPUT → OUTPUT: service layer functions → (a) MCP server runnable standalone, (b)
  `/copilot/ask` returns grounded answers.
- VERIFY:
  (a) Run `python -m app.mcp.server`, connect any MCP client (or Bob, if accessible) and
  call `get_at_risk_assets` — confirm real data comes back.
  (b) `POST /copilot/ask {"question": "which assets are highest risk this week"}` returns
  an answer naming actual top-ranked asset IDs that match the `/maintenance-plan` output.

**Frontend Lead:** build `CopilotPanel` chat UI → posts to `/copilot/ask`, renders the
answer (optionally shows which tool(s) were called, for transparency). VERIFY: ask 3
sample questions in the UI, get sensible grounded answers.

**Docs & QA (parallel):** write the "How the Bob/MCP integration works, and how to verify
it yourself" subsection for `docs/architecture.md` — this is the single highest-value
paragraph in the whole submission for the 10-point IBM Bob Integration score; it must give
a judge exact, copy-pasteable commands. Prepare 3 sample copilot questions for the demo
video script.

### Checkpoint 5 — Polish & Stretch (ONLY if genuinely ahead of schedule — Full tier only)

Priority order if extra time exists: (1) lightweight SVG asset map via
`react-simple-maps` (no API key), (2) LLM-polished copilot phrasing on top of the
deterministic router, (3) deploy backend + frontend to free hosts and fill in a real
`demo/live-demo-url.txt`, (4) a few `pytest` smoke tests on `risk_engine.py`, (5)
empty-state/error handling polish. **Cut immediately and without exception if behind
schedule** — this phase exists to be skipped.

### Checkpoint 6 — Docs, Demo Assembly, Presentation

Everyone converges here once the app is functionally stable.

- Finalize `docs/architecture.md`: real Mermaid diagram matching the actual system (not
  the template's watsonx/Postgres/Slack example), Components table, Data Flow, Security
  Considerations (synthetic data only, `.env` git-ignored, no real secrets), Scalability
  Notes, and the Bob/MCP verification subsection.
- Finalize `docs/setup-guide.md`: exact, tested commands. Have someone who did **not**
  write the code run it fresh from these instructions alone.
- Finalize `README.md`: replace every bracketed placeholder, real repository structure,
  how-to-run copied verbatim from `setup-guide.md`, honest `known_limitations`, and
  "what we're most proud of."
- Finalize `submission.yaml`: every `# REQUIRED` field filled, `key_features` with 3-5
  real bullets, `tech_stack.languages/frameworks/ibm_technologies/other` filled
  accurately (e.g., `ibm_technologies: ["IBM Bob", "MCP"]` or whatever is actually true).
- Take final screenshots (dashboard, asset detail with chart, maintenance plan, copilot
  chat — pick the best 3-4) into `demo/screenshots/` named `01-dashboard.png`,
  `02-asset-detail.png`, `03-maintenance-plan.png`, `04-copilot.png`.
- Record the demo video (3-5 min, screen + narration): dashboard → asset detail →
  maintenance plan → copilot query → (if possible) an MCP tool call from an external
  client → close on impact. Upload (YouTube unlisted or Loom), paste the **real** URL
  into `demo/demo-video-link.txt` (must not contain `your-demo-video-link-here`).
- Update `demo/live-demo-url.txt`: real URL if deployed, otherwise exactly
  `NOT DEPLOYED — run locally using docs/setup-guide.md`.
- Finalize `presentation/slides.pdf` (or `.pptx`): Problem → Solution →
  Demo/Architecture → IBM tech integration → Impact, in that order, using the real
  screenshots and architecture diagram.
- Tech track (spare capacity): code freeze, final commit, confirm no `.env` committed,
  no secrets in logs/console, `requirements.txt`/`package.json` installable from a clean
  clone.

### Checkpoint 7 (Phase X) — Final Verification & Submission Checklist (MANDATORY, ~20-30 min, never skip)

This mirrors the repo's own `CONTRIBUTING.md` checklist and exactly what
`.github/workflows/validate.yml` checks — go through it literally, in order:

- [ ] All 7 required files exist: `README.md`, `submission.yaml`,
      `docs/problem-statement.md`, `docs/solution-overview.md`, `docs/architecture.md`,
      `docs/setup-guide.md`, `demo/demo-video-link.txt`.
- [ ] `submission.yaml` is valid YAML (`yq '.' submission.yaml` if `yq` is installed, or
      paste into any YAML validator).
- [ ] Required fields non-empty: `team.name`, `team.track` (must be exactly `"AI"`),
      `team.lead.name`, `team.lead.email`, `submission.title`,
      `submission.problem_statement`, `submission.solution_summary`,
      `submission.key_features` (at least 1, aim for 3-5).
- [ ] `src/` contains real code files beyond `README.md`/`.env.example` — backend `.py`
      files and frontend `.tsx`/`.jsx` files are actually committed (not accidentally
      git-ignored).
- [ ] `demo/demo-video-link.txt` does **not** contain `your-demo-video-link-here` — real
      URL on the first line.
- [ ] `README.md` does **not** contain the literal strings `[Your Project Title Here]` or
      `[Your Team Name]` — search the whole file for any remaining `[` bracket
      placeholders (including `[TEAM_NAME — fill in before submitting]`).
- [ ] `.env` is **not** committed — only `.env.example` (`git ls-files | grep '\.env$'`
      returns nothing); no real API keys anywhere in a committed file.
- [ ] `demo/screenshots/` has 3+ real screenshots of the running app (not just the
      template's `README.md` stub).
- [ ] `presentation/slides.pdf` (or `.pptx`) present, 5 sections in the required order.
- [ ] GitHub repository visibility is **Public**.
- [ ] Push, open the Actions tab, confirm **✅ Validate Submission** is green. If red,
      fix and re-push — do not skip hooks or force-merge around it.
- [ ] Fresh-clone test: one team member (ideally not the code's author) clones the repo
      into a new folder and runs it using **only** `docs/setup-guide.md` — fix any gap
      found.
- [ ] Grep the whole repo for `TEAM_NAME` / `[Your Team Name]` to confirm the placeholder
      from the Immediate Action Items section was actually replaced everywhere.
- [ ] Video link opens without requiring special access (public or unlisted, no
      org-restricted Drive/Box links).
- [ ] Submit the repository URL via the official entry form **before 11:45 PM**.

---

## Rubric Guardrails (map plan elements → scoring, protect the highest-risk items)

| Rubric category | Pts | What in this plan earns it | Failure mode this plan guards against |
|---|---|---|---|
| Technical Implementation Quality | 25 | Real, working `risk_engine.py`, `maintenance_planner.py`, MCP server — not stubs | Empty/boilerplate `src/`; judges read actual code |
| Innovation & Differentiation | 25 | Explainable composite risk score + weather-compounding narrative visible in the data + Copilot genuinely grounded in tool calls | Vague "AI-powered" claims with no visible mechanism; generic CRUD dashboard |
| Problem Depth & Vision | 15 | Real utility maintenance-economics framing in `problem-statement.md`/`solution-overview.md` (calendar- vs condition-based maintenance cost tradeoff) | Just repeating the spec text back at judges |
| Working Demo & Functionality | 15 | Deterministic Copilot fallback (no live-LLM-key dependency), fresh-clone test in Checkpoint 7, Phase 5 stretch cut first under time pressure | Complete-but-broken demo; live API key failing during judging |
| IBM Bob Integration | 10 | MCP server independently startable and callable, documented verification steps, same code path as the app's own Copilot | Bob mentioned in README but never actually wired into the running app |
| Documentation & Reproducibility | 10 | `setup-guide.md` tested by a second person, zero placeholders anywhere | Boilerplate `[e.g., ...]` text left in docs; incomplete setup steps |

---

## Recap: Do These First

1. Replace `[TEAM_NAME — fill in before submitting]` with the real team name everywhere.
2. Confirm team roster + lead email for `submission.yaml`.
3. Check the clock, pick a time-budget tier.
4. Time-box the 15-minute Bob/MCP mechanism check, then commit to the MCP-server plan
   above regardless of what's found.
5. Split into the Technical Track and Narrative Track immediately — no one should be
   idle at Checkpoint 0.
