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

## Android build requirements (added 2026-09-18)

`flutter_local_notifications` 19.5.0 fails the build at
`:app:checkDebugAarMetadata` unless **core library desugaring** is enabled.
Both halves are required in `android/app/build.gradle.kts`:

```kotlin
compileOptions {
    isCoreLibraryDesugaringEnabled = true
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
```

The `2.1.4` version is not arbitrary — it is what the plugin itself declares
in its own `android/build.gradle`. An older desugar library still fails the
AAR metadata check. If the notification plugin is ever upgraded, re-check that
file rather than assuming the version still matches.

Notification permissions are already wired: `POST_NOTIFICATIONS` and
`RECEIVE_BOOT_COMPLETED` in the manifest, plus a runtime
`requestNotificationsPermission()` call in `lib/services/notifications.dart`
(required from Android 13 on; the test device runs Android 16).

## Sign-in failures: two distinct causes (2026-09-18)

Sign-in failed on the handset with "Could not reach API". There were **two**
independent causes; fixing only one leaves it broken.

**1. The connection pool had no health check (the real one).**
`app/db.py` built its `ConnectionPool` without `check=`, which defaults to
`None`. Neon closes idle connections when it scales to zero, so pooled sockets
go dead; the pool then hands out or waits on corpses and every operator route
fails with `PoolTimeout: couldn't get a connection after 10.00 sec` until the
process is restarted. Observed directly: `pg_stat_activity` showed only 2 of
901 connections in use while the server insisted the database was unavailable.
Fixed with `check=ConnectionPool.check_connection` plus `max_idle=120`, so a
dead connection is validated and replaced instead of being served.

**2. The dev tunnel drops requests, and POSTs were single-shot.**
Measured from the handset: 3 of 6 `POST /auth/login` calls hung forever (never
errored), while every response that did arrive came back in about a second.
`ApiClient` retried GETs three times but POSTs exactly once, so the dashboard
survived and sign-in did not. Retry is now decided **per call**, not per verb —
`retryable:` at each call site. Login, alert-ack and assignment-delete retry;
the copilot POST and the create-user/create-assignment mutations do not,
because a retry there costs an extra LLM call or 409s after already succeeding.

Neither cause is visible from the error message alone, which is why the fix
started with `adb shell curl` against the tunnel from the device rather than
with code changes.

## Alert flapping and the grace period (2026-09-18)

`live_simulator` re-scores every asset every 13s, so an asset sitting near the
High boundary (50) crosses back and forth and the monitor raised then resolved
an alert almost every tick — AST-020 had four raise/resolve cycles in the
table. It also meant a hand-raised alert vanished ~60s after an admin sent it,
before the recipient's phone had polled.

`alert_monitor.RESOLVE_GRACE_SECONDS` (600) now blocks auto-resolve inside the
first ten minutes. When the grace window blocks a resolve, `asset_tier_state`
is deliberately left untouched so the next tick re-evaluates the same
transition rather than recording the drop and never resolving at all.

## Sending an alert to a named person

`POST /admin/alerts/send` (admin only) raises a **real** alert — same table,
same headline wording, same one-open-alert-per-asset rule as the automatic
monitor. There is no separate "test notification" path on purpose: a test that
bypasses the real pipeline proves nothing about the real pipeline.

Reachable two ways in the app: the **Send** tab in the admin nav, and a
**Trigger an alert** strip at the top of the Alerts inbox (admins only).

The recipient must have an assignment — alerts are scoped by region, so a user
with none sees nothing whatever you send. `GET /admin/users/{id}/assignable-assets`
backs the picker so an admin cannot send into the void, and an unassigned user
gets a message naming the fix rather than a silent no-op.

Note that scoping is by region, not by person: anyone else covering that region
sees the same alert. That is intended — the whole crew responsible for an area
should know.

## Why "Send alert" fired nothing on the handset (2026-09-18)

The web button reported success and the phone stayed silent. Two correct
behaviours combined into a bug:

- `raise_alert_for_user` is idempotent per asset — a partial unique index
  allows one live alert per asset, so re-sending **re-opens the existing row**
  and returns the id it already had (#105, in the reported case).
- `AlertPoller` de-duplicated on `alert.id` alone, so that row looked like an
  alert the phone had already notified about, and `fresh` came back empty.

Idempotency is right for the automatic monitor and wrong for an explicit
manual send. Fixed on both sides:

- The re-open branch now also sets `raised_at = now()`, making a re-raise a
  genuinely new event rather than a silent no-op.
- The poller's dedup key is now `(id, raisedAt, tier)` rather than `id`.
  Including `tier` means a High→Critical escalation also notifies even though
  the row keeps its id; excluding `status` means acknowledging never
  re-notifies.

Pinned by three tests in `test/operator_test.dart`: re-sending the same alert
notifies again (but only once per re-raise), an escalation notifies, and an
acknowledgement does not.

**Still outstanding:** the poller only runs while the app is alive or
backgrounded. Nothing arrives after a force-kill — that needs FCM or a
`workmanager` background task, neither of which is built yet.

