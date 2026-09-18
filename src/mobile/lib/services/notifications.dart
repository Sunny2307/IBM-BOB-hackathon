import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../api/types.dart';

/// Device notifications for new alerts.
///
/// Deliberately LOCAL notifications, not FCM. The app polls `/alerts/mine` and
/// raises the notification itself, which means no Firebase project, no
/// `google-services.json`, no APNs certificate — it works on any device the
/// moment you install the APK. The trade-off is honest and worth stating: this
/// fires while the app is running or backgrounded, not after it is force-killed.
/// The `alerts` table on the server is the seam where real push slots in later.
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static const _channelId = 'grid_alerts';
  static const _channelName = 'Grid risk alerts';
  static const _channelDescription =
      'Raised when an assigned asset crosses into High or Critical risk.';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _ready = false;

  /// Called once at startup. Failing here must not stop the app — a phone that
  /// refuses notification permission should still show the alert list.
  Future<void> init({void Function(int alertId)? onAlertTapped}) async {
    if (_ready) return;
    try {
      const settings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        ),
      );

      await _plugin.initialize(
        settings,
        onDidReceiveNotificationResponse: (response) {
          final payload = response.payload;
          final alertId = payload == null ? null : int.tryParse(payload);
          if (alertId != null) onAlertTapped?.call(alertId);
        },
      );

      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();

      _ready = true;
    } catch (err) {
      debugPrint('[notifications] init failed: $err');
    }
  }

  /// Raises one notification for one alert. The notification id is the alert
  /// id, so the same alert can never stack two notifications.
  Future<void> showAlert(Alert alert) async {
    if (!_ready) return;
    final isCritical = alert.tier == RiskTier.critical;

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        // Critical assets wake the screen; High lands quietly in the shade.
        importance: isCritical ? Importance.max : Importance.high,
        priority: isCritical ? Priority.high : Priority.defaultPriority,
        styleInformation: BigTextStyleInformation(alert.headline),
      ),
      iOS: const DarwinNotificationDetails(),
    );

    try {
      await _plugin.show(
        alert.id,
        '${alert.tier.label} — ${alert.assetName}',
        alert.headline,
        details,
        payload: '${alert.id}',
      );
    } catch (err) {
      debugPrint('[notifications] show failed: $err');
    }
  }
}
