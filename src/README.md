# Source Code — Grid Failure Advisor

```
src/
  backend/        FastAPI service (risk engine, maintenance planner, MCP server)
  frontend/       React (Vite + TS) dashboard, asset detail, maintenance plan, Grid Copilot
  mobile/         Flutter app — the same screens on Android/iOS, same backend
```

See [`docs/setup-guide.md`](../docs/setup-guide.md) for exact install/run steps for the backend and web frontend; `mobile/README.md` covers the Flutter app.

- `backend/README.md` — backend layout and how to regenerate synthetic data
- `frontend/README.md` — frontend layout and API contract notes
- `mobile/README.md` — Flutter app layout, how it maps to the web frontend, and how to point it at a backend
- `backend/.env.example`, `frontend/.env.example` — every environment variable used, with dummy/default values. No `.env` file is committed anywhere in this repo.
  The mobile app takes its one setting at build time instead: `--dart-define=API_BASE_URL=...`.
