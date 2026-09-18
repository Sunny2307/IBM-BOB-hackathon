import type { MaintenancePlan, MaintenanceItem } from "../api/types";

/** Inside this many days, a recommended action reads as urgent. */
export const URGENT_WINDOW_DAYS = 7;

/** Whole days from now until an ISO date. Negative means overdue. */
export function daysUntil(dateStr: string): number {
  const target = new Date(dateStr).getTime();
  return Math.ceil((target - Date.now()) / 86_400_000);
}

/**
 * Finds the plan entry for one asset, with the region it sits in.
 *
 * The plan is grouped by region and an asset belongs to exactly one, so this
 * flattens rather than making the caller nest two loops. Returns null when the
 * asset is below the threshold for recommended work — a normal state, not an
 * error.
 */
export function findPlanItem(
  plan: MaintenancePlan | null,
  assetId: string,
): { item: MaintenanceItem; region: string; weatherSummary: string } | null {
  if (!plan) return null;
  for (const region of plan.regions) {
    const item = region.items.find((entry) => entry.asset_id === assetId);
    if (item) {
      return {
        item,
        region: region.region,
        weatherSummary: region.weather_summary,
      };
    }
  }
  return null;
}
