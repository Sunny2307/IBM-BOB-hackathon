@Timeout(Duration(minutes: 4))
library;

// Opt-in integration check against a REAL running backend. Skipped by default
// so the normal `flutter test` run stays offline and deterministic.
//
//   flutter test test/live_backend_test.dart --dart-define=LIVE=true
//   flutter test test/live_backend_test.dart --dart-define=LIVE=true \
//       --dart-define=API_BASE_URL=http://localhost:8000
//
// This is what proves the Dart models still match the FastAPI contract. Run it
// after any backend schema change.

import 'package:flutter_test/flutter_test.dart';
import 'package:grid_advisor_mobile/api/client.dart';
import 'package:grid_advisor_mobile/api/types.dart';

const bool _live = bool.fromEnvironment('LIVE');

void main() {
  // Generous: the dev tunnel can stall for ~60s on the first hit to a route
  // before answering in well under a second thereafter.
  final client = ApiClient(timeout: const Duration(seconds: 45));

  group(
    'live backend',
    () {
      test('GET /assets parses into Asset models', () async {
        final assets = await client.getAssets();

        expect(assets, isNotEmpty);
        final first = assets.first;
        expect(first.assetId, startsWith('AST-'));
        expect(first.name, isNotEmpty);
        expect(first.type, anyOf('transformer', 'substation'));
        expect(first.riskScore, inInclusiveRange(0, 100));
        expect(first.region, isNotEmpty);
        // A tier that failed to parse silently becomes `low`; make sure the
        // real payload produces a spread of tiers, not all-low.
        expect(assets.map((a) => a.riskTier).toSet().length, greaterThan(1));
      });

      test('GET /assets/{id} and /risk-breakdown parse', () async {
        final assets = await client.getAssets();
        final id = assets.first.assetId;

        final asset = await client.getAsset(id);
        expect(asset.assetId, id);

        final breakdown = await client.getRiskBreakdown(id);
        expect(breakdown.assetId, id);
        expect(breakdown.components, isNotEmpty);
        expect(breakdown.components.first.factor, isNotEmpty);
        expect(breakdown.sensorSeries.temperature, isNotEmpty);
        expect(breakdown.sensorSeries.oilQuality, isNotEmpty);
        expect(breakdown.sensorSeries.temperature.first.date, isNotEmpty);
        expect(breakdown.weatherContext.region, isNotEmpty);
        expect(breakdown.weatherContext.forecast, isNotEmpty);
      });

      test('GET /maintenance-plan parses', () async {
        final plan = await client.getMaintenancePlan();

        expect(plan.generatedAt, isNotEmpty);
        expect(plan.regions, isNotEmpty);
        final region = plan.regions.first;
        expect(region.region, isNotEmpty);
        expect(region.weatherSummary, isNotEmpty);
        expect(region.items, isNotEmpty);
        expect(region.items.first.recommendedAction, isNotEmpty);
        expect(region.items.first.recommendedByDate, isNotEmpty);
      });

      test('POST /copilot/ask parses, including tool calls', () async {
        final response = await client.askCopilot(
          'Which assets are highest risk?',
          history: const [
            CopilotHistoryTurn(role: 'user', content: 'hello'),
            CopilotHistoryTurn(role: 'assistant', content: 'hi'),
          ],
        );

        expect(response.answer, isNotEmpty);
        for (final call in response.toolCalls) {
          expect(call.tool, isNotEmpty);
        }
      });
    },
    skip: _live ? false : 'pass --dart-define=LIVE=true to run against a backend',
  );

  group(
    'live backend — operator layer',
    () {
      // Matches scripts/seed_operators.py. Run that against the same backend
      // first, or these will fail on the login step with a 401.
      const fieldEmail = 'ravi@grid.demo';
      const fieldPassword = 'FieldDemo2026';

      test('login returns a usable session', () async {
        final session = await client.login(fieldEmail, fieldPassword);

        expect(session.accessToken, isNotEmpty);
        expect(session.role, UserRole.field);
        expect(session.companyName, isNotEmpty);
        expect(session.userId, greaterThan(0));
      });

      test('a wrong password is refused', () async {
        await expectLater(
          client.login(fieldEmail, 'definitely-not-the-password'),
          throwsA(isA<ApiError>()),
        );
      });

      test('GET /alerts/mine parses into Alert models and is scoped', () async {
        final session = await client.login(fieldEmail, fieldPassword);
        client.authToken = session.accessToken;

        final inbox = await client.getMyAlerts(status: 'active');
        expect(inbox.scope, isNotEmpty);

        for (final alert in inbox.alerts) {
          expect(alert.assetId, startsWith('AST-'));
          expect(alert.headline, isNotEmpty);
          // The monitor only ever raises these two tiers.
          expect(alert.tier, anyOf(RiskTier.critical, RiskTier.high));
          expect(alert.riskScore, inInclusiveRange(0, 100));
        }
      });

      test('GET /assignments/mine returns this operator\'s own assets', () async {
        final session = await client.login(fieldEmail, fieldPassword);
        client.authToken = session.accessToken;

        final mine = await client.getMyAssignments();
        expect(mine.count, mine.assets.length);
        for (final asset in mine.assets) {
          expect(mine.regions, contains(asset.region));
        }
      });

      test('acknowledging an alert sticks', () async {
        final session = await client.login(fieldEmail, fieldPassword);
        client.authToken = session.accessToken;

        final inbox = await client.getMyAlerts(status: 'open');
        if (inbox.alerts.isEmpty) {
          markTestSkipped('no open alerts on the server right now');
          return;
        }

        final target = inbox.alerts.first;
        await client.acknowledgeAlert(target.id);

        final after = await client.getMyAlerts(status: 'acknowledged');
        expect(after.alerts.map((a) => a.id), contains(target.id));
      });

      test('a field user is refused the admin routes', () async {
        final session = await client.login(fieldEmail, fieldPassword);
        client.authToken = session.accessToken;

        // Role is enforced server-side, not by hiding the tab.
        await expectLater(client.getUsers(), throwsA(isA<ApiError>()));
      });
    },
    skip: _live ? false : 'pass --dart-define=LIVE=true to run against a backend',
  );
}
