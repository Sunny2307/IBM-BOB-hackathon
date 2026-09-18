import 'dart:async';

import 'package:flutter/foundation.dart';

import '../api/client.dart';
import '../api/types.dart';
import '../services/notifications.dart';

/// Polls the crew inbox and fires a device notification for anything new.
///
/// Deliberately NOT built on [AsyncData]. That class replaces its state
/// wholesale on every fetch, which is exactly right for a dashboard and
/// exactly wrong here: this needs to know which alerts it has *already seen*,
/// or every poll would re-notify the same five alerts forever.
///
/// The seen-set is seeded on the first successful poll without notifying. A
/// crew member opening the app should see their backlog in the list, not get
/// nine notifications at once for alerts raised while they were asleep.
class AlertPoller extends ChangeNotifier {
  AlertPoller._() : _api = api, _notify = NotificationService.instance.showAlert;

  /// Test seam. The dedup rule below is the one piece of logic in this class
  /// that can be wrong in a way nobody notices until crews start muting the
  /// app, so it needs to be reachable without a device or a live server.
  @visibleForTesting
  AlertPoller.forTest({
    required ApiClient client,
    required Future<void> Function(Alert) onNotify,
  })  : _api = client,
        _notify = onNotify;

  static final AlertPoller instance = AlertPoller._();

  final ApiClient _api;
  final Future<void> Function(Alert) _notify;

  static const pollInterval = Duration(seconds: 30);

  /// Signatures of alerts already notified — see [_signatureOf].
  final Set<String> _seen = {};
  Timer? _timer;
  bool _primed = false;

  List<Alert> _alerts = const [];
  bool _loading = false;
  String? _error;
  DateTime? _lastPolledAt;

  List<Alert> get alerts => List.unmodifiable(_alerts);

  bool get loading => _loading;

  String? get error => _error;

  DateTime? get lastPolledAt => _lastPolledAt;

  int get openCount => _alerts.where((a) => a.status == AlertStatus.open).length;

  int get criticalCount =>
      _alerts.where((a) => a.tier == RiskTier.critical).length;

  /// Begins polling. Safe to call more than once — a second call just refreshes.
  void start() {
    _timer?.cancel();
    _timer = Timer.periodic(pollInterval, (_) => poll());
    poll();
  }

  /// Stops polling and forgets what has been seen, so the next sign-in starts
  /// clean rather than inheriting the previous user's notification history.
  void stop() {
    _timer?.cancel();
    _timer = null;
    _seen.clear();
    _primed = false;
    _alerts = const [];
    _error = null;
    notifyListeners();
  }

  Future<void> poll() async {
    if (!_api.isAuthenticated) return;
    _loading = true;
    notifyListeners();

    try {
      final inbox = await _api.getMyAlerts(status: 'active');
      _alerts = inbox.alerts;
      _error = null;
      _lastPolledAt = DateTime.now();

      final fresh =
          _alerts.where((a) => !_seen.contains(_signatureOf(a))).toList();
      _seen.addAll(_alerts.map(_signatureOf));

      if (_primed) {
        for (final alert in fresh) {
          await _notify(alert);
        }
      } else {
        // First poll of the session: record the backlog, stay quiet.
        _primed = true;
      }
    } catch (err) {
      _error = err is ApiError ? err.message : 'Could not load alerts.';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// What counts as "an alert I have already notified about".
  ///
  /// The id alone is not enough. The server keeps ONE live alert row per asset
  /// and re-opens it rather than stacking duplicates, so a re-raised alert —
  /// an admin pressing "Send alert", or the monitor escalating High to
  /// Critical — arrives with an id the phone has already seen and would be
  /// silently swallowed.
  ///
  /// Including `raisedAt` makes a re-raise a genuinely new event, and `tier`
  /// makes an escalation one. Status is deliberately excluded: acknowledging
  /// an alert must not re-notify anyone.
  /// `raisedAt` is nullable (a malformed timestamp parses to null); falling
  /// back to 0 keeps such an alert stable rather than re-notifying on every
  /// poll, which is the safer failure.
  static String _signatureOf(Alert alert) =>
      '${alert.id}@${alert.raisedAt?.millisecondsSinceEpoch ?? 0}'
      '#${alert.tier.label}';

  /// Drops an alert from the local list after it is acknowledged, so the badge
  /// updates immediately instead of waiting up to 30s for the next poll.
  void markAcknowledgedLocally(int alertId) {
    _alerts = [
      for (final alert in _alerts)
        if (alert.id == alertId)
          Alert(
            id: alert.id,
            assetId: alert.assetId,
            assetName: alert.assetName,
            region: alert.region,
            tier: alert.tier,
            previousTier: alert.previousTier,
            riskScore: alert.riskScore,
            headline: alert.headline,
            status: AlertStatus.acknowledged,
            raisedAt: alert.raisedAt,
            acknowledgedByName: alert.acknowledgedByName,
            acknowledgedAt: DateTime.now(),
          )
        else
          alert,
    ];
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
