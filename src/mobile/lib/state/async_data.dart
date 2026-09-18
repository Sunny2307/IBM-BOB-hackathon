import 'dart:async';

import 'package:flutter/foundation.dart';

import '../api/client.dart';

/// Dart port of the web frontend's `useAsyncData` hook.
///
/// Fetches data from the real API. If the request fails (backend not running,
/// network error, non-2xx response), falls back to local mock data so the UI
/// stays demo-able. [isFallback] is surfaced so pages can show an unmissable
/// "demo data" banner instead of silently pretending it's live.
///
/// Also supports lightweight polling and a manual [refetch], both of which
/// refresh in the background ([isRefreshing]) rather than re-showing a loading
/// skeleton, so the page keeps its "live" feel instead of flashing empty.
class AsyncData<T> extends ChangeNotifier {
  AsyncData({
    required this.fetcher,
    required this.fallback,
    this.pollInterval,
    bool autoStart = true,
  }) {
    if (autoStart) load();
  }

  /// Hits the real backend.
  final Future<T> Function() fetcher;

  /// Local demo data used only when [fetcher] fails.
  final T Function() fallback;

  /// When set, re-fetches on this interval in the background.
  final Duration? pollInterval;

  T? _data;
  bool _loading = true;
  bool _isRefreshing = false;
  String? _error;
  bool _isFallback = false;
  DateTime? _lastUpdatedAt;

  Timer? _pollTimer;
  int _requestId = 0;
  bool _disposed = false;

  T? get data => _data;

  /// True only while there is no data on screen yet (first load).
  bool get loading => _loading;

  /// True while a background refresh (manual or polled) is in flight;
  /// [data] still holds the last good value.
  bool get isRefreshing => _isRefreshing;

  String? get error => _error;

  bool get isFallback => _isFallback;

  /// Wall-clock time of the last successful (real or fallback) fetch.
  DateTime? get lastUpdatedAt => _lastUpdatedAt;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// Re-run the fetch immediately without clearing currently displayed data.
  void refetch() => load();

  Future<void> load() async {
    final id = ++_requestId;
    final isInitialLoad = _data == null;

    _loading = isInitialLoad;
    _isRefreshing = !isInitialLoad;
    _error = null;
    _notify();

    _schedulePoll();

    try {
      final result = await fetcher();
      if (_disposed || id != _requestId) return;
      _data = result;
      _error = null;
      _isFallback = false;
      _lastUpdatedAt = DateTime.now();
    } catch (err) {
      if (_disposed || id != _requestId) return;
      final message = err is ApiError ? err.message : 'Unknown error';
      try {
        _data = fallback();
        _error = message;
        _isFallback = true;
        _lastUpdatedAt = DateTime.now();
      } catch (_) {
        _data = null;
        _error = message;
        _isFallback = false;
        _lastUpdatedAt = null;
      }
    } finally {
      if (!_disposed && id == _requestId) {
        _loading = false;
        _isRefreshing = false;
        _notify();
      }
    }
  }

  void _schedulePoll() {
    final interval = pollInterval;
    if (interval == null) return;
    _pollTimer?.cancel();
    _pollTimer = Timer(interval, load);
  }

  @override
  void dispose() {
    _disposed = true;
    _pollTimer?.cancel();
    super.dispose();
  }
}
