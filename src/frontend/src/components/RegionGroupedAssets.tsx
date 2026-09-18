import { useMemo, useState } from "react";
import { useNavigate } from "react-router-dom";
import { RiskBadge } from "./RiskBadge";
import type { Asset, RiskTier } from "../api/types";

const TIER_RANK: Record<RiskTier, number> = {
  Critical: 3,
  High: 2,
  Medium: 1,
  Low: 0,
};

interface RegionGroup {
  region: string;
  assets: Asset[];
  /** Highest tier present — what the region as a whole should be judged on. */
  worstTier: RiskTier;
  worstScore: number;
  criticalCount: number;
  highCount: number;
  customers: number;
}

function groupByRegion(assets: Asset[], sortDesc: boolean): RegionGroup[] {
  const byRegion = new Map<string, Asset[]>();
  for (const asset of assets) {
    const bucket = byRegion.get(asset.region);
    if (bucket) bucket.push(asset);
    else byRegion.set(asset.region, [asset]);
  }

  const groups: RegionGroup[] = [];
  for (const [region, regionAssets] of byRegion) {
    const ordered = [...regionAssets].sort((a, b) =>
      sortDesc ? b.risk_score - a.risk_score : a.risk_score - b.risk_score,
    );
    const worstTier = ordered.reduce<RiskTier>(
      (worst, asset) =>
        TIER_RANK[asset.risk_tier] > TIER_RANK[worst] ? asset.risk_tier : worst,
      "Low",
    );
    groups.push({
      region,
      assets: ordered,
      worstTier,
      worstScore: Math.max(...ordered.map((a) => a.risk_score)),
      criticalCount: ordered.filter((a) => a.risk_tier === "Critical").length,
      highCount: ordered.filter((a) => a.risk_tier === "High").length,
      customers: ordered.reduce((sum, a) => sum + a.customers_served, 0),
    });
  }

  // Regions carrying the worst asset come first: the point of the dashboard is
  // "where do I send a crew", and that is a question about regions.
  return groups.sort((a, b) =>
    sortDesc ? b.worstScore - a.worstScore : a.worstScore - b.worstScore,
  );
}

interface RegionGroupedAssetsProps {
  /** Already filtered by the dashboard's region/tier selects. */
  assets: Asset[];
  sortDesc: boolean;
  onToggleSort: () => void;
}

/**
 * The asset list, grouped into collapsible regions rather than one flat table.
 *
 * A utility runs tens of assets per region; a single ranked list of everything
 * buries the structure an operator actually works in — they dispatch crews by
 * region, not by scrolling a global leaderboard. Each region collapses to one
 * line carrying the numbers that decide whether to open it (worst tier, how
 * many Critical/High, customers exposed), and expands to the assets inside.
 *
 * The highest-risk region starts open so the screen still answers "what is
 * worst right now" without a click.
 */
export function RegionGroupedAssets({
  assets,
  sortDesc,
  onToggleSort,
}: RegionGroupedAssetsProps) {
  const navigate = useNavigate();
  const groups = useMemo(
    () => groupByRegion(assets, sortDesc),
    [assets, sortDesc],
  );

  // `null` means "not touched yet" — fall back to opening the worst region.
  const [openRegions, setOpenRegions] = useState<Set<string> | null>(null);

  const isOpen = (region: string) =>
    openRegions === null ? region === groups[0]?.region : openRegions.has(region);

  function toggleRegion(region: string) {
    setOpenRegions((current) => {
      const next = new Set(
        current ?? (groups[0] ? [groups[0].region] : []),
      );
      if (next.has(region)) next.delete(region);
      else next.add(region);
      return next;
    });
  }

  const allOpen = groups.length > 0 && groups.every((g) => isOpen(g.region));

  function toggleAll() {
    setOpenRegions(allOpen ? new Set() : new Set(groups.map((g) => g.region)));
  }

  return (
    <div className="space-y-3">
      <div className="flex items-center justify-between">
        <span className="font-mono text-xs text-carbon-gray-60">
          {groups.length} {groups.length === 1 ? "region" : "regions"}
        </span>
        <div className="flex items-center gap-5">
          <button
            type="button"
            onClick={onToggleSort}
            className="font-sans text-xs text-carbon-gray-70 transition-colors hover:text-carbon-gray-100 focus:ring-2 focus:ring-carbon-blue-60 focus:outline-none"
          >
            Risk score {sortDesc ? "↓" : "↑"}
          </button>
          <button
            type="button"
            onClick={toggleAll}
            className="font-sans text-xs text-carbon-blue-60 transition-colors hover:text-carbon-blue-70 focus:ring-2 focus:ring-carbon-blue-60 focus:outline-none"
          >
            {allOpen ? "Collapse all" : "Expand all"}
          </button>
        </div>
      </div>

      {groups.map((group) => {
        const expanded = isOpen(group.region);
        return (
          <section
            key={group.region}
            className="border border-carbon-gray-20 bg-carbon-white"
          >
            <button
              type="button"
              onClick={() => toggleRegion(group.region)}
              aria-expanded={expanded}
              className="flex w-full flex-wrap items-center gap-x-6 gap-y-2 px-4 py-4 text-left transition-colors hover:bg-carbon-gray-10 focus:ring-2 focus:ring-carbon-blue-60 focus:outline-none"
            >
              <span
                aria-hidden
                className={`font-mono text-xs text-carbon-gray-60 transition-transform ${
                  expanded ? "rotate-90" : ""
                }`}
              >
                ▶
              </span>

              <span className="font-serif text-lg font-semibold text-carbon-gray-100">
                {group.region}
              </span>

              <RiskBadge tier={group.worstTier} size="sm" />

              <span className="font-mono text-xs text-carbon-gray-60">
                {group.assets.length}{" "}
                {group.assets.length === 1 ? "asset" : "assets"}
              </span>

              {group.criticalCount > 0 && (
                <span className="font-sans text-xs font-semibold text-risk-critical">
                  {group.criticalCount} critical
                </span>
              )}
              {group.highCount > 0 && (
                <span className="font-sans text-xs font-semibold text-risk-high">
                  {group.highCount} high
                </span>
              )}

              <span className="ml-auto flex items-center gap-5">
                <span className="font-mono text-xs text-carbon-gray-60">
                  {group.customers.toLocaleString()} customers
                </span>
                <span className="font-mono font-tabular text-lg font-semibold text-carbon-gray-100">
                  {group.worstScore}
                </span>
              </span>
            </button>

            {expanded && (
              <div className="overflow-x-auto border-t border-carbon-gray-20">
                <table className="w-full border-collapse text-sm">
                  <thead className="bg-carbon-gray-10/60">
                    <tr className="text-left">
                      <th className="kicker border-b border-carbon-gray-20 px-3 py-2.5">
                        Name
                      </th>
                      <th className="kicker border-b border-carbon-gray-20 px-3 py-2.5">
                        Type
                      </th>
                      <th className="kicker border-b border-carbon-gray-20 px-3 py-2.5">
                        Tier
                      </th>
                      <th className="kicker border-b border-carbon-gray-20 px-3 py-2.5">
                        Risk Score
                      </th>
                      <th className="kicker border-b border-carbon-gray-20 px-3 py-2.5">
                        Grid Impact
                      </th>
                      <th className="kicker border-b border-carbon-gray-20 px-3 py-2.5">
                        Customers
                      </th>
                    </tr>
                  </thead>
                  {/* Region column is dropped — it is the heading above. */}
                  <tbody className="divide-y divide-carbon-gray-20">
                    {group.assets.map((asset) => (
                      <tr
                        key={asset.asset_id}
                        onClick={() => navigate(`/assets/${asset.asset_id}`)}
                        className="cursor-pointer transition-colors hover:bg-carbon-gray-10"
                      >
                        <td className="px-3 py-3.5 font-serif text-[15px] font-medium text-carbon-gray-100">
                          {asset.name}
                        </td>
                        <td className="px-3 py-3.5 text-carbon-gray-70">
                          {asset.type}
                        </td>
                        <td className="px-3 py-3.5">
                          <RiskBadge tier={asset.risk_tier} size="sm" />
                        </td>
                        <td className="px-3 py-3.5 font-mono font-tabular font-medium text-carbon-gray-100">
                          {asset.risk_score}
                        </td>
                        <td className="px-3 py-3.5 text-carbon-gray-70">
                          {asset.grid_impact_severity}
                        </td>
                        <td className="px-3 py-3.5 font-mono font-tabular text-carbon-gray-70">
                          {asset.customers_served.toLocaleString()}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </section>
        );
      })}
    </div>
  );
}
