import { useMemo, useState } from "react";
import { useNavigate } from "react-router-dom";
import { getAssets } from "../api/client";
import { MOCK_ASSETS } from "../api/mockData";
import { useAsyncData } from "../hooks/useAsyncData";
import { RiskBadge } from "../components/RiskBadge";
import { EmptyBlock, ErrorBlock, FallbackBanner, LoadingBlock } from "../components/StatusStates";
import type { RiskTier } from "../api/types";

const TIERS: RiskTier[] = ["Critical", "High", "Medium", "Low"];

export function Dashboard() {
  const navigate = useNavigate();
  const { data: assets, loading, error, isFallback } = useAsyncData(
    getAssets,
    () => MOCK_ASSETS,
    [],
  );

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

  return (
    <div className="space-y-6">
      <div>
        <h1 className="font-sans text-2xl font-light text-carbon-gray-100">
          Asset Risk Overview
        </h1>
        <p className="mt-2 text-sm text-carbon-gray-70">
          All monitored grid assets, ranked by predicted failure risk.
        </p>
      </div>

      {isFallback && <FallbackBanner message={error ?? undefined} />}

      {loading && <LoadingBlock label="Fetching assets" />}
      {!loading && error && !isFallback && <ErrorBlock message={error} />}

      {!loading && assets && (
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
      )}
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
