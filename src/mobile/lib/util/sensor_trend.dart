import '../api/types.dart';

enum TrendDirection { up, down }

/// Port of the web frontend's `src/lib/sensorTrend.ts`.
///
/// Compares the average of the first third of readings against the last third
/// to determine trend direction, smoothing out day-to-day noise. Returns
/// whether the trend is moving toward the "bad" direction for that metric
/// (e.g. rising temperature, falling oil quality).
bool isDegrading(List<SensorReading> readings, TrendDirection badDirection) {
  if (readings.length < 2) return false;

  final chunk = (readings.length ~/ 3).clamp(1, readings.length);
  final early = readings.take(chunk);
  final late = readings.skip(readings.length - chunk);

  double avg(Iterable<SensorReading> items) =>
      items.fold<double>(0, (sum, r) => sum + r.value) / items.length;

  final delta = avg(late) - avg(early);

  return badDirection == TrendDirection.up ? delta > 0 : delta < 0;
}
