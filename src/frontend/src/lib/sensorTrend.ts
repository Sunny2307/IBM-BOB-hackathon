import type { SensorReading } from "../api/types";

export type TrendDirection = "up" | "down";

/**
 * Compares the average of the first third of readings against the last
 * third to determine trend direction, smoothing out day-to-day noise.
 * Returns whether the trend is moving toward the "bad" direction for
 * that metric (e.g. rising temperature, falling oil quality).
 */
export function isDegrading(readings: SensorReading[], badDirection: TrendDirection): boolean {
  if (readings.length < 2) return false;

  const chunk = Math.max(1, Math.floor(readings.length / 3));
  const early = readings.slice(0, chunk);
  const late = readings.slice(-chunk);

  const avg = (arr: SensorReading[]) => arr.reduce((sum, r) => sum + r.value, 0) / arr.length;
  const delta = avg(late) - avg(early);

  return badDirection === "up" ? delta > 0 : delta < 0;
}
