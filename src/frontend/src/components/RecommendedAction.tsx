import { getMaintenancePlan } from "../api/client";
import { MOCK_MAINTENANCE_PLAN } from "../api/mockData";
import { useAsyncData } from "../hooks/useAsyncData";
import {
  URGENT_WINDOW_DAYS,
  daysUntil,
  findPlanItem,
} from "../lib/maintenanceTiming";

/**
 * This asset's entry in the maintenance plan, shown on the asset page.
 *
 * Without it, clicking an asset from the Maintenance Plan lands on a page
 * identical to the one reached from the Dashboard — the recommended action,
 * the deadline and the reasoning all vanish at exactly the moment the operator
 * drilled in to read them. The plan says "dispatch a crew by Tuesday"; the
 * asset page should not then be silent about it.
 *
 * Fetched here rather than passed through router state so the section is
 * correct however the page was reached — deep link, refresh, or back button.
 */
export function RecommendedAction({ assetId }: { assetId: string }) {
  const { data: plan, loading } = useAsyncData(
    getMaintenancePlan,
    () => MOCK_MAINTENANCE_PLAN,
    [assetId],
  );

  if (loading) return null;

  const found = findPlanItem(plan, assetId);

  // Below the threshold for recommended work. Worth stating plainly — silence
  // here would read as "the page failed to load something".
  if (!found) {
    return (
      <section>
        <p className="kicker mb-3">Recommended Action</p>
        <p className="border border-carbon-gray-20 bg-carbon-white px-5 py-4 font-serif text-base text-carbon-gray-70 italic">
          No maintenance action is currently recommended for this asset.
        </p>
      </section>
    );
  }

  const { item, weatherSummary } = found;
  const days = daysUntil(item.recommended_by_date);
  const isUrgent = days <= URGENT_WINDOW_DAYS;

  return (
    <section>
      <p className="kicker mb-3">Recommended Action</p>
      <div
        className={`border border-l-2 border-carbon-gray-20 bg-carbon-white ${
          isUrgent ? "border-l-risk-critical" : "border-l-carbon-gray-30"
        }`}
      >
        <div className="flex flex-wrap items-start justify-between gap-6 px-5 py-5">
          <div className="min-w-0 flex-1">
            <p className="font-serif text-lg font-semibold text-carbon-gray-100">
              {item.recommended_action}
            </p>
            <p className="mt-2 text-sm text-carbon-gray-70">{item.rationale}</p>
          </div>

          <div className="shrink-0 text-right">
            <p className="kicker">Due</p>
            <p
              className={`mt-1 font-mono font-tabular text-lg font-semibold ${
                isUrgent ? "text-risk-critical" : "text-carbon-gray-100"
              }`}
            >
              {item.recommended_by_date}
            </p>
            <p className="mt-0.5 font-mono text-xs text-carbon-gray-60">
              {days >= 0 ? `${days}d remaining` : `${Math.abs(days)}d overdue`}
            </p>
          </div>
        </div>

        <div className="flex flex-wrap items-center gap-x-6 gap-y-2 border-t border-carbon-gray-20 px-5 py-3">
          <span className="font-mono text-xs text-carbon-gray-60">
            priority {Math.round(item.priority_score)}
          </span>
          <span className="text-sm text-carbon-gray-70 italic">
            {weatherSummary}
          </span>
        </div>
      </div>
    </section>
  );
}
