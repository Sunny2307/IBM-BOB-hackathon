import { useMemo, useState } from "react";
import { useNavigate } from "react-router-dom";
import { getAssets } from "../api/client";
import { MOCK_ASSETS } from "../api/mockData";
import { useAsyncData } from "../hooks/useAsyncData";
import { RiskBadge } from "../components/RiskBadge";
import { GridMap } from "../components/GridMap";
import { LastUpdated } from "../components/LastUpdated";
import { DashboardSkeleton } from "../components/Skeleton";
import { EmptyBlock, ErrorBlock, FallbackBanner } from "../components/StatusStates";
import type { Asset, RiskTier } from "../api/types";

const TIERS: RiskTier[] = ["Critical", "High", "Medium", "Low"];
const POLL_INTERVAL_MS = 30_000;

export function Dashboard() {
  const navigate = useNavigate();
  const {
    data: assets,
    loading,
    isRefreshing,
    error,
    isFallback,
    lastUpdatedAt,
    refetch,
  } = useAsyncData(getAssets, () => MOCK_ASSETS, [], { pollIntervalMs: POLL_INTERVAL_MS });

  const [regionFilter, setRegionFilter] = useState<string>("all");
  const [tierFilter, setTierFilter] = useState<string>("all");
  const [sortDesc, setSortDesc] = useState(true);

  const regions = useMemo(
    () => Array.from(new Set((assets ?? []).map((a) => a.region))).sort(),
    [assets],
  );

  const stats = useMemo(() => computeStats(assets ?? []), [assets]);

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

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-end justify-between gap-4">
        <div>
          <h1 className="font-sans text-2xl font-light text-carbon-gray-100">
            Asset Risk Overview
          </h1>
          <p className="mt-2 text-sm text-carbon-gray-70">
            All monitored grid assets, ranked by predicted failure risk.
          </p>
        </div>
        {assets && (
          <LastUpdated timestamp={lastUpdatedAt} isRefreshing={isRefreshing} onRefresh={refetch} />
        )}
      </div>

      {isFallback && <FallbackBanner message={error ?? undefined} />}

      {loading && <DashboardSkeleton />}
      {!loading && error && !isFallback && <ErrorBlock message={error} />}

      {!loading && assets && (
        <>
          <StatTileRow stats={stats} />

          <GridMap assets={assets} />

          <div className="bg-carbon-white shadow-sm border border-carbon-gray-20">
            {/* Toolbar */}
            <div className="flex flex-wrap items-center gap-4 bg-carbon-white px-4 py-3 border-b border-carbon-gray-20">
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
              <div className="ml-auto font-sans text-sm text-carbon-gray-70">
                <strong>{rows.length}</strong> of {assets.length} items
              </div>
            </div>

            {/* Table */}
            {rows.length === 0 ? (
              <EmptyBlock message="No assets match the current filters." />
            ) : (
              <div className="overflow-x-auto">
                <table className="w-full border-collapse text-sm">
                  <thead>
                    <tr className="bg-carbon-gray-10 text-left font-sans text-xs font-semibold text-carbon-gray-100">
                      <th className="px-4 py-3 border-b border-carbon-gray-20">Name</th>
                      <th className="px-4 py-3 border-b border-carbon-gray-20">Type</th>
                      <th className="px-4 py-3 border-b border-carbon-gray-20">Region</th>
                      <th className="px-4 py-3 border-b border-carbon-gray-20">Tier</th>
                      <th className="px-4 py-3 border-b border-carbon-gray-20">
                        <button
                          type="button"
                          onClick={() => setSortDesc((v) => !v)}
                          className="flex items-center gap-1 hover:text-carbon-blue-60 transition-colors focus:outline-none focus:ring-2 focus:ring-carbon-blue-60"
                        >
                          Risk Score {sortDesc ? "↓" : "↑"}
                        </button>
                      </th>
                      <th className="px-4 py-3 border-b border-carbon-gray-20">Grid Impact</th>
                      <th className="px-4 py-3 border-b border-carbon-gray-20">Customers</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-carbon-gray-20">
                    {rows.map((asset) => (
                      <tr
                        key={asset.asset_id}
                        onClick={() => navigate(`/assets/${asset.asset_id}`)}
                        className="cursor-pointer bg-carbon-white transition-colors hover:bg-carbon-gray-10"
                      >
                        <td className="px-4 py-3 font-medium text-carbon-blue-70">{asset.name}</td>
                        <td className="px-4 py-3 text-carbon-gray-90">{asset.type}</td>
                        <td className="px-4 py-3 text-carbon-gray-90">{asset.region}</td>
                        <td className="px-4 py-3">
                          <RiskBadge tier={asset.risk_tier} size="sm" />
                        </td>
                        <td className="px-4 py-3 font-mono font-tabular text-carbon-gray-100 font-medium">
                          {asset.risk_score}
                        </td>
                        <td className="px-4 py-3 text-carbon-gray-90">{asset.grid_impact_severity}</td>
                        <td className="px-4 py-3 font-mono font-tabular text-carbon-gray-90">
                          {asset.customers_served.toLocaleString()}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </div>
        </>
      )}
    </div>
  );
}

interface DashboardStats {
  total: number;
  critical: number;
  avgScore: number;
  regionCount: number;
}

function computeStats(assets: Asset[]): DashboardStats {
  const total = assets.length;
  const critical = assets.filter((a) => a.risk_tier === "Critical").length;
  const avgScore = total === 0 ? 0 : Math.round(assets.reduce((sum, a) => sum + a.risk_score, 0) / total);
  const regionCount = new Set(assets.map((a) => a.region)).size;
  return { total, critical, avgScore, regionCount };
}

function StatTileRow({ stats }: { stats: DashboardStats }) {
  const tiles: { label: string; value: string; accent: string }[] = [
    { label: "Total Assets", value: String(stats.total), accent: "border-carbon-blue-60" },
    { label: "Critical Tier", value: String(stats.critical), accent: "border-risk-critical" },
    { label: "Avg. Risk Score", value: String(stats.avgScore), accent: "border-risk-medium" },
    { label: "Regions", value: String(stats.regionCount), accent: "border-risk-low" },
  ];

  return (
    <div className="grid grid-cols-2 gap-px border border-carbon-gray-20 bg-carbon-gray-20 sm:grid-cols-4">
      {tiles.map((tile) => (
        <div
          key={tile.label}
          className={`border-l-4 bg-carbon-white px-4 py-4 ${tile.accent}`}
        >
          <p className="font-sans text-[11px] font-semibold tracking-widest text-carbon-gray-70 uppercase">
            {tile.label}
          </p>
          <p className="mt-1 font-mono text-3xl font-semibold tabular-nums text-carbon-gray-100">
            {tile.value}
          </p>
        </div>
      ))}
    </div>
  );
}

interface FilterSelectProps {
  label: string;
  value: string;
  onChange: (value: string) => void;
  options: string[];
}

function FilterSelect({ label, value, onChange, options }: FilterSelectProps) {
  return (
    <label className="flex items-center gap-2 font-sans text-sm text-carbon-gray-70">
      {label}
      <select
        value={value}
        onChange={(e) => onChange(e.target.value)}
        className="border-b border-carbon-gray-60 bg-carbon-white px-2 py-1.5 text-sm text-carbon-gray-100 focus:border-carbon-blue-60 focus:outline-none focus:ring-0 cursor-pointer hover:bg-carbon-gray-10 transition-colors min-w-[120px]"
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
