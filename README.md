# ⚡ Grid Failure Advisor

> Predicts outage-prone grid assets weeks in advance by fusing sensor telemetry, weather forecasts, and historical incidents into one explainable, prioritized maintenance plan.

---

## 👥 Team

| Field | Value |
|---|---|
| **Team Name** | Grid Failure Advisors |
| **Track** | AI |
| **Team Lead** | Malay Sheta — malay.sheta@devxlabs.ai |
| **Members** | Malay Sheta |

---

## 🎯 Problem Statement

Utilities still run calendar-based maintenance on transformers and
substations even though sensors already show failure signatures — rising
partial discharge, falling oil quality — weeks before failure, and weather
forecasts that compound that risk are never combined with the sensor data in
time to act. A single major asset failure causes blackouts costing
**$1M+/hour** and can strand tens of thousands of customers, including
hospitals and water treatment plants.

---

## 💡 Solution

Grid Failure Advisor fuses asset sensor data, 7-day weather forecasts, and
historical incident records into one **explainable** composite risk score
per asset, ranks assets by how much damage their failure would actually
cause, and generates a maintenance plan that pulls action dates forward
ahead of an incoming storm. A **Grid Copilot**, backed by an MCP server IBM
Bob can call directly, answers plain-English questions grounded in the same
real data.

---

## ✨ Key Features

- **Explainable risk scoring** — every point of every asset's 0-100 score traces to a named factor (per-sensor anomaly, weather risk, historical incident rate) with a plain-language explanation, shown in a "Why This Score" panel
- **Sensor anomaly detection** across temperature, vibration, partial discharge, and oil quality, measured against each asset's own 15-day baseline
- **Weather-timed maintenance & crew pre-positioning plan** — recommended dates are pulled forward to land before a forecast storm in the asset's region
- **Grid Copilot with a real MCP server** — the same tool functions (`get_at_risk_assets`, `explain_asset_risk`, `get_maintenance_plan`, …) are callable independently by IBM Bob or any MCP client, and by the in-app chat — one implementation, not a demo stub
- **Zero-dependency-on-a-live-LLM-key demo** — the copilot's deterministic intent router means the live demo never breaks on Wi-Fi or a missing API key

---

## 🛠️ Tech Stack

| Category | Technologies |
|---|---|
| **Languages** | Python, TypeScript |
| **Frameworks** | FastAPI, React, Vite, Tailwind CSS |
| **IBM Technologies** | IBM Bob, Model Context Protocol (MCP) |
| **Databases** | None — in-memory, generated JSON/CSV (zero infra by design) |
| **Other** | Uvicorn, Pydantic, Recharts, Playwright (used to verify the UI end-to-end) |

---

## 📁 Repository Structure

```
├── src/
│   ├── backend/          # FastAPI service: risk engine, maintenance planner, MCP server
│   └── frontend/         # React (Vite + TS) dashboard, asset detail, maintenance plan, Grid Copilot
├── docs/                 # Written documentation
│   ├── problem-statement.md
│   ├── solution-overview.md
│   ├── architecture.md
│   └── setup-guide.md
├── demo/                 # Demo artifacts
│   ├── screenshots/      # App screenshots
│   └── demo-video-link.txt  # Link to demo video
├── presentation/         # Slide deck
└── submission.yaml       # Structured submission metadata
```

---

## ⚡ How to Run

> Full details, environment variables, and troubleshooting: [`docs/setup-guide.md`](docs/setup-guide.md)

```bash
# 1. Clone the repo
git clone https://github.com/<your-org>/bob-ai-hackathon-grid-failure-advisors.git
cd bob-ai-hackathon-grid-failure-advisors

# 2. Backend
cd src/backend
python -m venv .venv && .venv\Scripts\activate   # or: source .venv/bin/activate
pip install -r requirements.txt
python scripts/generate_synthetic_data.py
uvicorn app.main:app --reload --port 8000

# 3. Frontend (separate terminal)
cd src/frontend
npm install
cp .env.example .env
npm run dev

# 4. Optional — the IBM Bob / MCP integration (separate terminal)
cd src/backend
.venv\Scripts\activate                            # or: source .venv/bin/activate
python -m app.mcp.server
```

Open **http://localhost:5173** for the app. Interactive API docs at
**http://localhost:8000/docs**.

---

## 🖥️ Demo

| Artifact | Link |
|---|---|
| 📹 Demo Video | [See demo/demo-video-link.txt](demo/demo-video-link.txt) |
| 🌐 Live Demo | [See demo/live-demo-url.txt](demo/live-demo-url.txt) |
| 🖼️ Screenshots | [See demo/screenshots/](demo/screenshots/) |
| 📊 Presentation | [See presentation/slides.pdf](presentation/) |

---

## ⚠️ Known Limitations

- All data is synthetic (deterministic, seeded generator) — no real utility dataset was available in the build window
- Risk scoring is intentionally rule-based/statistical, not a trained ML model — a deliberate explainability and time-budget decision, documented in `docs/solution-overview.md`, and designed to be upgradeable once real failure labels exist
- No map visualization, authentication, or persistent database in this MVP
- Not deployed — runs locally via `docs/setup-guide.md` (see `demo/live-demo-url.txt`)
- The Grid Copilot uses a deterministic keyword/intent router rather than a full LLM, by design, so the demo has zero dependency on a live API key

---

## 🏅 What We're Most Proud Of

The risk engine is genuinely explainable, not just "AI-powered" in name: the
"Why This Score" panel shows every contributing factor with its exact point
value, and the synthetic data generator deliberately guarantees the
top-ranked asset has both a real degrading sensor trend *and* an upcoming
storm in its region — the problem statement's core story is verifiably true
in the running app on every run, not just asserted in a slide. Just as
important: the MCP server and the in-app Grid Copilot share one
implementation (`app/services/grid_tools.py`), so a judge can independently
call `get_at_risk_assets` over MCP and get back the exact numbers the
dashboard shows — proof the IBM Bob integration is load-bearing.

---
