import { Link } from "react-router-dom";
import { getMaintenancePlan } from "../api/client";
import { MOCK_MAINTENANCE_PLAN } from "../api/mockData";
import { useAsyncData } from "../hooks/useAsyncData";
import { RiskBadge } from "../components/RiskBadge";
import { MaintenancePlanSkeleton } from "../components/Skeleton";
import { EmptyBlock, ErrorBlock, FallbackBanner } from "../components/StatusStates";
import type { MaintenanceItem } from "../api/types";

const URGENT_WINDOW_DAYS = 7;

function daysUntil(dateStr: string): number {
  const target = new Date(dateStr).getTime();
  const now = Date.now();
  return Math.ceil((target - now) / 86_400_000);
}

export function MaintenancePlan() {
  const { data: plan, loading, error, isFallback } = useAsyncData(
    getMaintenancePlan,
    () => MOCK_MAINTENANCE_PLAN,
    [],
  );

  return (
    <div className="space-y-10">
      <div className="border-b border-carbon-gray-20 pb-6">
        <p className="kicker mb-2">Prioritized Actions</p>
        <h1 className="font-serif text-4xl font-semibold tracking-tight text-carbon-gray-100">
          Maintenance Plan
        </h1>
        {plan && (
          <p className="mt-3 font-mono text-xs text-carbon-gray-60">
            Generated {new Date(plan.generated_at).toLocaleString()}
          </p>
        )}
      </div>

      {isFallback && <FallbackBanner message={error ?? undefined} />}
      {loading && <MaintenancePlanSkeleton />}
      {!loading && error && !isFallback && <ErrorBlock message={error} />}

      {!loading && plan && plan.regions.length === 0 && (
        <EmptyBlock message="No maintenance actions recommended." />
      )}

      {plan && plan.regions.length > 0 && (
        <div className="space-y-12">
          {plan.regions.map((region) => (
            <RegionCard key={region.region} region={region.region} weatherSummary={region.weather_summary} items={region.items} />
          ))}
        </div>
      )}
    </div>
  );
}

interface RegionCardProps {
  region: string;
  weatherSummary: string;
  items: MaintenanceItem[];
}

function RegionCard({ region, weatherSummary, items }: RegionCardProps) {
  return (
    <section className="border border-carbon-gray-20 bg-carbon-white">
      <header className="border-b border-carbon-gray-20 bg-carbon-gray-10/60 px-6 py-4">
        <h2 className="font-serif text-2xl font-semibold text-carbon-gray-100">{region}</h2>
        <p className="mt-1 text-sm text-carbon-gray-70 italic">{weatherSummary}</p>
      </header>

      {items.length === 0 ? (
        <div className="p-6">
          <EmptyBlock message="No actions recommended for this region." />
        </div>
      ) : (
        <ul className="divide-y divide-carbon-gray-20 px-6">
          {items.map((item) => (
            <MaintenanceRow key={item.asset_id} item={item} />
          ))}
        </ul>
      )}
    </section>
  );
}

function MaintenanceRow({ item }: { item: MaintenanceItem }) {
  const days = daysUntil(item.recommended_by_date);
  const isUrgent = days <= URGENT_WINDOW_DAYS;

  return (
    <li className="flex flex-col gap-4 py-6 transition-colors first:pt-0 sm:flex-row sm:items-start sm:justify-between">
      <div className="min-w-0 flex-1">
        <div className="flex flex-wrap items-center gap-3">
          <Link
            to={`/assets/${item.asset_id}`}
            className="font-serif text-lg font-semibold text-carbon-gray-100 transition-colors hover:text-carbon-blue-70"
          >
            {item.asset_name}
          </Link>
          <RiskBadge tier={item.risk_tier} size="sm" />
          <span className="font-mono text-xs font-tabular text-carbon-gray-60">
            score {item.risk_score}
          </span>
        </div>
        <p className="mt-2 text-sm font-medium text-carbon-gray-100">{item.recommended_action}</p>
        <p className="mt-1 text-sm text-carbon-gray-70">{item.rationale}</p>
      </div>

      <div
        className={`shrink-0 border-l-2 py-1 pl-4 text-right font-sans text-sm whitespace-nowrap ${
          isUrgent ? "border-risk-critical" : "border-carbon-gray-30 text-carbon-gray-70"
        }`}
      >
        <div className={`font-semibold ${isUrgent ? "text-risk-critical" : "text-carbon-gray-100"}`}>
          By {item.recommended_by_date}
        </div>
        <div className="mt-1 font-mono text-xs">
          {days >= 0 ? `${days}d remaining` : "overdue"}
        </div>
      </div>
    </li>
  );
}
