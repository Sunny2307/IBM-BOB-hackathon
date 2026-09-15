# Grid Failure Advisor — Frontend

React + Vite + TypeScript + Tailwind CSS v4 + Recharts + React Router. A dark,
high-density "grid operations console" UI for utility predictive maintenance.

## Run it

```bash
cd src/frontend
npm install
cp .env.example .env   # optional — defaults to http://localhost:8000
npm run dev
```

Opens on `http://localhost:5173`. Works standalone (no backend required) —
every page falls back to local mock data if the API is unreachable, with a
visible "DEMO DATA" banner so it's never mistaken for live data.

Once the FastAPI backend is running on the URL in `.env` (`VITE_API_BASE_URL`),
the app automatically uses live data instead.

## Build

```bash
npm run build      # type-checks (tsc -b) then builds to dist/
npm run preview    # preview the production build locally
```

## Structure

```
src/
  api/          client.ts (typed fetch wrapper), types.ts (API contract), mockData.ts (demo fallback)
  components/   Layout, RiskBadge, CopilotPanel, SensorChart, StatusStates, ErrorBoundary
  hooks/        useAsyncData (loading/error/fallback handling for all pages)
  lib/          sensorTrend.ts (degrading/stable trend detection for charts)
  pages/        Dashboard, AssetDetail, MaintenancePlan
```

## Routes

- `/` — Dashboard: sortable/filterable asset table
- `/assets/:id` — Asset detail: risk breakdown, sensor trend charts, weather context
- `/maintenance-plan` — Region-grouped recommended actions
- Copilot chat panel is docked on every page (right-edge tab, top-right).

## API contract notes

`src/api/types.ts` matches the live FastAPI backend exactly (reconciled
against `app/models/schemas.py` after both sides were built) — verified by
running both together end-to-end with Playwright: all pages loaded real data
with zero console errors and no "DEMO DATA" fallback triggered. See
`../../docs/architecture.md` for the full contract.
