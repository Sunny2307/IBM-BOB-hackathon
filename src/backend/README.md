# Backend — Grid Failure Advisor API

FastAPI service: risk engine, maintenance planner, REST API, and the MCP
server that exposes the same logic to IBM Bob / any MCP client.

```
app/
  main.py                 FastAPI app, CORS, router registration, /health
  routers/                assets.py, maintenance.py, copilot.py — thin HTTP layer
  services/
    data_loader.py        loads generated JSON/CSV into memory at startup
    risk_engine.py         explainable composite risk scoring
    maintenance_planner.py ranking, regional clustering, weather-timed recommendations
    grid_tools.py           the 4(+1) tools shared by /copilot/ask AND the MCP server
    copilot_service.py      deterministic keyword-intent router over grid_tools
  mcp/
    server.py              MCP server — `python -m app.mcp.server`
  models/
    schemas.py              Pydantic request/response models (the API contract)
  data/generated/           synthetic assets/sensors/weather/incidents (generated, not hand-written)
scripts/
  generate_synthetic_data.py   regenerate all data under app/data/generated/ (deterministic, seeded)
tests/
  test_risk_engine.py           proves the specific claims in the docs are actually true of the code
```

## Run

```bash
python -m venv .venv
.venv/Scripts/activate        # Windows; source .venv/bin/activate on macOS/Linux
pip install -r requirements.txt
python scripts/generate_synthetic_data.py    # only needed once, or to regenerate
uvicorn app.main:app --reload --port 8000
```

Docs: http://localhost:8000/docs (FastAPI auto-generated OpenAPI UI — judges can
poke at every endpoint directly here).

## Tests

```bash
pytest
```

5 tests that verify the specific claims made in the docs are actually true of
the running code — not just asserted: the top-ranked asset always has both a
degrading sensor trend and a forecast storm in its region, risk tiers
actually discriminate on sensor anomaly, maintenance dates land before
forecast storms, and `grid_tools` (shared by the MCP server and the in-app
Copilot) returns the exact same top asset as the dashboard. Data is
auto-generated on first run if missing, so this works on a fresh clone with
no setup beyond `pip install -r requirements.txt`.

## MCP server (Bob / IBM Bob integration)

```bash
python -m app.mcp.server
```

Runs standalone over stdio. Any MCP client (or Bob) can connect and call
`get_at_risk_assets`, `get_asset_detail`, `explain_asset_risk`,
`get_maintenance_plan`, `list_regions` — these call the exact same
`app/services/grid_tools.py` functions used by `/copilot/ask`, so the numbers
returned match the running web app exactly. See
[`../../docs/architecture.md`](../../docs/architecture.md) for the full
verification walkthrough.
