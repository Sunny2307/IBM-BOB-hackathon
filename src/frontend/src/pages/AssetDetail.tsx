import { Link, useParams } from "react-router-dom";
import { getAsset, getRiskBreakdown } from "../api/client";
import { getMockAsset, getMockRiskBreakdown } from "../api/mockData";
import { useAsyncData } from "../hooks/useAsyncData";
import { RiskBadge } from "../components/RiskBadge";
import { SensorChart } from "../components/SensorChart";
import { LastUpdated } from "../components/LastUpdated";
import { AssetDetailSkeleton } from "../components/Skeleton";
import { EmptyBlock, ErrorBlock, FallbackBanner } from "../components/StatusStates";
import type { RiskTier } from "../api/types";

const POLL_INTERVAL_MS = 30_000;

export function AssetDetail() {
  const { id } = useParams<{ id: string }>();
  const assetId = id ?? "";

  const asset = useAsyncData(() => getAsset(assetId), () => getMockAsset(assetId), [assetId], {
    pollIntervalMs: POLL_INTERVAL_MS,
  });
  const breakdown = useAsyncData(
    () => getRiskBreakdown(assetId),
    () => getMockRiskBreakdown(assetId),
    [assetId],
    { pollIntervalMs: POLL_INTERVAL_MS },
  );

  const isFallback = asset.isFallback || breakdown.isFallback;
  const isLoading = asset.loading || breakdown.loading;
  const isRefreshing = asset.isRefreshing || breakdown.isRefreshing;
  const fatalError = !isLoading && (asset.error && !asset.data ? asset.error : null);
  const lastUpdatedAt =
    asset.lastUpdatedAt && breakdown.lastUpdatedAt
      ? Math.min(asset.lastUpdatedAt, breakdown.lastUpdatedAt)
      : (asset.lastUpdatedAt ?? breakdown.lastUpdatedAt);

  function refreshAll() {
    asset.refetch();
    breakdown.refetch();
  }

  return (
    <div className="space-y-10">
      <div className="flex flex-wrap items-center justify-between gap-4 border-b border-carbon-gray-20 pb-4">
        <Link
          to="/"
          className="font-sans text-sm text-carbon-gray-70 transition-colors hover:text-carbon-gray-100"
        >
          &larr; Back to dashboard
        </Link>
        {asset.data && (
          <LastUpdated timestamp={lastUpdatedAt} isRefreshing={isRefreshing} onRefresh={refreshAll} />
        )}
      </div>

      {isFallback && <FallbackBanner message={asset.error ?? breakdown.error ?? undefined} />}
      {isLoading && <AssetDetailSkeleton />}
      {fatalError && <ErrorBlock message={fatalError} />}

      {!isLoading && !fatalError && !asset.data && (
        <EmptyBlock message="Asset not found." />
      )}

      {asset.data && (
        <>
          <AssetHeader
            name={asset.data.name}
            type={asset.data.type}
            region={asset.data.region}
            installYear={asset.data.install_year}
            capacityMva={asset.data.capacity_mva}
            customersServed={asset.data.customers_served}
            gridImpact={asset.data.grid_impact_severity}
            riskTier={asset.data.risk_tier}
            riskScore={asset.data.risk_score}
          />

          {breakdown.data && (
            <>
              <WhyThisScore components={breakdown.data.components} />

              <section>
                <p className="kicker mb-4">Sensor Trends</p>
                <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
                  <SensorChart
                    title="Temperature"
                    unit="°C"
                    data={breakdown.data.sensor_series.temperature}
                    badDirection="up"
                  />
                  <SensorChart
                    title="Vibration"
                    unit="mm/s"
                    data={breakdown.data.sensor_series.vibration}
                    badDirection="up"
                  />
                  <SensorChart
                    title="Partial Discharge"
                    unit="pC"
                    data={breakdown.data.sensor_series.partial_discharge}
                    badDirection="up"
                  />
                  <SensorChart
                    title="Oil Quality"
                    unit="%"
                    data={breakdown.data.sensor_series.oil_quality}
                    badDirection="down"
                  />
                </div>
              </section>

              <WeatherPanel
                region={breakdown.data.weather_context.region}
                forecast={breakdown.data.weather_context.forecast}
              />
            </>
          )}
        </>
      )}
    </div>
  );
}

interface AssetHeaderProps {
  name: string;
  type: string;
  region: string;
  installYear: number;
  capacityMva: number;
  customersServed: number;
  gridImpact: number;
  riskTier: RiskTier;
  riskScore: number;
}

function AssetHeader(props: AssetHeaderProps) {
  const fields: [string, string][] = [
    ["Installed", String(props.installYear)],
    ["Capacity", `${props.capacityMva} MVA`],
    ["Customers Served", props.customersServed.toLocaleString()],
    ["Grid Impact", `${props.gridImpact}/10`],
  ];

  return (
    <header className="border-b border-carbon-gray-20 pb-8">
      <div className="flex flex-wrap items-start justify-between gap-8">
        <div>
          <p className="kicker mb-2">{props.type} — {props.region}</p>
          <h1 className="font-serif text-4xl font-semibold tracking-tight text-carbon-gray-100">
            {props.name}
          </h1>
          <div className="mt-8 grid grid-cols-2 gap-x-12 gap-y-5 sm:grid-cols-3">
            {fields.map(([label, value]) => (
              <div key={label}>
                <dt className="kicker">{label}</dt>
                <dd className="mt-1.5 font-mono text-sm font-medium text-carbon-gray-100">
                  {value}
                </dd>
              </div>
            ))}
          </div>
        </div>

        <div className="flex flex-col items-end gap-3 border-l border-carbon-gray-20 pl-8">
          <RiskBadge tier={props.riskTier} size="lg" />
          <div className="font-mono text-5xl font-semibold text-carbon-gray-100">
            {props.riskScore}
            <span className="text-xl font-normal text-carbon-gray-60">/100</span>
          </div>
        </div>
      </div>
    </header>
  );
}

interface WhyThisScoreProps {
  components: { factor: string; contribution: number; explanation: string }[];
}

function WhyThisScore({ components }: WhyThisScoreProps) {
  if (components.length === 0) return null;

  const sorted = [...components].sort((a, b) => b.contribution - a.contribution);

  return (
    <section className="border border-carbon-gray-20 bg-carbon-white">
      <p className="kicker border-b border-carbon-gray-20 bg-carbon-gray-10/60 px-6 py-3">
        Why This Score
      </p>
      <ul className="divide-y divide-carbon-gray-20 px-6">
        {sorted.map((c) => (
          <li key={c.factor} className="flex gap-6 py-5">
            <span className="w-20 shrink-0 font-mono text-lg font-semibold text-carbon-gray-100">
              +{c.contribution}
            </span>
            <div>
              <p className="font-serif text-base font-semibold text-carbon-gray-100">
                {c.factor}
              </p>
              <p className="mt-1 text-sm text-carbon-gray-70">{c.explanation}</p>
            </div>
          </li>
        ))}
      </ul>
    </section>
  );
}

interface WeatherPanelProps {
  region: string;
  forecast: {
    date: string;
    temp_high_f: number;
    wind_speed_mph: number;
    precip_probability: number;
    storm_warning: boolean;
  }[];
}

function WeatherPanel({ region, forecast }: WeatherPanelProps) {
  return (
    <section>
      <p className="kicker mb-4">7-Day Weather Context — {region}</p>
      {forecast.length === 0 ? (
        <EmptyBlock message="No forecast data available." />
      ) : (
        <div className="grid grid-cols-2 divide-x divide-carbon-gray-20 border border-carbon-gray-20 bg-carbon-white sm:grid-cols-4 lg:grid-cols-7">
          {forecast.map((day) => (
            <div key={day.date} className="px-3 py-4">
              <p className="font-mono text-xs text-carbon-gray-60">{day.date.slice(5)}</p>
              <p className="mt-2 font-mono text-xl font-semibold text-carbon-gray-100">
                {day.temp_high_f}°F
              </p>
              <p className="mt-2 text-xs text-carbon-gray-70">Wind {day.wind_speed_mph} mph</p>
              <p className="text-xs text-carbon-gray-70">
                Precip {Math.round(day.precip_probability * 100)}%
              </p>
              {day.storm_warning && (
                <p className="mt-2 font-sans text-xs font-bold tracking-wide text-risk-critical uppercase">
                  Storm Warning
                </p>
              )}
            </div>
          ))}
        </div>
      )}
    </section>
  );
}
