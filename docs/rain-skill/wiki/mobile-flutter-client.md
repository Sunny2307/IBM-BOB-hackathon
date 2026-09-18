# Mobile client (Flutter) — `src/mobile`

Added 2026-09-18. A third client alongside `src/backend` (FastAPI) and
`src/frontend` (React). It is **frontend only** — it calls the existing backend
over the existing endpoints, and no backend file was touched to make it work.

## What it is

`grid_advisor_mobile`, a Flutter 3.47 / Dart 3.13 app for Android and iOS that
mirrors the web app screen-for-screen: Dashboard, Asset Detail, Maintenance
Plan, and the Volt copilot.

## Endpoints consumed

The same five the web app uses — `GET /assets`, `GET /assets/{id}`,
`GET /assets/{id}/risk-breakdown`, `GET /maintenance-plan`,
`POST /copilot/ask`. The Dart models in `lib/api/types.dart` are a field-for-field
port of `frontend/src/api/types.ts`, which in turn mirrors
`backend/app/models/schemas.py`. **If the backend contract changes, all three
must change together.**

## Configuration

One setting, supplied at build time — the mobile equivalent of the web's
`VITE_API_BASE_URL`:

```
flutter run --dart-define=API_BASE_URL=https://your-api-host
```

Unset, it defaults to `http://10.0.2.2:8000` on Android (the emulator's alias
for the host machine) and `http://localhost:8000` elsewhere. There is no `.env`
file in the mobile app.

## Decisions

- **`flutter_map` + OSM tiles**, not `google_maps_flutter` — no API key to
  manage, and the same tile source the web's react-leaflet map uses.
- **`fl_chart`**, not syncfusion — free, and matches the Recharts area-chart look.
- **`go_router`**, not Navigator 1.0 — keeps the web's URL route shapes (`/`,
  `/assets/:id`, `/maintenance-plan`), so deep links behave the same on both.
- **`google_fonts`**, not bundled IBM Plex binaries — keeps font files out of
  the repo; falls back to system fonts if the device is offline.
- **Cleartext HTTP is allowlisted per-host, not globally.** Only `10.0.2.2`,
  `localhost` and `127.0.0.1` may use plain HTTP (Android
  `network_security_config.xml`, iOS `NSAllowsLocalNetworking`). Everything else
  must be HTTPS, so a deployed backend stays protected. A blanket
  `usesCleartextTraffic="true"` was deliberately avoided.

## Deliberate departures from the web UI

Two, both because the web form does not work at phone width:

1. **The 7-column asset table became a list of rows.** Every column is still
   shown, stacked rather than side by side.
2. **The Leaflet marker popup became a bottom sheet**, and the right-hand
   copilot drawer became a full-height modal sheet with an "Ask Volt" FAB.

One behavioural difference worth knowing: the web map refits its viewport to
the asset bounds every time the asset list changes; the mobile map fits once on
load, so a 30s poll does not yank the user's pan/zoom out from under them.

## State and offline behaviour

`lib/state/async_data.dart` is the port of the web's `useAsyncData` hook: 30s
polling, background refresh without flashing a skeleton, and fallback to the
same local demo data with the same unmissable "SHOWING CACHED DEMO DATA"
banner. `lib/state/copilot_controller.dart` is a session-scoped singleton —
the web mounts `CopilotPanel` once inside `Layout` so its history survives
navigation; the mobile sheet is rebuilt on each open, so the history lives in
the controller instead.

## Verification

`flutter analyze` clean, `flutter test` 10/10 passing (contract parsing,
fallback behaviour, widget rendering), `flutter build apk --debug` succeeds.
The app has not yet been run against a live backend on this machine — the
backend's Python dependencies are not installed here — so the contract was
verified by reading `schemas.py`, the routers, `risk_engine.compute_risk_breakdown`,
and the generated `assets.json` / `weather_forecast.json` field names directly.

See [`src/mobile/README.md`](../../../src/mobile/README.md) for the full
file-by-file map from web to mobile.
