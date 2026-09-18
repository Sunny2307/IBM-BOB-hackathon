import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:grid_advisor_mobile/api/client.dart';
import 'package:grid_advisor_mobile/api/mock_data.dart';
import 'package:grid_advisor_mobile/api/types.dart';
import 'package:grid_advisor_mobile/state/async_data.dart';
import 'package:grid_advisor_mobile/theme/app_theme.dart';
import 'package:grid_advisor_mobile/util/formatting.dart';
import 'package:grid_advisor_mobile/util/sensor_trend.dart';
import 'package:grid_advisor_mobile/widgets/risk_badge.dart';
import 'package:grid_advisor_mobile/widgets/status_states.dart';

void main() {
  group('Asset.fromJson', () {
    test('parses the backend asset contract', () {
      final asset = Asset.fromJson(const {
        'asset_id': 'AST-014',
        'name': 'North Valley Transformer 03',
        'type': 'transformer',
        'lat': 37.9,
        'lon': -121.3,
        'region': 'North Valley',
        'install_year': 1998,
        'capacity_mva': 50,
        'customers_served': 8200,
        'grid_impact_severity': 9,
        'has_hospital_critical_load': true,
        'has_water_treatment_load': false,
        'has_redundancy': false,
        'risk_score': 91.0,
        'risk_tier': 'Critical',
      });

      expect(asset.assetId, 'AST-014');
      expect(asset.riskTier, RiskTier.critical);
      expect(asset.customersServed, 8200);
      expect(asset.hasHospitalCriticalLoad, isTrue);
    });

    test('parses the risk-breakdown contract including nested series', () {
      final breakdown = RiskBreakdown.fromJson(const {
        'asset_id': 'AST-014',
        'risk_score': 91,
        'risk_tier': 'Critical',
        'components': [
          {
            'factor': 'Weather Risk',
            'contribution': 25,
            'explanation': 'Storm warning',
          },
        ],
        'sensor_series': {
          'temperature': [
            {'date': '2026-09-01', 'value': 62.4},
          ],
          'vibration': <Map<String, dynamic>>[],
          'partial_discharge': <Map<String, dynamic>>[],
          'oil_quality': <Map<String, dynamic>>[],
        },
        'weather_context': {
          'region': 'North Valley',
          'forecast': [
            {
              'date': '2026-09-18',
              'temp_high_f': 75,
              'wind_speed_mph': 12,
              'precip_probability': 0.3,
              'storm_warning': true,
            },
          ],
        },
      });

      expect(breakdown.components.single.factor, 'Weather Risk');
      expect(breakdown.sensorSeries.temperature.single.value, 62.4);
      expect(breakdown.weatherContext.forecast.single.stormWarning, isTrue);
    });
  });

  group('base URL', () {
    test('defaults to the dev tunnel with no trailing slash', () {
      expect(apiBaseUrl, 'https://4gs8lfzg-8000.inc1.devtunnels.ms');
      expect(apiBaseUrl.endsWith('/'), isFalse);
    });

    test('strips trailing slashes so paths never double up', () {
      expect(
        normalizeBaseUrl('https://4gs8lfzg-8000.inc1.devtunnels.ms/'),
        'https://4gs8lfzg-8000.inc1.devtunnels.ms',
      );
      expect(normalizeBaseUrl('  http://localhost:8000//  '),
          'http://localhost:8000');
      expect(normalizeBaseUrl('http://localhost:8000'),
          'http://localhost:8000');
    });
  });

  group('ApiClient retry', () {
    test('retries a dropped GET until one lands', () async {
      var calls = 0;
      final client = ApiClient(
        httpClient: MockClient((request) async {
          calls++;
          if (calls < 3) throw const SocketException('dropped');
          return http.Response('[]', 200);
        }),
      );

      final assets = await client.getAssets();
      expect(calls, 3, reason: 'two drops, third attempt succeeds');
      expect(assets, isEmpty);
    });

    test('retries a GET on a 5xx gateway error', () async {
      var calls = 0;
      final client = ApiClient(
        httpClient: MockClient((request) async {
          calls++;
          if (calls == 1) return http.Response('', 504);
          return http.Response('[]', 200);
        }),
      );

      await client.getAssets();
      expect(calls, 2);
    });

    test('gives up after getAttempts and does not retry forever', () async {
      var calls = 0;
      final client = ApiClient(
        getAttempts: 3,
        httpClient: MockClient((request) async {
          calls++;
          throw const SocketException('dropped');
        }),
      );

      await expectLater(client.getAssets(), throwsA(isA<ApiError>()));
      expect(calls, 3);
    });

    test('a hung request is abandoned at the per-attempt timeout', () async {
      var calls = 0;
      final client = ApiClient(
        timeout: const Duration(milliseconds: 80),
        getAttempts: 2,
        httpClient: MockClient((request) async {
          calls++;
          if (calls == 1) {
            // Mimics the tunnel dropping a request: never completes.
            await Future<void>.delayed(const Duration(seconds: 30));
          }
          return http.Response('[]', 200);
        }),
      );

      final stopwatch = Stopwatch()..start();
      await client.getAssets();
      stopwatch.stop();

      expect(calls, 2);
      expect(
        stopwatch.elapsed,
        lessThan(const Duration(seconds: 5)),
        reason: 'must not wait on the hung attempt',
      );
    });

    test('surfaces a gateway error when both attempts fail', () async {
      final client = ApiClient(
        httpClient: MockClient((request) async => http.Response('', 504)),
      );

      await expectLater(
        client.getAssets(),
        throwsA(
          isA<ApiError>()
              .having((e) => e.status, 'status', 504)
              .having((e) => e.message, 'message', contains('gateway error')),
        ),
      );
    });

    test('does NOT retry the copilot POST', () async {
      var calls = 0;
      final client = ApiClient(
        httpClient: MockClient((request) async {
          calls++;
          throw const SocketException('down');
        }),
      );

      await expectLater(
        client.askCopilot('hi'),
        throwsA(isA<ApiError>()),
      );
      expect(calls, 1, reason: 'a retry would fire a second LLM call');
    });

    test('builds request paths without a double slash', () async {
      final seen = <String>[];
      final client = ApiClient(
        httpClient: MockClient((request) async {
          seen.add(request.url.toString());
          return http.Response('{}', 200);
        }),
      );

      await client.getRiskBreakdown('AST-001');
      expect(seen.single, '$defaultBaseUrl/assets/AST-001/risk-breakdown');
      expect(seen.single, isNot(contains('//assets')));
    });
  });

  group('AsyncData', () {
    test('serves live data when the fetch succeeds', () async {
      final controller = AsyncData<int>(
        fetcher: () async => 42,
        fallback: () => 0,
      );
      await Future<void>.delayed(Duration.zero);

      expect(controller.data, 42);
      expect(controller.isFallback, isFalse);
      expect(controller.error, isNull);
      expect(controller.loading, isFalse);
      controller.dispose();
    });

    test('falls back to mock data when the backend is unreachable', () async {
      final controller = AsyncData<List<Asset>>(
        fetcher: () async => throw ApiError('Could not reach API'),
        fallback: () => mockAssets,
      );
      await Future<void>.delayed(Duration.zero);

      expect(controller.isFallback, isTrue);
      expect(controller.error, 'Could not reach API');
      expect(controller.data, isNotEmpty);
      controller.dispose();
    });
  });

  group('sensor trend', () {
    test('rising series is degrading when up is the bad direction', () {
      final rising = [
        for (var i = 0; i < 30; i++)
          SensorReading(date: '2026-09-01', value: 60 + i.toDouble()),
      ];
      expect(isDegrading(rising, TrendDirection.up), isTrue);
      expect(isDegrading(rising, TrendDirection.down), isFalse);
    });

    test('too few readings are never degrading', () {
      expect(
        isDegrading(const [SensorReading(date: '2026-09-01', value: 1)],
            TrendDirection.up),
        isFalse,
      );
    });
  });

  group('formatting', () {
    test('scores drop a trailing .0 but keep real decimals', () {
      expect(formatScore(91.0), '91');
      expect(formatScore(16.5), '16.5');
    });

    test('counts are grouped and dates shortened like the web app', () {
      expect(formatCount(8200), '8,200');
      expect(shortDate('2026-09-18'), '09-18');
    });
  });

  testWidgets('RiskBadge renders the tier label in its tier color',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: const Scaffold(
          body: RiskBadge(tier: RiskTier.critical),
        ),
      ),
    );

    expect(find.text('CRITICAL'), findsOneWidget);
    final text = tester.widget<Text>(find.text('CRITICAL'));
    expect(text.style?.color, AppColors.riskCritical);
  });

  testWidgets('FallbackBanner is unmissable about showing demo data',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: const Scaffold(
          body: FallbackBanner(message: 'Could not reach API'),
        ),
      ),
    );

    expect(find.textContaining('SHOWING CACHED DEMO DATA'), findsOneWidget);
    expect(find.textContaining('Could not reach API'), findsOneWidget);
  });
}
