# Solution Overview

## What We Built

**Grid Failure Advisor** is a predictive-maintenance dashboard for utility
grid assets. It ingests sensor telemetry, weather forecasts, and historical
incident records for a fleet of transformers and substations; computes an
**explainable** risk score for each one; ranks them by how much damage their
failure would actually cause (not just how likely they are to fail); and
turns that ranking into a concrete, weather-timed maintenance and
crew-pre-positioning plan. A **Grid Copilot** lets anyone — an operator, a
judge, or IBM Bob itself — ask questions in plain English and get answers
grounded in the same live data, not a canned response.

## How It Works

1. **Data fusion.** Each asset's last 30 days of sensor readings (temperature,
   vibration, partial discharge, oil quality), its region's 7-day weather
   forecast, and the fleet's historical incident record are loaded into one
   in-memory view at startup.
2. **Explainable scoring, not a black box.** For each asset, the risk engine
   computes: a per-sensor anomaly score (how far the last 3 days deviate from
   that asset's own 15-day baseline, direction-aware — rising partial
   discharge is bad, falling oil quality is bad), a weather-risk term (full
   weight if a storm is forecast for that asset's region in the next 7 days),
   and a historical-incident-rate term (based on incident frequency for
   similar-age, similar-type assets). These are **added**, not blended into
   an opaque single number — every point is traceable to a named factor.
3. **Prioritization, not just scoring.** A high risk score on a
   low-consequence asset matters less than a moderate risk score on a
   transformer feeding a hospital. The maintenance planner multiplies
   `risk_score × grid_impact_severity` (the latter derived from customers
   served, critical-load flags, and N-1 redundancy) to rank what actually
   deserves crew time first.
4. **Weather-timed action, not just a ranked list.** For each recommended
   action, the planner checks whether a storm is forecast for that asset's
   region and, if so, pulls the recommended-by date forward to land *before*
   the storm — this is the concrete mechanism behind "combine sensor data and
   weather forecasts in time to act."
5. **A copilot grounded in the same data.** The Grid Copilot answers
   questions by routing them (via keyword/intent matching, not a hallucinating
   LLM) to the exact same functions used everywhere else in the app —
   `get_at_risk_assets`, `explain_asset_risk`, `get_maintenance_plan` — and
   these are also exposed as an **MCP server** that IBM Bob or any MCP client
   can call directly and independently of the web app.

## What Makes It Different From a Naive Alternative

A naive version of this idea is "put sensor readings on a dashboard with
threshold alarms." That doesn't answer *why* an asset is risky, doesn't
account for *who* it would hurt if it failed, doesn't combine weather with
sensor data, and gives an operator a wall of numbers instead of a plan.
Grid Failure Advisor's differentiation is specifically in the three joins a
naive dashboard skips: **sensor data joined with weather timing**, **risk
score joined with grid-impact consequence** (not risk in isolation), and
**a chat interface joined to real backend tool calls** rather than a
separately-implemented, disconnected "AI demo" bolted on afterward.

## Key Design Decisions

| Decision | Rationale |
|---|---|
| Rule-based/statistical risk scoring instead of a trained ML model | Defensible under judge Q&A in one sentence, needs no training-data legitimacy argument, and every number is traceable to a named factor — explicitly designed to be upgraded to a trained model once real historical failure labels exist (the service-layer interface would not need to change) |
| Deterministic keyword-intent router for the Grid Copilot, no required LLM key | The live demo must never fail because of a missing API key or no internet access; correctness comes from real tool calls against real data, not from an LLM's judgment |
| MCP server and `/copilot/ask` share one implementation (`grid_tools.py`) | This is what makes "IBM Bob integration" a real, judge-verifiable claim instead of a README mention — there is exactly one definition of "what counts as at-risk" |
| Synthetic but internally-consistent data, generated deterministically | No real utility dataset was available in the time available; the generator deliberately guarantees the top-ranked asset has both a genuine degrading sensor trend *and* an upcoming storm in its region, so the core narrative is verifiably true in the running app on every run, not just claimed in a slide |
| In-memory JSON/CSV instead of a database | Zero infrastructure to fail during a live demo; fully reproducible from a single committed, re-runnable generator script |

## What the User Experience Looks Like

An operator opens the dashboard and sees every monitored asset ranked by risk
score, with a color-coded tier (Critical/High/Medium/Low), filterable by
region and tier. Clicking an asset shows four sensor trend charts (with
degrading trends visually flagged in red), the region's weather forecast
(with the storm day highlighted), and — most importantly — a plain-language
"Why This Score" panel listing every contributing factor and its point
value. A separate Maintenance Plan view groups the highest-priority actions
by region, each with a specific recommended action and a "by \<date\>"
deadline tied to incoming weather. Throughout, a docked Grid Copilot panel
lets the operator ask a question in plain English and see, transparently,
which backend tools were called to produce the answer.
