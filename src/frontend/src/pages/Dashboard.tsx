import { useMemo, useState } from "react";
import { useNavigate } from "react-router-dom";
import { getAssets } from "../api/client";
import { MOCK_ASSETS } from "../api/mockData";
import { useAsyncData } from "../hooks/useAsyncData";
import { RiskBadge } from "../components/RiskBadge";
import {
  EmptyBlock,
  ErrorBlock,
  FallbackBanner,
  LoadingBlock,
} from "../components/StatusStates";
import type { Asset, RiskTier } from "../api/types";

const TIERS: RiskTier[] = ["Critical", "High", "Medium", "Low"];

const TIER_COLOR: Record<RiskTier, string> = {
  Critical: "var(--color-risk-critical)",
  High:     "var(--color-risk-high)",
  Medium:   "var(--color-risk-medium)",
  Low:      "var(--color-risk-low)",
};

/* ── KPI chip ───────────────────────────────────────── */
function KpiChip({
  tier,
  count,
  total,
}: {
  tier: RiskTier;
  count: number;
  total: number;
}) {
  const color = TIER_COLOR[tier];
  const pct = total > 0 ? (count / total) * 100 : 0;

  return (
    <div
      className="flex flex-1 flex-col gap-2 rounded-sm px-4 py-3"
      style={{
        backgroundColor: "var(--color-surface-1)",
        border: "1px solid var(--color-border-subtle)",
        borderTop: `2px solid ${color}`,
        minWidth: 120,
      }}
    >
      {/* Tier label */}
      <span
        className="font-sans text-[10px] font-semibold uppercase tracking-widest"
        style={{ color }}
      >
        {tier}
      </span>

      {/* Count */}
      <span
        className="font-mono text-2xl font-bold font-tabular leading-none"
        style={{ color: "var(--color-text-primary)" }}
      >
        {count}
      </span>

      {/* Mini progress bar */}
      <div
        className="h-1 w-full rounded-full overflow-hidden"
        style={{ backgroundColor: "var(--color-surface-3)" }}
        aria-hidden="true"
      >
        <div
          className="h-full rounded-full"
          style={{
            width: `${pct}%`,
            backgroundColor: color,
            transition: "width 600ms ease-out",
          }}
        />
      </div>
    </div>
  );
}

/* ── Filter select ──────────────────────────────────── */
interface FilterSelectProps {
  label: string;
  value: string;
  onChange: (value: string) => void;
  options: string[];
}

function FilterSelect({ label, value, onChange, options }: FilterSelectProps) {
  return (
    <label
      className="flex items-center gap-2 font-sans text-xs font-medium"
      style={{ color: "var(--color-text-secondary)" }}
    >
      <span className="uppercase tracking-wider">{label}</span>
      <select
        value={value}
        onChange={(e) => onChange(e.target.value)}
        className="cursor-pointer font-sans text-sm transition-colors focus:outline-none"
        style={{
          backgroundColor: "var(--color-surface-2)",
          color: "var(--color-text-primary)",
          border: "1px solid var(--color-border-default)",
          borderRadius: "2px",
          padding: "5px 10px",
          minWidth: 120,
        }}
        onFocus={(e) => {
          e.currentTarget.style.borderColor = "var(--color-accent)";
        }}
        onBlur={(e) => {
          e.currentTarget.style.borderColor = "var(--color-border-default)";
        }}
      >
        {options.map((opt) => (
          <option key={opt} value={opt}>
            {opt === "all" ? "All" : opt}
          </option>
        ))}
      </select>
    </label>
  );
}

/* ── Score cell with mini bar ───────────────────────── */
function ScoreBar({ score, tier }: { score: number; tier: RiskTier }) {
  const color = TIER_COLOR[tier];
  return (
    <div className="flex items-center gap-3">
      <span
        className="w-8 font-mono text-sm font-bold font-tabular"
        style={{ color: "var(--color-text-primary)" }}
      >
        {score}
      </span>
      <div
        className="h-1.5 flex-1 max-w-[64px] rounded-full overflow-hidden"
        style={{ backgroundColor: "var(--color-surface-3)" }}
        aria-hidden="true"
      >
        <div
          className="h-full rounded-full"
          style={{ width: `${score}%`, backgroundColor: color }}
        />
      </div>
    </div>
  );
}

/* ── Main page ──────────────────────────────────────── */
export function Dashboard() {
  const navigate = useNavigate();
  const {
    data: assets,
    loading,
    error,
    isFallback,
  } = useAsyncData(getAssets, () => MOCK_ASSETS, []);

  const [regionFilter, setRegionFilter] = useState<string>("all");
  const [tierFilter, setTierFilter] = useState<string>("all");
  const [sortDesc, setSortDesc] = useState(true);

  const regions = useMemo(
    () => Array.from(new Set((assets ?? []).map((a) => a.region))).sort(),
    [assets],
  );

  const rows = useMemo(() => {
    const filtered = (assets ?? []).filter(
      (a) =>
        (regionFilter === "all" || a.region === regionFilter) &&
        (tierFilter === "all" || a.risk_tier === tierFilter),
    );
    return filtered.sort((a, b) =>
      sortDesc ? b.risk_score - a.risk_score : a.risk_score - b.risk_score,
    );
  }, [assets, regionFilter, tierFilter, sortDesc]);

  /* KPI counts */
  const tierCounts = useMemo(() => {
    const all = assets ?? [];
    return TIERS.reduce(
      (acc, t) => {
        acc[t] = all.filter((a) => a.risk_tier === t).length;
        return acc;
      },
      {} as Record<RiskTier, number>,
    );
  }, [assets]);

  const totalAssets = assets?.length ?? 0;

  return (
    <div className="space-y-6 animate-fade-in-up">
      {/* ── Page header ── */}
      <div>
        <h1
          className="font-sans text-xl font-bold"
          style={{ color: "var(--color-text-primary)" }}
        >
          Asset Risk Overview
        </h1>
        <p
          className="mt-1 font-sans text-sm"
          style={{ color: "var(--color-text-secondary)" }}
        >
          All monitored grid assets, ranked by predicted failure risk.
        </p>
      </div>

      {/* ── Status banners ── */}
      {isFallback && <FallbackBanner message={error ?? undefined} />}
      {loading && <LoadingBlock label="Fetching assets" />}
      {!loading && error && !isFallback && <ErrorBlock message={error} />}

      {/* ── KPI chips (Serial Position — most critical info first) ── */}
      {!loading && assets && (
        <div className="flex flex-wrap gap-3">
          {TIERS.map((tier) => (
            <KpiChip
              key={tier}
              tier={tier}
              count={tierCounts[tier] ?? 0}
              total={totalAssets}
            />
          ))}
        </div>
      )}

      {/* ── Asset table ── */}
      {!loading && assets && (
        <div
          className="overflow-hidden rounded-sm"
          style={{
            backgroundColor: "var(--color-surface-1)",
            border: "1px solid var(--color-border-subtle)",
          }}
        >
          {/* Toolbar */}
          <div
            className="flex flex-wrap items-center gap-4 px-4 py-3"
            style={{ borderBottom: "1px solid var(--color-border-subtle)" }}
          >
            <FilterSelect
              label="Region"
              value={regionFilter}
              onChange={setRegionFilter}
              options={["all", ...regions]}
            />
            <FilterSelect
              label="Risk Tier"
              value={tierFilter}
              onChange={setTierFilter}
              options={["all", ...TIERS]}
            />
            <div
              className="ml-auto font-sans text-xs"
              style={{ color: "var(--color-text-tertiary)" }}
            >
              <strong style={{ color: "var(--color-text-primary)" }}>
                {rows.length}
              </strong>{" "}
              of {totalAssets} assets
            </div>
          </div>

          {/* Table */}
          {rows.length === 0 ? (
            <EmptyBlock message="No assets match the current filters." />
          ) : (
            <div className="overflow-x-auto">
              <table
                className="w-full border-collapse"
                style={{ fontSize: "13px" }}
              >
                <thead>
                  <tr
                    style={{
                      backgroundColor: "var(--color-surface-0)",
                      borderBottom: "1px solid var(--color-border-default)",
                    }}
                  >
                    {[
                      "Name",
                      "Type",
                      "Region",
                      "Tier",
                      null, // Risk Score — sortable
                      "Grid Impact",
                      "Customers",
                    ].map((col, i) =>
                      col === null ? (
                        <th
                          key="score"
                          className="px-4 py-3 text-left"
                          style={{
                            color: "var(--color-text-secondary)",
                            fontSize: "11px",
                            fontWeight: 600,
                            textTransform: "uppercase",
                            letterSpacing: "0.05em",
                          }}
                        >
                          <button
                            type="button"
                            onClick={() => setSortDesc((v) => !v)}
                            className="flex items-center gap-1 transition-colors focus:outline-none focus-visible:ring-1"
                            style={{
                              color: "var(--color-text-secondary)",
                              fontSize: "11px",
                              fontWeight: 600,
                              textTransform: "uppercase",
                              letterSpacing: "0.05em",
                            }}
                            onMouseEnter={(e) => {
                              e.currentTarget.style.color = "var(--color-accent)";
                            }}
                            onMouseLeave={(e) => {
                              e.currentTarget.style.color =
                                "var(--color-text-secondary)";
                            }}
                          >
                            Risk Score{" "}
                            <span aria-hidden="true">
                              {sortDesc ? "↓" : "↑"}
                            </span>
                          </button>
                        </th>
                      ) : (
                        <th
                          key={i}
                          className="px-4 py-3 text-left"
                          style={{
                            color: "var(--color-text-secondary)",
                            fontSize: "11px",
                            fontWeight: 600,
                            textTransform: "uppercase",
                            letterSpacing: "0.05em",
                          }}
                        >
                          {col}
                        </th>
                      ),
                    )}
                  </tr>
                </thead>
                <tbody>
                  {rows.map((asset: Asset, idx: number) => {
                    const isCritical = asset.risk_tier === "Critical";
                    const isHigh = asset.risk_tier === "High";

                    return (
                      <tr
                        key={asset.asset_id}
                        onClick={() => navigate(`/assets/${asset.asset_id}`)}
                        className="cursor-pointer transition-colors duration-100"
                        style={{
                          borderBottom: "1px solid var(--color-border-subtle)",
                          backgroundColor:
                            idx % 2 === 0
                              ? "var(--color-surface-1)"
                              : "var(--color-surface-0)",
                        }}
                        onMouseEnter={(e) => {
                          e.currentTarget.style.backgroundColor =
                            "var(--color-surface-2)";
                        }}
                        onMouseLeave={(e) => {
                          e.currentTarget.style.backgroundColor =
                            idx % 2 === 0
                              ? "var(--color-surface-1)"
                              : "var(--color-surface-0)";
                        }}
                      >
                        {/* Name — left indicator for Critical/High (Von Restorff) */}
                        <td
                          className="px-4 py-3 font-medium"
                          style={{
                            color: "var(--color-accent)",
                            borderLeft: isCritical
                              ? "2px solid var(--color-risk-critical)"
                              : isHigh
                                ? "2px solid var(--color-risk-high)"
                                : "2px solid transparent",
                          }}
                        >
                          {asset.name}
                        </td>
                        <td
                          className="px-4 py-3"
                          style={{ color: "var(--color-text-secondary)" }}
                        >
                          {asset.type}
                        </td>
                        <td
                          className="px-4 py-3"
                          style={{ color: "var(--color-text-secondary)" }}
                        >
                          {asset.region}
                        </td>
                        <td className="px-4 py-3">
                          <RiskBadge tier={asset.risk_tier} size="sm" />
                        </td>
                        <td className="px-4 py-3">
                          <ScoreBar
                            score={asset.risk_score}
                            tier={asset.risk_tier}
                          />
                        </td>
                        <td
                          className="px-4 py-3"
                          style={{ color: "var(--color-text-secondary)" }}
                        >
                          {asset.grid_impact_severity}
                        </td>
                        <td
                          className="px-4 py-3 font-mono font-tabular"
                          style={{ color: "var(--color-text-secondary)" }}
                        >
                          {asset.customers_served.toLocaleString()}
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
          )}
        </div>
      )}
    </div>
  );
}
