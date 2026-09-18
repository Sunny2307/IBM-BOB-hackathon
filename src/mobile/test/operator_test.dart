// Offline tests for the operator layer: auth session handling, alert parsing,
// and the poller's dedup rule. No device, no server, no notifications.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:grid_advisor_mobile/api/client.dart';
import 'package:grid_advisor_mobile/api/types.dart';
import 'package:grid_advisor_mobile/state/alert_poller.dart';

Map<String, dynamic> _alertJson(
  int id, {
  String tier = 'Critical',
  String status = 'open',
  String raisedAt = '2026-09-18T10:00:00+00:00',
}) => {
      'id': id,
      'asset_id': 'AST-0$id',
      'asset_name': 'Test Substation $id',
      'region': 'North Valley',
      'tier': tier,
      'previous_tier': 'Medium',
      'risk_score': 91.4,
      'headline': 'Test Substation $id moved Medium to $tier.',
      'status': status,
      'raised_at': raisedAt,
      'acknowledged_by_name': null,
      'acknowledged_at': null,
    };

ApiClient _clientReturning(List<Map<String, dynamic>> Function() alerts) {
  return ApiClient(
    httpClient: MockClient((request) async {
      if (request.url.path == '/auth/login') {
        return http.Response(
          jsonEncode({
            'access_token': 'test-token',
            'token_type': 'bearer',
            'user_id': 5,
            'email': 'ravi@grid.demo',
            'full_name': 'Ravi Mehta',
            'role': 'field',
            'company_id': 1,
            'company_name': 'Gujarat Grid Operations',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (request.url.path == '/alerts/mine') {
        return http.Response(
          jsonEncode({'count': alerts().length, 'scope': 'assets assigned to you', 'alerts': alerts()}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response('{"detail":"not found"}', 404);
    }),
  );
}

void main() {
  group('auth session', () {
    test('login parses the identity the backend returns', () async {
      final client = _clientReturning(() => []);
      final session = await client.login('ravi@grid.demo', 'FieldDemo2026');

      expect(session.accessToken, 'test-token');
      expect(session.role, UserRole.field);
      expect(session.isAdmin, isFalse);
      expect(session.companyName, 'Gujarat Grid Operations');
    });

    test('an unknown role degrades to the LEAST privilege, never the most', () {
      // A backend that grows a new role must never accidentally grant admin.
      expect(UserRole.fromJson('superuser'), UserRole.field);
      expect(UserRole.fromJson(null), UserRole.field);
      expect(UserRole.fromJson('admin'), UserRole.admin);
    });

    test('a 401 clears the token and reports it, rather than retrying blindly', () async {
      var signedOut = false;
      final client = ApiClient(
        httpClient: MockClient((_) async => http.Response('{"detail":"Session expired"}', 401)),
      );
      client.authToken = 'stale-token';
      client.onUnauthorized = () => signedOut = true;

      expect(client.isAuthenticated, isTrue);
      await expectLater(client.getMyAlerts(), throwsA(isA<ApiError>()));
      expect(signedOut, isTrue, reason: 'the app must drop to the login screen');
      expect(client.isAuthenticated, isFalse, reason: 'a dead token must not be kept');
    });

    test('calling an operator endpoint with no session fails fast', () async {
      final client = _clientReturning(() => []);
      await expectLater(client.getMyAlerts(), throwsA(isA<ApiError>()));
    });

    test('server error text is surfaced, not just the status code', () async {
      final client = ApiClient(
        httpClient: MockClient(
          (_) async => http.Response('{"detail":"That email already has an account."}', 409,
              headers: {'content-type': 'application/json'}),
        ),
      );
      client.authToken = 't';
      try {
        await client.createUser(
            email: 'a@b.c', fullName: 'A', password: 'passwordpass', role: UserRole.field);
        fail('expected an ApiError');
      } on ApiError catch (err) {
        expect(err.message, contains('already has an account'));
      }
    });
  });

  group('alert parsing', () {
    test('maps the backend contract field for field', () {
      final alert = Alert.fromJson(_alertJson(7));

      expect(alert.id, 7);
      expect(alert.tier, RiskTier.critical);
      expect(alert.previousTier, 'Medium');
      expect(alert.status, AlertStatus.open);
      expect(alert.isAcknowledged, isFalse);
      expect(alert.raisedAt, isNotNull);
      expect(alert.acknowledgedAt, isNull, reason: 'a null timestamp must stay null');
    });

    test('acknowledged alerts carry who took them', () {
      final alert = Alert.fromJson({
        ..._alertJson(8, status: 'acknowledged'),
        'acknowledged_by_name': 'Ravi Mehta',
        'acknowledged_at': '2026-09-18T11:00:00+00:00',
      });

      expect(alert.isAcknowledged, isTrue);
      expect(alert.acknowledgedByName, 'Ravi Mehta');
      expect(alert.acknowledgedAt, isNotNull);
    });
  });

  group('AlertPoller dedup', () {
    test('the first poll is silent, so opening the app is not a barrage', () async {
      final notified = <int>[];
      final client = _clientReturning(() => [_alertJson(1), _alertJson(2)]);
      client.authToken = 'test-token';

      final poller = AlertPoller.forTest(
        client: client,
        onNotify: (alert) async => notified.add(alert.id),
      );

      await poller.poll();

      expect(poller.alerts, hasLength(2), reason: 'the backlog still shows in the list');
      expect(notified, isEmpty, reason: 'but it must not fire two notifications on launch');
    });

    test('only genuinely new alerts notify, however often we poll', () async {
      final notified = <int>[];
      var current = [_alertJson(1)];
      final client = _clientReturning(() => current);
      client.authToken = 'test-token';

      final poller = AlertPoller.forTest(
        client: client,
        onNotify: (alert) async => notified.add(alert.id),
      );

      await poller.poll(); // prime
      await poller.poll(); // same alert again
      await poller.poll(); // and again
      expect(notified, isEmpty, reason: 'a steady inbox must stay quiet');

      current = [_alertJson(1), _alertJson(2)];
      await poller.poll();
      expect(notified, [2], reason: 'only the new one');

      await poller.poll();
      expect(notified, [2], reason: 'and it must not re-fire on the next poll');
    });

    test('an admin re-sending the SAME alert notifies again', () async {
      // The server keeps one live alert row per asset and re-opens it instead
      // of stacking duplicates, so a re-sent alert comes back with the id the
      // phone already saw. Deduping on id alone swallowed it and the admin's
      // "Send alert" button did nothing on the handset.
      final notified = <int>[];
      var current = [_alertJson(105, tier: 'High')];
      final client = _clientReturning(() => current);
      client.authToken = 'test-token';

      final poller = AlertPoller.forTest(
        client: client,
        onNotify: (alert) async => notified.add(alert.id),
      );

      await poller.poll(); // prime on the existing backlog
      expect(notified, isEmpty);

      // Admin presses "Send alert": same row, same id, new raised_at.
      current = [
        _alertJson(105, tier: 'High', raisedAt: '2026-09-18T11:30:00+00:00'),
      ];
      await poller.poll();
      expect(notified, [105], reason: 're-raising must reach the crew');

      await poller.poll();
      expect(notified, [105], reason: 'but only once per re-raise');
    });

    test('an escalation on an already-seen alert notifies', () async {
      final notified = <int>[];
      var current = [_alertJson(7, tier: 'High')];
      final client = _clientReturning(() => current);
      client.authToken = 'test-token';

      final poller = AlertPoller.forTest(
        client: client,
        onNotify: (alert) async => notified.add(alert.id),
      );

      await poller.poll(); // prime
      current = [_alertJson(7, tier: 'Critical')];
      await poller.poll();

      expect(notified, [7], reason: 'High to Critical is news, same id or not');
    });

    test('acknowledging does NOT re-notify', () async {
      final notified = <int>[];
      var current = [_alertJson(3)];
      final client = _clientReturning(() => current);
      client.authToken = 'test-token';

      final poller = AlertPoller.forTest(
        client: client,
        onNotify: (alert) async => notified.add(alert.id),
      );

      await poller.poll(); // prime
      current = [_alertJson(3, status: 'acknowledged')];
      await poller.poll();

      expect(notified, isEmpty, reason: 'status changes are not new events');
    });

    test('signing out forgets history so the next user starts clean', () async {
      final notified = <int>[];
      final client = _clientReturning(() => [_alertJson(1)]);
      client.authToken = 'test-token';

      final poller = AlertPoller.forTest(
        client: client,
        onNotify: (alert) async => notified.add(alert.id),
      );

      await poller.poll();
      poller.stop();
      expect(poller.alerts, isEmpty);

      await poller.poll();
      expect(notified, isEmpty, reason: 'a fresh session re-primes rather than replaying');
    });

    test('open count drives the tab badge and drops on acknowledge', () async {
      final client = _clientReturning(() => [_alertJson(1), _alertJson(2)]);
      client.authToken = 'test-token';

      final poller = AlertPoller.forTest(client: client, onNotify: (_) async {});
      await poller.poll();
      expect(poller.openCount, 2);

      poller.markAcknowledgedLocally(1);
      expect(poller.openCount, 1, reason: 'the badge must update without waiting 30s');
      expect(poller.alerts.firstWhere((a) => a.id == 1).isAcknowledged, isTrue);
    });
  });
}
