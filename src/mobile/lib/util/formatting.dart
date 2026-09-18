import 'package:intl/intl.dart';

final NumberFormat _thousands = NumberFormat.decimalPattern('en_US');

/// `8200` -> `8,200`, matching the web's `Number.toLocaleString()`.
String formatCount(num value) => _thousands.format(value);

/// Risk scores come back as floats but read as integers in the UI
/// (`91.0` -> `91`, `16.5` -> `16.5`), matching how React renders them.
String formatScore(double value) =>
    value == value.roundToDouble() ? value.round().toString() : '$value';

/// `2026-09-18` -> `09-18`, matching the web's `date.slice(5)`.
String shortDate(String isoDate) =>
    isoDate.length >= 10 ? isoDate.substring(5, 10) : isoDate;

/// Port of `LastUpdated.formatRelative`.
String formatRelative(Duration elapsed) {
  final s = elapsed.inSeconds;
  if (s < 5) return 'just now';
  if (s < 60) return '${s}s ago';
  final m = elapsed.inMinutes;
  if (m < 60) return '${m}m ago';
  return '${elapsed.inHours}h ago';
}

/// Whole days between now and an ISO date string. Port of
/// `MaintenancePlan.daysUntil` (ceil of the millisecond delta).
int daysUntil(String isoDate) {
  final target = DateTime.tryParse(isoDate);
  if (target == null) return 0;
  final deltaMs = target.millisecondsSinceEpoch -
      DateTime.now().millisecondsSinceEpoch;
  return (deltaMs / Duration.millisecondsPerDay).ceil();
}

/// `2026-09-18T11:24:00` -> a readable local timestamp, matching the web's
/// `new Date(plan.generated_at).toLocaleString()`.
String formatGeneratedAt(String raw) {
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return raw;
  return DateFormat('MMM d, y · h:mm a').format(parsed.toLocal());
}
