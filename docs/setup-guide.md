# Setup Guide

Follow these steps exactly — they are the same commands used to build and
verify this submission (backend REST API, MCP server, and frontend were all
run and screenshotted end-to-end with these exact commands before
submission).

## Prerequisites

| Tool | Version used | Check |
|---|---|---|
| Python | 3.11+ | `python --version` |
| Node.js | 18+ (built/tested on Node 22) | `node --version` |
| npm | comes with Node | `npm --version` |

No accounts, API keys, or cloud services are required to run this project.
The Grid Copilot works fully offline with no LLM API key.

## 1. Clone and enter the repo

```bash
git clone https://github.com/<your-org>/bob-ai-hackathon-<your-team-name>.git
cd bob-ai-hackathon-<your-team-name>
```

## 2. Backend — install, generate data, run

```bash
cd src/backend
python -m venv .venv

# Windows:
.venv\Scripts\activate
# macOS / Linux:
source .venv/bin/activate

pip install -r requirements.txt

# Generate synthetic data (deterministic — safe to re-run any time)
python scripts/generate_synthetic_data.py

# Optional: copy env template (no real secrets required to run)
cp .env.example .env

# Start the API
uvicorn app.main:app --reload --port 8000
```

Verify it's working:

```bash
curl http://localhost:8000/health
# {"status":"ok"}

curl http://localhost:8000/assets
# a JSON array of 50 scored grid assets
```

Interactive API docs (all endpoints, try-it-out): http://localhost:8000/docs

### Environment variables (`src/backend/.env.example`)

| Variable | Required? | Purpose |
|---|---|---|
| `LLM_API_KEY` | No | Not used by the MVP — the Grid Copilot is fully deterministic and needs no LLM key |
| `LLM_PROVIDER` | No | Reserved for a future optional LLM phrasing layer; unused |
| `FRONTEND_ORIGIN` | No (defaults to `http://localhost:5173`) | Allowed CORS origin for the frontend dev server |

## 3. Frontend — install and run (separate terminal)

```bash
cd src/frontend
npm install
cp .env.example .env      # sets VITE_API_BASE_URL=http://localhost:8000
npm run dev
```

Open **http://localhost:5173** — the dashboard should load 50 real assets
ranked by risk score. If it instead shows an amber "DEMO DATA" banner, the
backend isn't reachable — see troubleshooting below.

### Environment variables (`src/frontend/.env.example`)

| Variable | Required? | Purpose |
|---|---|---|
| `VITE_API_BASE_URL` | No (defaults to `http://localhost:8000`) | Base URL the frontend calls for the backend API |

## 4. MCP server — the IBM Bob integration (optional, separate terminal)

```bash
cd src/backend
.venv\Scripts\activate      # or: source .venv/bin/activate
python -m app.mcp.server
```

This starts an MCP server over stdio. Connect it to IBM Bob or any MCP
client and call `get_at_risk_assets`, `get_asset_detail`,
`explain_asset_risk`, `get_maintenance_plan`, or `list_regions` — see
[`architecture.md`](architecture.md#verifying-the-bobmcp-integration) for the
exact verification command and what it proves.

## 5. How to verify everything is working

1. Backend health check returns `{"status":"ok"}` (step 2 above).
2. Frontend dashboard at http://localhost:5173 shows **50 assets**, no
   "DEMO DATA" banner, sortable by risk score.
3. Click any **Critical**-tier asset — its detail page should show 4 sensor
   charts and a non-empty "Why This Score" panel.
4. Open the Grid Copilot panel (top-right tab) and ask: *"which assets are
   highest risk?"* — the answer should name real asset IDs/names with scores
   matching the dashboard.
5. (Optional) Run the MCP verification command in step 4 above and confirm
   the returned numbers match the dashboard for the same region.
6. (Optional) From `src/backend`, run `pytest` — 5 tests confirm the core
   claims (compounding sensor+weather risk on the top asset, weather-timed
   maintenance dates, MCP/dashboard data consistency) are actually true of
   the code, not just asserted in the docs.

## Troubleshooting

| Symptom | Fix |
|---|---|
| `ModuleNotFoundError` on `import mcp` or `fastapi` | You're not inside the activated `.venv` — re-run the `activate` command for your OS, then `pip install -r requirements.txt` again |
| `pip install` reports a pydantic/mcp version conflict | Make sure you're using the committed `requirements.txt` as-is (pydantic is pinned to `2.10.6` specifically because `mcp==1.2.0` requires `pydantic>=2.10.1`) |
| Backend starts but `/assets` returns a 500 / `MissingDataError` | You skipped `python scripts/generate_synthetic_data.py` — run it from `src/backend/` before starting uvicorn |
| Frontend shows an amber "DEMO DATA" banner | The backend isn't running, isn't on port 8000, or CORS is blocking it — confirm `curl http://localhost:8000/health` works, and that `src/frontend/.env` matches |
| `npm run dev` fails to start | Confirm Node 18+ (`node --version`); delete `node_modules` and re-run `npm install` |
| Port 8000 or 5173 already in use | Another process is bound to the port — stop it, or run uvicorn with `--port 8001` and update `VITE_API_BASE_URL` in `src/frontend/.env` to match |
