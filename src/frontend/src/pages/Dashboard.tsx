import { useMemo, useState, type ReactNode } from "react";
import { useNavigate } from "react-router-dom";
import { getAssets, getHealth } from "../api/client";
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
const PAGE_SIZE = 10;

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

  // Where the numbers come from, stated on the page rather than left to be
  // asked about: weather is a real live feed, the rest is generated.
  const { data: health } = useAsyncData(
    getHealth,
    () => ({ status: "ok", last_updated: null, weather_source: "synthetic" }),
    [],
  );

  const [regionFilter, setRegionFilter] = useState<string>("all");
  const [tierFilter, setTierFilter] = useState<string>("all");
  const [sortDesc, setSortDesc] = useState(true);
  const [page, setPage] = useState(1);

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

  const pageCount = Math.max(1, Math.ceil(rows.length / PAGE_SIZE));
  const clampedPage = Math.min(page, pageCount);
  const pageRows = useMemo(
    () => rows.slice((clampedPage - 1) * PAGE_SIZE, clampedPage * PAGE_SIZE),
    [rows, clampedPage],
  );

  function updateRegionFilter(value: string) {
    setRegionFilter(value);
    setPage(1);
  }

  function updateTierFilter(value: string) {
    setTierFilter(value);
    setPage(1);
  }

  function toggleSort() {
    setSortDesc((v) => !v);
    setPage(1);
  }

  return (
    <div className="space-y-12">
      <div className="flex flex-wrap items-end justify-between gap-4 border-b border-carbon-gray-20 pb-6">
        <div className="max-w-2xl">
          <p className="kicker mb-2">Live Overview</p>
          <h1 className="font-serif text-4xl font-semibold tracking-tight text-carbon-gray-100">
            Asset Risk Overview
          </h1>
          <p className="mt-3 font-serif text-base text-carbon-gray-70 italic">
            All monitored grid assets, ranked by predicted failure risk.
          </p>
          {health && <DataSourceLine weatherSource={health.weather_source} />}
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

          <section>
            <p className="kicker mb-3">Geographic Distribution</p>
            <GridMap assets={assets} />
          </section>

          <section>
            <div className="mb-4 flex flex-wrap items-end justify-between gap-4">
              <p className="kicker">All Assets</p>
              <div className="flex flex-wrap items-center gap-6">
                <FilterSelect
                  label="Region"
                  value={regionFilter}
                  onChange={updateRegionFilter}
                  options={["all", ...regions]}
                />
                <FilterSelect
                  label="Risk Tier"
                  value={tierFilter}
                  onChange={updateTierFilter}
                  options={["all", ...TIERS]}
                />
                <span className="font-mono text-xs text-carbon-gray-60">
                  {rows.length} of {assets.length}
                </span>
              </div>
            </div>

            {rows.length === 0 ? (
              <EmptyBlock message="No assets match the current filters." />
            ) : (
              <div className="border border-carbon-gray-20 bg-carbon-white">
                <div className="overflow-x-auto">
                  <table className="w-full border-collapse text-sm">
                    <thead className="bg-carbon-gray-10/60">
                      <tr className="text-left">
                        <th className="kicker px-3 py-3 border-b border-carbon-gray-20">Name</th>
                        <th className="kicker px-3 py-3 border-b border-carbon-gray-20">Type</th>
                        <th className="kicker px-3 py-3 border-b border-carbon-gray-20">Region</th>
                        <th className="kicker px-3 py-3 border-b border-carbon-gray-20">Tier</th>
                        <th className="kicker px-3 py-3 border-b border-carbon-gray-20">
                          <button
                            type="button"
                            onClick={toggleSort}
                            className="flex items-center gap-1 transition-colors hover:text-carbon-gray-100 focus:outline-none focus:ring-2 focus:ring-carbon-blue-60"
                          >
                            Risk Score {sortDesc ? "↓" : "↑"}
                          </button>
                        </th>
                        <th className="kicker px-3 py-3 border-b border-carbon-gray-20">
                          Grid Impact
                        </th>
                        <th className="kicker px-3 py-3 border-b border-carbon-gray-20">
                          Customers
                        </th>
                      </tr>
                    </thead>
                    <tbody className="divide-y divide-carbon-gray-20">
                      {pageRows.map((asset) => (
                        <tr
                          key={asset.asset_id}
                          onClick={() => navigate(`/assets/${asset.asset_id}`)}
                          className="cursor-pointer transition-colors hover:bg-carbon-gray-10"
                        >
                          <td className="px-3 py-4 font-serif text-[15px] font-medium text-carbon-gray-100">
                            {asset.name}
                          </td>
                          <td className="px-3 py-4 text-carbon-gray-70">{asset.type}</td>
                          <td className="px-3 py-4 text-carbon-gray-70">{asset.region}</td>
                          <td className="px-3 py-4">
                            <RiskBadge tier={asset.risk_tier} size="sm" />
                          </td>
                          <td className="px-3 py-4 font-mono font-tabular font-medium text-carbon-gray-100">
                            {asset.risk_score}
                          </td>
                          <td className="px-3 py-4 text-carbon-gray-70">
                            {asset.grid_impact_severity}
                          </td>
                          <td className="px-3 py-4 font-mono font-tabular text-carbon-gray-70">
                            {asset.customers_served.toLocaleString()}
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>

                {rows.length > 0 && (
                  <Pagination page={clampedPage} pageCount={pageCount} onChange={setPage} />
                )}
              </div>
            )}
          </section>
        </>
      )}
    </div>
  );
}

interface PaginationProps {
  page: number;
  pageCount: number;
  onChange: (page: number) => void;
}

function Pagination({ page, pageCount, onChange }: PaginationProps) {
  return (
    <div className="flex items-center justify-between gap-4 border-t border-carbon-gray-20 px-4 py-3">
      <span className="font-mono text-xs text-carbon-gray-60">
        Page {page} of {pageCount}
      </span>
      <div className="flex items-center gap-1">
        <PageButton onClick={() => onChange(1)} disabled={page === 1} label="First">
          «
        </PageButton>
        <PageButton onClick={() => onChange(page - 1)} disabled={page === 1} label="Previous">
          ‹
        </PageButton>
        {pageNumbersAround(page, pageCount).map((n) => (
          <button
            key={n}
            type="button"
            onClick={() => onChange(n)}
            aria-current={n === page ? "page" : undefined}
            className={`h-8 min-w-8 px-2 font-mono text-sm transition-colors focus:outline-none focus:ring-2 focus:ring-carbon-blue-60 ${
              n === page
                ? "border-b-2 border-carbon-gray-100 font-semibold text-carbon-gray-100"
                : "text-carbon-gray-60 hover:text-carbon-gray-100"
            }`}
          >
            {n}
          </button>
        ))}
        <PageButton onClick={() => onChange(page + 1)} disabled={page === pageCount} label="Next">
          ›
        </PageButton>
        <PageButton onClick={() => onChange(pageCount)} disabled={page === pageCount} label="Last">
          »
        </PageButton>
      </div>
    </div>
  );
}

function pageNumbersAround(page: number, pageCount: number): number[] {
  const span = 2;
  const start = Math.max(1, page - span);
  const end = Math.min(pageCount, page + span);
  return Array.from({ length: end - start + 1 }, (_, i) => start + i);
}

function PageButton({
  onClick,
  disabled,
  label,
  children,
}: {
  onClick: () => void;
  disabled: boolean;
  label: string;
  children: ReactNode;
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      disabled={disabled}
      aria-label={label}
      className="h-8 min-w-8 px-2 font-mono text-sm text-carbon-gray-60 transition-colors hover:text-carbon-gray-100 disabled:cursor-not-allowed disabled:text-carbon-gray-30 disabled:hover:text-carbon-gray-30 focus:outline-none focus:ring-2 focus:ring-carbon-blue-60"
    >
      {children}
    </button>
  );
}

/** Names each input feed so nobody has to guess which numbers are real. */
function DataSourceLine({ weatherSource }: { weatherSource: string }) {
  const isLive = weatherSource.startsWith("live");
  return (
    <p className="mt-3 flex flex-wrap items-center gap-x-2 gap-y-1 font-mono text-xs text-carbon-gray-60">
      <span className="inline-flex items-center gap-1.5">
        <span
          aria-hidden
          className={`inline-block h-1.5 w-1.5 rounded-full ${
            isLive ? "animate-pulse bg-risk-low" : "bg-carbon-gray-30"
          }`}
        />
        Weather: {weatherSource}
      </span>
      <span aria-hidden>·</span>
      <span>Sensors: simulated telemetry</span>
      <span aria-hidden>·</span>
      <span>Incidents: synthetic</span>
    </p>
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
    <div className="grid grid-cols-2 divide-y divide-carbon-gray-20 border-y border-carbon-gray-20 sm:grid-cols-4 sm:divide-x sm:divide-y-0">
      {tiles.map((tile) => (
        <div key={tile.label} className="px-6 py-5 first:pl-0">
          <p className="kicker">{tile.label}</p>
          <p
            className={`mt-2 border-b-2 pb-2 font-mono text-4xl font-semibold tabular-nums text-carbon-gray-100 ${tile.accent}`}
          >
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
        className="cursor-pointer border-b border-carbon-gray-60 bg-transparent px-1 py-1 text-sm text-carbon-gray-100 transition-colors hover:border-carbon-gray-100 focus:border-carbon-gray-100 focus:outline-none focus:ring-0"
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
