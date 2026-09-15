import { Link } from "react-router-dom";
import { getMaintenancePlan } from "../api/client";
import { MOCK_MAINTENANCE_PLAN } from "../api/mockData";
import { useAsyncData } from "../hooks/useAsyncData";
import { RiskBadge } from "../components/RiskBadge";
import { EmptyBlock, ErrorBlock, FallbackBanner, LoadingBlock } from "../components/StatusStates";
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
    <div className="space-y-4">
      <div>
        <h1 className="font-mono text-lg font-bold tracking-widest text-slate-100 uppercase">
          Maintenance Plan
        </h1>
        {plan && (
          <p className="mt-1 text-sm text-slate-400">
            Generated {new Date(plan.generated_at).toLocaleString()}
          </p>
        )}
      </div>

      {isFallback && <FallbackBanner message={error ?? undefined} />}
      {loading && <LoadingBlock label="Generating maintenance plan" />}
      {!loading && error && !isFallback && <ErrorBlock message={error} />}

      {!loading && plan && plan.regions.length === 0 && (
        <EmptyBlock message="No maintenance actions recommended." />
      )}

      {plan && plan.regions.length > 0 && (
        <div className="space-y-5">
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
    <section className="border border-console-700 bg-console-900">
      <header className="border-b border-console-700 bg-console-850 px-4 py-3">
        <h2 className="font-mono text-sm font-bold tracking-widest text-slate-100 uppercase">
          {region}
        </h2>
        <p className="mt-1 text-xs text-slate-400">{weatherSummary}</p>
      </header>

      {items.length === 0 ? (
        <div className="px-4 py-6">
          <EmptyBlock message="No actions recommended for this region." />
        </div>
      ) : (
        <ul className="divide-y divide-console-800">
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
    <li className="flex flex-col gap-3 px-4 py-4 sm:flex-row sm:items-center sm:justify-between">
      <div className="min-w-0 flex-1">
        <div className="flex flex-wrap items-center gap-2">
          <Link
            to={`/assets/${item.asset_id}`}
            className="font-medium text-slate-100 hover:text-signal"
          >
            {item.asset_name}
          </Link>
          <RiskBadge tier={item.risk_tier} size="sm" />
          <span className="font-mono text-xs text-slate-500 font-tabular">
            score {item.risk_score}
          </span>
        </div>
        <p className="mt-1 text-sm text-slate-300">{item.recommended_action}</p>
        <p className="mt-0.5 text-xs text-slate-500">{item.rationale}</p>
      </div>

      <div
        className={`shrink-0 border px-3 py-2 text-right font-mono text-xs whitespace-nowrap ${
          isUrgent
            ? "border-risk-critical/50 bg-risk-critical/10 text-risk-critical"
            : "border-console-600 text-slate-400"
        }`}
      >
        <div className="font-semibold tracking-wide uppercase">
          By {item.recommended_by_date}
        </div>
        <div className="font-tabular">
          {days >= 0 ? `${days}d remaining` : "overdue"}
        </div>
      </div>
    </li>
  );
}
