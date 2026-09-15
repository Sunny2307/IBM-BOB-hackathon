import {
  Area,
  AreaChart,
  CartesianGrid,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from "recharts";
import type { SensorReading } from "../api/types";
import { isDegrading, type TrendDirection } from "../lib/sensorTrend";

interface SensorChartProps {
  title: string;
  unit: string;
  data: SensorReading[];
  badDirection: TrendDirection;
}

export function SensorChart({
  title,
  unit,
  data,
  badDirection,
}: SensorChartProps) {
  const degrading = isDegrading(data, badDirection);
  const lineColor = degrading ? "#ff4d4f" : "#52c41a";

  return (
    <div
      className="rounded-sm p-4"
      style={{
        backgroundColor: "var(--color-surface-1)",
        border: "1px solid var(--color-border-subtle)",
        borderTop: `2px solid ${lineColor}`,
      }}
    >
      {/* Card header */}
      <div
        className="mb-4 flex items-center justify-between pb-3"
        style={{ borderBottom: "1px solid var(--color-border-subtle)" }}
      >
        <h3
          className="font-sans text-sm font-semibold"
          style={{ color: "var(--color-text-primary)" }}
        >
          {title}{" "}
          <span style={{ color: "var(--color-text-tertiary)", fontWeight: 400 }}>
            ({unit})
          </span>
        </h3>
        <span
          className="font-sans text-[10px] font-bold uppercase tracking-wider px-2 py-0.5 rounded-sm"
          style={{
            color: lineColor,
            backgroundColor: degrading
              ? "var(--color-risk-critical-dim)"
              : "var(--color-risk-low-dim)",
            border: `1px solid ${lineColor}`,
            borderRadius: "2px",
          }}
        >
          {degrading ? "Degrading" : "Stable"}
        </span>
      </div>

      {/* Chart */}
      {data.length === 0 ? (
        <div
          className="flex h-40 items-center justify-center font-sans text-sm"
          style={{ color: "var(--color-text-tertiary)" }}
        >
          No sensor data
        </div>
      ) : (
        <ResponsiveContainer width="100%" height={160}>
          <AreaChart
            data={data}
            margin={{ top: 4, right: 8, left: -20, bottom: 0 }}
          >
            <defs>
              <linearGradient id={`fill-${title}`} x1="0" y1="0" x2="0" y2="1">
                <stop offset="0%" stopColor={lineColor} stopOpacity={0.25} />
                <stop offset="100%" stopColor={lineColor} stopOpacity={0} />
              </linearGradient>
            </defs>
            <CartesianGrid
              stroke="rgba(255 255 255 / 0.05)"
              strokeDasharray="2 4"
              vertical={false}
            />
            <XAxis
              dataKey="date"
              tick={{
                fontSize: 10,
                fill: "var(--color-text-tertiary)",
                fontFamily: "IBM Plex Mono",
              }}
              tickFormatter={(v: string) => v.slice(5)}
              axisLine={{ stroke: "var(--color-border-subtle)" }}
              tickLine={false}
            />
            <YAxis
              tick={{
                fontSize: 10,
                fill: "var(--color-text-tertiary)",
                fontFamily: "IBM Plex Mono",
              }}
              tickFormatter={(v: number) => `${Math.round(v * 10) / 10}`}
              axisLine={false}
              tickLine={false}
              width={44}
            />
            <Tooltip
              contentStyle={{
                background: "hsl(220 12% 12%)",
                border: "1px solid rgba(255 255 255 / 0.12)",
                borderRadius: 2,
                fontSize: 12,
                fontFamily: "IBM Plex Sans",
                color: "hsl(220 20% 92%)",
              }}
              labelStyle={{ color: "hsl(220 12% 60%)", marginBottom: 4 }}
              formatter={(value) => [`${value}${unit}`, title]}
            />
            <Area
              type="monotone"
              dataKey="value"
              stroke={lineColor}
              strokeWidth={2}
              fill={`url(#fill-${title})`}
              dot={false}
            />
          </AreaChart>
        </ResponsiveContainer>
      )}
    </div>
  );
}
