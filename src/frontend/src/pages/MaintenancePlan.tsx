import { Link } from "react-router-dom";
import { getMaintenancePlan } from "../api/client";
import { MOCK_MAINTENANCE_PLAN } from "../api/mockData";
import { useAsyncData } from "../hooks/useAsyncData";
import { RiskBadge } from "../components/RiskBadge";
import {
  EmptyBlock,
  ErrorBlock,
  FallbackBanner,
  LoadingBlock,
} from "../components/StatusStates";
import type { MaintenanceItem } from "../api/types";

const URGENT_WINDOW_DAYS = 7;
const WARN_WINDOW_DAYS = 14;

function daysUntil(dateStr: string): number {
  const target = new Date(dateStr).getTime();
  const now = Date.now();
  return Math.ceil((target - now) / 86_400_000);
}

/* ── Urgency badge ──────────────────────────────────── */
function UrgencyBadge({ days }: { days: number }) {
  const overdue  = days < 0;
  const urgent   = !overdue && days <= URGENT_WINDOW_DAYS;
  const warn     = !urgent && !overdue && days <= WARN_WINDOW_DAYS;

  const color = overdue || urgent
    ? "var(--color-risk-critical)"
    : warn
      ? "var(--color-risk-medium)"
      : "var(--color-risk-low)";

  const bg = overdue || urgent
    ? "var(--color-risk-critical-dim)"
    : warn
      ? "var(--color-risk-medium-dim)"
      : "var(--color-risk-low-dim)";

  const label = overdue ? "Overdue" : `${days}d left`;

  return (
    <span
      className="inline-block font-mono text-[10px] font-bold font-tabular uppercase tracking-wider px-2 py-1 rounded-sm"
      style={{
        color,
        backgroundColor: bg,
        border: `1px solid ${color}`,
        borderRadius: "2px",
      }}
    >
      {label}
    </span>
  );
}

/* ── Main page ──────────────────────────────────────── */
export function MaintenancePlan() {
  const {
    data: plan,
    loading,
    error,
    isFallback,
  } = useAsyncData(getMaintenancePlan, () => MOCK_MAINTENANCE_PLAN, []);

  return (
    <div className="space-y-6 animate-fade-in-up">
      {/* Page header */}
      <div>
        <h1
          className="font-sans text-xl font-bold"
          style={{ color: "var(--color-text-primary)" }}
        >
          Maintenance Plan
        </h1>
        {plan && (
          <p
            className="mt-1 font-sans text-sm"
            style={{ color: "var(--color-text-secondary)" }}
          >
            Generated{" "}
            <time dateTime={plan.generated_at}>
              {new Date(plan.generated_at).toLocaleString()}
            </time>
          </p>
        )}
      </div>

      {/* Status */}
      {isFallback && <FallbackBanner message={error ?? undefined} />}
      {loading && <LoadingBlock label="Generating maintenance plan" />}
      {!loading && error && !isFallback && <ErrorBlock message={error} />}

      {!loading && plan && plan.regions.length === 0 && (
        <EmptyBlock message="No maintenance actions recommended." />
      )}

      {plan && plan.regions.length > 0 && (
        <div className="space-y-6">
          {plan.regions.map((region) => (
            <RegionCard
              key={region.region}
              region={region.region}
              weatherSummary={region.weather_summary}
              items={region.items}
            />
          ))}
        </div>
      )}
    </div>
  );
}

/* ── Region card ────────────────────────────────────── */
interface RegionCardProps {
  region: string;
  weatherSummary: string;
  items: MaintenanceItem[];
}

function RegionCard({ region, weatherSummary, items }: RegionCardProps) {
  return (
    <section
      className="overflow-hidden rounded-sm"
      style={{
        backgroundColor: "var(--color-surface-1)",
        border: "1px solid var(--color-border-subtle)",
      }}
    >
      <header
        className="px-6 py-4"
        style={{
          backgroundColor: "var(--color-surface-2)",
          borderBottom: "1px solid var(--color-border-subtle)",
        }}
      >
        <h2
          className="font-sans text-sm font-bold uppercase tracking-wider"
          style={{ color: "var(--color-text-primary)" }}
        >
          {region}
        </h2>
        <p
          className="mt-1 font-sans text-xs"
          style={{ color: "var(--color-text-secondary)" }}
        >
          {weatherSummary}
        </p>
      </header>

      {items.length === 0 ? (
        <div className="px-6 py-8">
          <EmptyBlock message="No actions recommended for this region." />
        </div>
      ) : (
        <ul>
          {items.map((item, idx) => (
            <MaintenanceRow
              key={item.asset_id}
              item={item}
              isLast={idx === items.length - 1}
            />
          ))}
        </ul>
      )}
    </section>
  );
}

/* ── Maintenance row ────────────────────────────────── */
function MaintenanceRow({
  item,
  isLast,
}: {
  item: MaintenanceItem;
  isLast: boolean;
}) {
  const days = daysUntil(item.recommended_by_date);
  const isUrgent = days <= URGENT_WINDOW_DAYS;

  return (
    <li
      className="flex flex-col gap-4 px-6 py-5 transition-colors duration-100 sm:flex-row sm:items-center sm:justify-between"
      style={{
        borderBottom: isLast ? "none" : "1px solid var(--color-border-subtle)",
        borderLeft: isUrgent
          ? "3px solid var(--color-risk-critical)"
          : "3px solid transparent",
      }}
      onMouseEnter={(e) => {
        (e.currentTarget as HTMLLIElement).style.backgroundColor =
          "var(--color-surface-2)";
      }}
      onMouseLeave={(e) => {
        (e.currentTarget as HTMLLIElement).style.backgroundColor = "";
      }}
    >
      {/* Left: info */}
      <div className="min-w-0 flex-1">
        <div className="flex flex-wrap items-center gap-3">
          <Link
            to={`/assets/${item.asset_id}`}
            className="font-sans text-sm font-semibold transition-colors"
            style={{ color: "var(--color-accent)" }}
            onMouseEnter={(e) => {
              (e.currentTarget as HTMLAnchorElement).style.textDecoration =
                "underline";
            }}
            onMouseLeave={(e) => {
              (e.currentTarget as HTMLAnchorElement).style.textDecoration =
                "none";
            }}
          >
            {item.asset_name}
          </Link>
          <RiskBadge tier={item.risk_tier} size="sm" />
          <span
            className="font-mono text-[11px] font-tabular"
            style={{ color: "var(--color-text-tertiary)" }}
          >
            score {item.risk_score}
          </span>
        </div>

        <p
          className="mt-2 font-sans text-sm font-semibold"
          style={{ color: "var(--color-text-primary)" }}
        >
          {item.recommended_action}
        </p>
        <p
          className="mt-1 font-sans text-xs"
          style={{ color: "var(--color-text-secondary)" }}
        >
          {item.rationale}
        </p>
      </div>

      {/* Right: deadline */}
      <div className="flex shrink-0 flex-col items-end gap-2">
        <span
          className="font-sans text-xs font-medium"
          style={{ color: "var(--color-text-secondary)" }}
        >
          By{" "}
          <strong style={{ color: isUrgent ? "var(--color-risk-critical)" : "var(--color-text-primary)" }}>
            {item.recommended_by_date}
          </strong>
        </span>
        <UrgencyBadge days={days} />
      </div>
    </li>
  );
}
