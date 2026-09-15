# Source Code — Grid Failure Advisor

```
src/
  backend/        FastAPI service (risk engine, maintenance planner, MCP server)
  frontend/       React (Vite + TS) dashboard, asset detail, maintenance plan, Grid Copilot
```

See [`docs/setup-guide.md`](../docs/setup-guide.md) for exact install/run steps for both.

- `backend/README.md` — backend layout and how to regenerate synthetic data
- `frontend/README.md` — frontend layout and API contract notes
- `backend/.env.example`, `frontend/.env.example` — every environment variable used, with dummy/default values. No `.env` file is committed anywhere in this repo.
