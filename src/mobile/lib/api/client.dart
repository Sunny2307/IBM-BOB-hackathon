import 'dart:convert';

import 'package:http/http.dart' as http;

import 'types.dart';

/// Where the backend lives when nothing is passed at build time — currently
/// the shared dev tunnel, so the app works on a real device without being on
/// the same network as the machine running uvicorn.
///
/// The tunnel must be set to **public** visibility; a private tunnel answers
/// with a Microsoft login page instead of JSON, which surfaces here as a
/// "Malformed JSON response" error.
const String defaultBaseUrl = 'https://4gs8lfzg-8000.inc1.devtunnels.ms';

/// Base URL of the existing FastAPI backend. Mirrors the web frontend's
/// `VITE_API_BASE_URL`, supplied at build time to override [defaultBaseUrl]:
///
///   flutter run --dart-define=API_BASE_URL=http://localhost:8000
///
/// Note for local runs: the Android emulator cannot reach the host's
/// `localhost` — use `http://10.0.2.2:8000`, its alias for the host machine.
const String _configuredBaseUrl = String.fromEnvironment('API_BASE_URL');

/// Trailing slashes are stripped so `'$apiBaseUrl$path'` can't produce a
/// double slash (`https://host//assets`), which some gateways 404 on.
String get apiBaseUrl => normalizeBaseUrl(
      _configuredBaseUrl.isNotEmpty ? _configuredBaseUrl : defaultBaseUrl,
    );

String normalizeBaseUrl(String raw) {
  var url = raw.trim();
  while (url.endsWith('/')) {
    url = url.substring(0, url.length - 1);
  }
  return url;
}

class ApiError implements Exception {
  ApiError(this.message, [this.status]);

  final String message;
  final int? status;

  @override
  String toString() => message;
}

/// Backend caps `CopilotRequest.history` at 20 messages (see schemas.py) —
/// each turn becomes 2 messages, so keep at most the last 10 turns.
const int maxCopilotHistoryTurns = 10;

class ApiClient {
  ApiClient({
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 8),
    this.copilotTimeout = const Duration(seconds: 45),
    this.getAttempts = 3,
  }) : _http = httpClient ?? http.Client();

  final http.Client _http;

  /// Per-attempt budget for the read endpoints. Deliberately short: measured
  /// against the dev tunnel, a healthy response lands in well under 1.2s, and
  /// anything slower is a dropped request that will never arrive. Failing fast
  /// and retrying beats waiting.
  final Duration timeout;

  /// The copilot is an LLM round-trip, so it gets a much longer budget and is
  /// never retried.
  final Duration copilotTimeout;

  /// How many times to attempt an (idempotent) GET before giving up.
  final int getAttempts;

  Future<dynamic> _request(
    String path, {
    String method = 'GET',
    Object? body,
  }) async {
    final uri = Uri.parse('$apiBaseUrl$path');
    final headers = {'Content-Type': 'application/json'};
    final isGet = method != 'POST';

    // The dev tunnel drops roughly one request in three outright — they hang
    // forever rather than erroring — while every response that does arrive
    // lands in under ~1.2s. So a short per-attempt timeout with a few retries
    // beats one long wait: three 8s attempts bound the worst case at 24s and
    // cut the drop rate to a few percent. Without this, a single dropped call
    // puts the user on the "demo data" fallback banner, which reads as a
    // broken demo.
    //
    // GETs are idempotent, so retrying is free. The copilot POST is not
    // retried — a retry would silently fire a second LLM call.
    final attempts = isGet ? getAttempts : 1;
    final budget = isGet ? timeout : copilotTimeout;
    http.Response? response;
    Object? lastFailure;

    for (var attempt = 0; attempt < attempts; attempt++) {
      try {
        response = isGet
            ? await _http.get(uri, headers: headers).timeout(budget)
            : await _http
                .post(uri, headers: headers, body: jsonEncode(body))
                .timeout(budget);
        // 502/503/504 are the tunnel giving up, not the API answering.
        if (response.statusCode < 502 || response.statusCode > 504) break;
        lastFailure = ApiError(
          '${response.statusCode} gateway error on $path',
          response.statusCode,
        );
      } catch (err) {
        lastFailure = err;
        response = null;
      }
    }

    if (response == null) {
      throw ApiError('Could not reach API at $uri');
    }
    if (lastFailure != null &&
        response.statusCode >= 502 &&
        response.statusCode <= 504) {
      throw ApiError(
        '${response.statusCode} gateway error on $path — backend or tunnel is not responding',
        response.statusCode,
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiError(
        '${response.statusCode} ${response.reasonPhrase ?? ''} on $path'.trim(),
        response.statusCode,
      );
    }

    try {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      throw ApiError('Malformed JSON response from $path');
    }
  }

  Future<List<Asset>> getAssets() async {
    final data = await _request('/assets');
    if (data is! List) throw ApiError('Expected a list of assets from /assets');
    return data
        .whereType<Map>()
        .map((e) => Asset.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  Future<Asset> getAsset(String id) async {
    final data = await _request('/assets/${Uri.encodeComponent(id)}');
    return Asset.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<RiskBreakdown> getRiskBreakdown(String id) async {
    final data =
        await _request('/assets/${Uri.encodeComponent(id)}/risk-breakdown');
    return RiskBreakdown.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<MaintenancePlan> getMaintenancePlan() async {
    final data = await _request('/maintenance-plan');
    return MaintenancePlan.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<CopilotResponse> askCopilot(
    String question, {
    List<CopilotHistoryTurn> history = const [],
  }) async {
    final data = await _request(
      '/copilot/ask',
      method: 'POST',
      body: {
        'question': question,
        'history': history.map((t) => t.toJson()).toList(),
      },
    );
    return CopilotResponse.fromJson((data as Map).cast<String, dynamic>());
  }

  void close() => _http.close();
}

/// Single shared client for the whole app.
final ApiClient api = ApiClient();
