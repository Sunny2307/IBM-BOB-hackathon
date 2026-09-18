# Flutter mobile app (src/mobile)

**Date:** 2026-09-18
**Flow:** FEATURE
**Status:** done

## Goal
A Flutter mobile frontend at `src/mobile/` that mirrors the existing React
website (`src/frontend`) screen-for-screen and talks to the **existing**
FastAPI backend unchanged. No edits to `src/backend` or `src/frontend`.

## Done =
`flutter analyze` clean and `flutter build apk --debug` succeeds for an app
with Dashboard / Asset Detail / Maintenance Plan screens + the Volt copilot,
hitting `/assets`, `/assets/{id}`, `/assets/{id}/risk-breakdown`,
`/maintenance-plan`, `/copilot/ask`, with mock-data fallback when the API is
unreachable.

## API contract (unchanged, read from backend/app)
- `GET  /assets`                        -> Asset[]
- `GET  /assets/{id}`                   -> Asset
- `GET  /assets/{id}/risk-breakdown`    -> RiskBreakdown
- `GET  /maintenance-plan`              -> MaintenancePlan
- `POST /copilot/ask` {question, history[]} -> {answer, tool_calls, data}
- `GET  /health`

## Screen parity map
| Web | Mobile |
|---|---|
| `Layout` masthead + nav | `AppShell` AppBar + bottom nav |
| `Dashboard` stat tiles / map / filters / table / pagination | `DashboardPage` stat grid / map / filter sheet / asset cards / pagination |
| `AssetDetail` header / why-this-score / 4 sensor charts / weather | `AssetDetailPage`, same sections stacked |
| `MaintenancePlan` region cards | `MaintenancePlanPage`, same |
| `CopilotPanel` right drawer | `CopilotSheet` full-height modal sheet |
| `useAsyncData` (poll + mock fallback) | `AsyncData<T>` controller, same semantics |
| `index.css` editorial tokens | `AppTheme` with identical hex values |

## Package choices (rejected alternatives)
- `flutter_map` + OSM tiles over google_maps_flutter — no API key, same tile
  source as react-leaflet on web.
- `fl_chart` over syncfusion — free, matches the recharts area-chart look.
- `go_router` over Navigator 1.0 — keeps the web's URL route shapes.
- `google_fonts` over bundling IBM Plex — avoids committing font binaries;
  falls back to system fonts if the device is offline.
- Config via `--dart-define=API_BASE_URL` over a .env package — no extra dep,
  and mirrors the web's `VITE_API_BASE_URL`.

## Steps
1. `flutter create` the project at `src/mobile`.
2. Models + client + mock data (ports of `api/types.ts`, `client.ts`, `mockData.ts`).
3. Theme (port of `index.css` tokens).
4. `AsyncData` controller (port of `useAsyncData`).
5. Shared widgets: RiskBadge, GridMap, SensorChart, LastUpdated, Skeleton,
   StatusStates, FormattedAnswer, CopilotSheet.
6. Three pages + AppShell + router.
7. `flutter analyze`, `flutter build apk --debug`, README.

## Outcome (2026-09-18)

Delivered at `src/mobile/` (`grid_advisor_mobile`). Backend and web frontend
verified untouched via `git status -- src/backend src/frontend` (empty).
Only other change outside `src/mobile/`: one index entry added to `src/README.md`.

Evidence:
- `flutter analyze` → **No issues found!**
- `flutter test` → **+10: All tests passed!**
- `flutter build apk --debug` -> **Built build/app/outputs/flutter-apk/app-debug.apk**

Security gate (FEATURE, frontend-only client):
- No secrets in the app; the one setting (`API_BASE_URL`) is a build-time
  `--dart-define`, not a credential.
- Cleartext HTTP allowlisted per-host (`10.0.2.2`, `localhost`, `127.0.0.1`)
  rather than a blanket `usesCleartextTraffic`; everything else must be HTTPS.
- Asset ids are `Uri.encodeComponent`-escaped before path interpolation
  (found and fixed during the gate); the backend additionally validates them
  against `^AST-\d+$`.
- Copilot history capped at 10 turns = 20 messages, matching the backend's
  `max_length=20` on `CopilotRequest.history`.
- LLM answers render as Flutter `Text` widgets — no HTML/JS execution surface.

Not done / known limits:
- Never exercised against a running backend on this machine (backend Python
  deps are not installed here). Contract verified by reading `schemas.py`,
  the routers, `risk_engine.compute_risk_breakdown` and the generated data files.
- No screenshots or on-device run — no emulator/device was available.
- The map fits its viewport once on load rather than refitting on every poll
  (deliberate; see the wiki page).
