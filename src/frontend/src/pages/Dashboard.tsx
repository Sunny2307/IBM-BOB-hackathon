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
    <div className="space-y-4">
      <div>
        <h1 className="font-mono text-lg font-bold tracking-widest text-slate-100 uppercase">
          Asset Risk Overview
        </h1>
        <p className="mt-1 text-sm text-slate-400">
          All monitored grid assets, ranked by predicted failure risk.
        </p>
      </div>

      {isFallback && <FallbackBanner message={error ?? undefined} />}

      {loading && <LoadingBlock label="Fetching assets" />}
      {!loading && error && !isFallback && <ErrorBlock message={error} />}

      {!loading && assets && (
        <>
          <div className="flex flex-wrap items-center gap-3 border border-console-700 bg-console-900 px-4 py-3">
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
            <div className="ml-auto font-mono text-xs text-slate-500">
              {rows.length} of {assets.length} assets
            </div>
          </div>

          {rows.length === 0 ? (
            <EmptyBlock message="No assets match the current filters." />
          ) : (
            <div className="overflow-x-auto border border-console-700">
              <table className="w-full border-collapse text-sm">
                <thead>
                  <tr className="border-b border-console-700 bg-console-900 text-left font-mono text-xs tracking-wide text-slate-400 uppercase">
                    <th className="px-4 py-2.5 font-medium">Name</th>
                    <th className="px-4 py-2.5 font-medium">Type</th>
                    <th className="px-4 py-2.5 font-medium">Region</th>
                    <th className="px-4 py-2.5 font-medium">Tier</th>
                    <th className="px-4 py-2.5 font-medium">
                      <button
                        type="button"
                        onClick={() => setSortDesc((v) => !v)}
                        className="flex items-center gap-1 hover:text-slate-100"
                      >
                        Risk Score {sortDesc ? "↓" : "↑"}
                      </button>
                    </th>
                    <th className="px-4 py-2.5 font-medium">Grid Impact</th>
                    <th className="px-4 py-2.5 font-medium">Customers</th>
                  </tr>
                </thead>
                <tbody>
                  {rows.map((asset) => (
                    <tr
                      key={asset.asset_id}
                      onClick={() => navigate(`/assets/${asset.asset_id}`)}
                      className="cursor-pointer border-b border-console-800 bg-console-950 transition-colors last:border-0 hover:bg-console-900"
                    >
                      <td className="px-4 py-2.5 font-medium text-slate-100">{asset.name}</td>
                      <td className="px-4 py-2.5 text-slate-400">{asset.type}</td>
                      <td className="px-4 py-2.5 text-slate-400">{asset.region}</td>
                      <td className="px-4 py-2.5">
                        <RiskBadge tier={asset.risk_tier} size="sm" />
                      </td>
                      <td className="px-4 py-2.5 font-mono font-tabular text-slate-100">
                        {asset.risk_score}
                      </td>
                      <td className="px-4 py-2.5 text-slate-400">{asset.grid_impact_severity}</td>
                      <td className="px-4 py-2.5 font-mono font-tabular text-slate-400">
                        {asset.customers_served.toLocaleString()}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </>
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
    <label className="flex items-center gap-2 font-mono text-xs text-slate-400">
      {label}
      <select
        value={value}
        onChange={(e) => onChange(e.target.value)}
        className="border border-console-600 bg-console-950 px-2 py-1 text-slate-100 focus:border-signal focus:outline-none"
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
