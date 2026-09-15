import { Link, useParams } from "react-router-dom";
import { getAsset, getRiskBreakdown } from "../api/client";
import { getMockAsset, getMockRiskBreakdown } from "../api/mockData";
import { useAsyncData } from "../hooks/useAsyncData";
import { RiskBadge } from "../components/RiskBadge";
import { SensorChart } from "../components/SensorChart";
import { EmptyBlock, ErrorBlock, FallbackBanner, LoadingBlock } from "../components/StatusStates";
import type { RiskTier } from "../api/types";

export function AssetDetail() {
  const { id } = useParams<{ id: string }>();
  const assetId = id ?? "";

  const asset = useAsyncData(() => getAsset(assetId), () => getMockAsset(assetId), [assetId]);
  const breakdown = useAsyncData(
    () => getRiskBreakdown(assetId),
    () => getMockRiskBreakdown(assetId),
    [assetId],
  );

  const isFallback = asset.isFallback || breakdown.isFallback;
  const isLoading = asset.loading || breakdown.loading;
  const fatalError = !isLoading && (asset.error && !asset.data ? asset.error : null);

  return (
    <div className="space-y-6">
      <Link to="/" className="font-mono text-xs text-slate-500 hover:text-signal">
        &larr; Back to dashboard
      </Link>

      {isFallback && <FallbackBanner message={asset.error ?? breakdown.error ?? undefined} />}
      {isLoading && <LoadingBlock label="Loading asset detail" />}
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
                <h2 className="mb-3 font-mono text-xs font-semibold tracking-widest text-slate-300 uppercase">
                  Sensor Trends
                </h2>
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
    ["Type", props.type],
    ["Region", props.region],
    ["Installed", String(props.installYear)],
    ["Capacity", `${props.capacityMva} MVA`],
    ["Customers Served", props.customersServed.toLocaleString()],
    ["Grid Impact", `${props.gridImpact}/10`],
  ];

  return (
    <header className="border border-console-700 bg-console-900 p-5">
      <div className="flex flex-wrap items-start justify-between gap-4">
        <div>
          <h1 className="font-mono text-xl font-bold text-slate-100">{props.name}</h1>
          <div className="mt-3 grid grid-cols-2 gap-x-8 gap-y-1.5 sm:grid-cols-3">
            {fields.map(([label, value]) => (
              <div key={label}>
                <dt className="font-mono text-[10px] tracking-widest text-slate-500 uppercase">
                  {label}
                </dt>
                <dd className="font-mono text-sm text-slate-200">{value}</dd>
              </div>
            ))}
          </div>
        </div>

        <div className="flex flex-col items-end gap-2">
          <RiskBadge tier={props.riskTier} size="lg" />
          <div className="font-mono text-4xl font-bold text-slate-100 font-tabular">
            {props.riskScore}
            <span className="text-base font-normal text-slate-500">/100</span>
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
    <section className="border-2 border-signal/50 bg-signal/5 p-5">
      <h2 className="mb-3 font-mono text-sm font-bold tracking-widest text-signal uppercase">
        Why This Score
      </h2>
      <ul className="space-y-3">
        {sorted.map((c) => (
          <li key={c.factor} className="flex gap-3">
            <span className="mt-0.5 w-16 shrink-0 font-mono text-sm font-bold text-signal font-tabular">
              +{c.contribution} pts
            </span>
            <div>
              <p className="text-sm font-semibold text-slate-100">{c.factor}</p>
              <p className="text-sm text-slate-400">{c.explanation}</p>
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
      <h2 className="mb-3 font-mono text-xs font-semibold tracking-widest text-slate-300 uppercase">
        7-Day Weather Context — {region}
      </h2>
      {forecast.length === 0 ? (
        <EmptyBlock message="No forecast data available." />
      ) : (
        <div className="grid grid-cols-2 gap-2 sm:grid-cols-4 lg:grid-cols-7">
          {forecast.map((day) => (
            <div
              key={day.date}
              className={`border p-3 ${
                day.storm_warning
                  ? "border-risk-critical/50 bg-risk-critical/10"
                  : "border-console-700 bg-console-900"
              }`}
            >
              <p className="font-mono text-[10px] tracking-widest text-slate-500 uppercase">
                {day.date.slice(5)}
              </p>
              <p className="mt-1 font-mono text-lg font-bold text-slate-100 font-tabular">
                {day.temp_high_f}°F
              </p>
              <p className="font-mono text-xs text-slate-400 font-tabular">
                Wind {day.wind_speed_mph} mph
              </p>
              <p className="font-mono text-xs text-slate-400 font-tabular">
                Precip {Math.round(day.precip_probability * 100)}%
              </p>
              {day.storm_warning && (
                <p className="mt-1 font-mono text-[10px] font-bold tracking-wide text-risk-critical uppercase">
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
