import { Link, useParams } from "react-router-dom";
import { getAsset, getRiskBreakdown } from "../api/client";
import { getMockAsset, getMockRiskBreakdown } from "../api/mockData";
import { useAsyncData } from "../hooks/useAsyncData";
import { RiskBadge } from "../components/RiskBadge";
import { SensorChart } from "../components/SensorChart";
import {
  EmptyBlock,
  ErrorBlock,
  FallbackBanner,
  LoadingBlock,
} from "../components/StatusStates";
import type { RiskTier } from "../api/types";

const TIER_COLOR: Record<RiskTier, string> = {
  Critical: "var(--color-risk-critical)",
  High:     "var(--color-risk-high)",
  Medium:   "var(--color-risk-medium)",
  Low:      "var(--color-risk-low)",
};

/* ─────────────────────────────────────────────────────── */

export function AssetDetail() {
  const { id } = useParams<{ id: string }>();
  const assetId = id ?? "";

  const asset = useAsyncData(
    () => getAsset(assetId),
    () => getMockAsset(assetId),
    [assetId],
  );
  const breakdown = useAsyncData(
    () => getRiskBreakdown(assetId),
    () => getMockRiskBreakdown(assetId),
    [assetId],
  );

  const isFallback = asset.isFallback || breakdown.isFallback;
  const isLoading = asset.loading || breakdown.loading;
  const fatalError =
    !isLoading && (asset.error && !asset.data ? asset.error : null);

  return (
    <div className="space-y-6 animate-fade-in-up">
      {/* Back link */}
      <Link
        to="/"
        className="inline-flex items-center gap-1.5 font-sans text-sm font-medium transition-colors"
        style={{ color: "var(--color-text-secondary)" }}
        onMouseEnter={(e) => {
          (e.currentTarget as HTMLAnchorElement).style.color =
            "var(--color-accent)";
        }}
        onMouseLeave={(e) => {
          (e.currentTarget as HTMLAnchorElement).style.color =
            "var(--color-text-secondary)";
        }}
      >
        <span aria-hidden="true">←</span> Back to dashboard
      </Link>

      {/* Status banners */}
      {isFallback && (
        <FallbackBanner message={asset.error ?? breakdown.error ?? undefined} />
      )}
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
                <h2
                  className="mb-4 font-sans text-base font-semibold"
                  style={{ color: "var(--color-text-primary)" }}
                >
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

/* ── Asset header card ──────────────────────────────── */
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

  const accentColor = TIER_COLOR[props.riskTier];

  return (
    <header
      className="overflow-hidden rounded-sm"
      style={{
        backgroundColor: "var(--color-surface-1)",
        border: "1px solid var(--color-border-subtle)",
        borderTop: `3px solid ${accentColor}`,
      }}
    >
      <div className="flex flex-wrap items-start justify-between gap-8 p-6">
        {/* Left: name + stat tiles */}
        <div className="flex-1 min-w-0">
          <h1
            className="font-sans text-2xl font-bold leading-tight"
            style={{ color: "var(--color-text-primary)" }}
          >
            {props.name}
          </h1>

          <dl className="mt-5 grid grid-cols-2 gap-3 sm:grid-cols-3">
            {fields.map(([label, value]) => (
              <div
                key={label}
                className="rounded-sm px-3 py-2.5"
                style={{
                  backgroundColor: "var(--color-surface-2)",
                  border: "1px solid var(--color-border-subtle)",
                }}
              >
                <dt
                  className="font-sans text-[10px] font-semibold uppercase tracking-widest"
                  style={{ color: "var(--color-text-tertiary)" }}
                >
                  {label}
                </dt>
                <dd
                  className="mt-1 font-sans text-sm font-semibold"
                  style={{ color: "var(--color-text-primary)" }}
                >
                  {value}
                </dd>
              </div>
            ))}
          </dl>
        </div>

        {/* Right: risk score — Focal Point law — dominant element */}
        <div
          className="flex shrink-0 flex-col items-center gap-3 rounded-sm px-6 py-5"
          style={{
            backgroundColor: "var(--color-surface-2)",
            border: `1px solid ${accentColor}`,
            borderRadius: "2px",
            minWidth: 140,
          }}
        >
          <span
            className="font-sans text-[10px] font-semibold uppercase tracking-widest"
            style={{ color: "var(--color-text-tertiary)" }}
          >
            Risk Score
          </span>

          <div
            className="font-mono font-bold font-tabular leading-none"
            style={{
              fontSize: "3.5rem",
              color: accentColor,
              lineHeight: 1,
            }}
            aria-label={`Risk score: ${props.riskScore} out of 100`}
          >
            {props.riskScore}
            <span
              className="font-sans font-normal"
              style={{ fontSize: "1.25rem", color: "var(--color-text-tertiary)" }}
            >
              /100
            </span>
          </div>

          <RiskBadge tier={props.riskTier} size="lg" />
        </div>
      </div>
    </header>
  );
}

/* ── Why This Score — animated contribution bars ─────── */
interface WhyThisScoreProps {
  components: { factor: string; contribution: number; explanation: string }[];
}

function WhyThisScore({ components }: WhyThisScoreProps) {
  if (components.length === 0) return null;

  const sorted = [...components].sort((a, b) => b.contribution - a.contribution);
  const maxContribution = sorted[0]?.contribution ?? 1;

  return (
    <section
      className="rounded-sm p-6"
      style={{
        backgroundColor: "var(--color-surface-1)",
        border: "1px solid var(--color-border-subtle)",
        borderLeft: "3px solid var(--color-accent)",
      }}
    >
      <h2
        className="mb-5 font-sans text-base font-semibold"
        style={{ color: "var(--color-text-primary)" }}
      >
        Why This Score
      </h2>
      <ul className="space-y-5">
        {sorted.map((c) => {
          const pct = (c.contribution / maxContribution) * 100;
          return (
            <li key={c.factor}>
              <div className="mb-1.5 flex items-baseline justify-between gap-4">
                <span
                  className="font-sans text-sm font-semibold"
                  style={{ color: "var(--color-text-primary)" }}
                >
                  {c.factor}
                </span>
                <span
                  className="font-mono text-sm font-bold font-tabular shrink-0"
                  style={{ color: "var(--color-accent)" }}
                >
                  +{c.contribution} pts
                </span>
              </div>

              {/* Animated bar */}
              <div
                className="mb-2 h-1.5 w-full overflow-hidden rounded-full"
                style={{ backgroundColor: "var(--color-surface-3)" }}
                aria-hidden="true"
              >
                <div
                  className="h-full rounded-full"
                  style={{
                    width: `${pct}%`,
                    backgroundColor: "var(--color-accent)",
                    transition: "width 700ms ease-out",
                  }}
                />
              </div>

              <p
                className="font-sans text-xs"
                style={{ color: "var(--color-text-secondary)" }}
              >
                {c.explanation}
              </p>
            </li>
          );
        })}
      </ul>
    </section>
  );
}

/* ── Weather panel ──────────────────────────────────── */
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
      <h2
        className="mb-4 font-sans text-base font-semibold"
        style={{ color: "var(--color-text-primary)" }}
      >
        7-Day Weather Context —{" "}
        <span style={{ color: "var(--color-text-secondary)", fontWeight: 400 }}>
          {region}
        </span>
      </h2>

      {forecast.length === 0 ? (
        <EmptyBlock message="No forecast data available." />
      ) : (
        <div className="grid grid-cols-2 gap-3 sm:grid-cols-4 lg:grid-cols-7">
          {forecast.map((day) => (
            <div
              key={day.date}
              className="rounded-sm p-4"
              style={{
                backgroundColor: day.storm_warning
                  ? "var(--color-risk-critical-dim)"
                  : "var(--color-surface-1)",
                border: day.storm_warning
                  ? "1px solid rgba(255 77 79 / 0.4)"
                  : "1px solid var(--color-border-subtle)",
                borderTop: day.storm_warning
                  ? "2px solid var(--color-risk-critical)"
                  : "1px solid var(--color-border-subtle)",
              }}
            >
              <p
                className="font-sans text-[10px] font-semibold uppercase tracking-wider"
                style={{ color: "var(--color-text-tertiary)" }}
              >
                {day.date.slice(5)}
              </p>
              <p
                className="mt-2 font-mono text-xl font-bold font-tabular"
                style={{ color: "var(--color-text-primary)" }}
              >
                {day.temp_high_f}°
              </p>
              <p
                className="mt-2 font-sans text-[11px]"
                style={{ color: "var(--color-text-secondary)" }}
              >
                Wind {day.wind_speed_mph} mph
              </p>
              <p
                className="font-sans text-[11px]"
                style={{ color: "var(--color-text-secondary)" }}
              >
                Precip {Math.round(day.precip_probability * 100)}%
              </p>
              {day.storm_warning && (
                <p
                  className="mt-2 font-sans text-[10px] font-bold uppercase tracking-wider"
                  style={{ color: "var(--color-risk-critical)" }}
                >
                  ⚡ Storm
                </p>
              )}
            </div>
          ))}
        </div>
      )}
    </section>
  );
}
