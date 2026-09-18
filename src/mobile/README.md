# Grid Failure Advisor — Mobile (Flutter)

The mobile client for the Grid Failure Advisor. It is a **frontend only**: it
talks to the same FastAPI backend in [`../backend`](../backend) that the web app
uses, over the same endpoints, with no backend changes of any kind.

Screen-for-screen it mirrors the React web app in [`../frontend`](../frontend) —
same data, same sections, same "Editorial Clean" look (paper/ink palette, IBM
Plex Serif headings, hairline rules, risk-tier color as the only accent).

## Run it

```bash
cd src/mobile
flutter pub get

# Android emulator — reaches the host's localhost:8000 as 10.0.2.2 automatically
flutter run

# iOS simulator / desktop — localhost:8000 works directly
flutter run

# Point at any other backend (deployed, LAN IP, etc.)
flutter run --dart-define=API_BASE_URL=https://grid-failure-advisor-api.onrender.com
```

`API_BASE_URL` is the mobile equivalent of the web app's `VITE_API_BASE_URL`.
With nothing supplied the app defaults to `http://10.0.2.2:8000` on Android
(the emulator's alias for your machine) and `http://localhost:8000` everywhere
else.

Build a release APK:

```bash
flutter build apk --release --dart-define=API_BASE_URL=https://your-api-host
```

## Backend endpoints used

Exactly the routes the web app calls — nothing new was added server-side:

| Method | Path | Used by |
|---|---|---|
| `GET`  | `/assets` | Dashboard |
| `GET`  | `/assets/{id}` | Asset detail |
| `GET`  | `/assets/{id}/risk-breakdown` | Asset detail |
| `GET`  | `/maintenance-plan` | Maintenance plan |
| `POST` | `/copilot/ask` | Volt copilot |

## Screens

| Web (`src/frontend`) | Mobile (this app) |
|---|---|
| `Layout` masthead + top nav | `AppShell` — app bar + bottom navigation |
| `Dashboard` | `DashboardPage` — stat tiles, map, filters, asset list, pagination |
| `AssetDetail` | `AssetDetailPage` — header, Why This Score, 4 sensor charts, 7-day weather |
| `MaintenancePlan` | `MaintenancePlanPage` — region cards with prioritized actions |
| `CopilotPanel` (right drawer) | `showCopilotSheet` — full-height modal sheet, "Ask Volt" FAB |

Two things are deliberately shaped for a phone rather than copied literally:

- **The asset table becomes a list of rows.** Every column the web table shows
  (name, type, region, tier, risk score, grid impact, customers) is still
  present — stacked instead of side by side, because a 7-column table is
  unreadable at 400px.
- **The map popup becomes a bottom sheet.** Tapping a marker opens an asset
  summary with a "View asset detail" action, which is the phone-native form of
  the web's Leaflet popup.

## How the code maps to the web app

| Web file | Mobile file |
|---|---|
| `src/api/types.ts` | `lib/api/types.dart` |
| `src/api/client.ts` | `lib/api/client.dart` |
| `src/api/mockData.ts` | `lib/api/mock_data.dart` |
| `src/hooks/useAsyncData.ts` | `lib/state/async_data.dart` |
| `src/lib/riskColors.ts` | `lib/util/risk_colors.dart` |
| `src/lib/sensorTrend.ts` | `lib/util/sensor_trend.dart` |
| `src/index.css` (`@theme` tokens) | `lib/theme/app_theme.dart` |
| `src/components/*` | `lib/widgets/*` |
| `src/pages/*` | `lib/pages/*` |

### Offline / demo behaviour

`AsyncData<T>` is the port of `useAsyncData`: it polls every 30s, refreshes in
the background without flashing a skeleton, and — if the backend is unreachable
— falls back to the same local demo data the web app uses, with the same
unmissable **"SHOWING CACHED DEMO DATA"** banner. The demo never silently
pretends mock data is live.

## Packages

| Package | Replaces (web) | Why |
|---|---|---|
| `flutter_map` + `latlong2` | `react-leaflet` | Same OpenStreetMap tiles, no API key |
| `fl_chart` | `recharts` | Area charts matching the web's sensor trends |
| `go_router` | `react-router-dom` | Keeps the web's URL route shapes |
| `google_fonts` | web font CSS | IBM Plex Sans/Serif/Mono; falls back to system fonts offline |
| `http` | `fetch` | REST calls |
| `intl` | `toLocaleString` | Number and date formatting |

## Checks

```bash
flutter analyze   # no issues
flutter test      # 10 tests: contract parsing, fallback behaviour, widgets
```

## Platform notes

Android 9+ and iOS block plain HTTP. Local development is allowlisted
explicitly — `10.0.2.2`, `localhost` and `127.0.0.1` in
`android/app/src/main/res/xml/network_security_config.xml`, and
`NSAllowsLocalNetworking` in `ios/Runner/Info.plist`. Every other host must be
HTTPS, so a deployed backend stays fully protected.
