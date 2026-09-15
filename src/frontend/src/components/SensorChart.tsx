import { Area, AreaChart, CartesianGrid, ResponsiveContainer, Tooltip, XAxis, YAxis } from "recharts";
import type { SensorReading } from "../api/types";
import { isDegrading, type TrendDirection } from "../lib/sensorTrend";

interface SensorChartProps {
  title: string;
  unit: string;
  data: SensorReading[];
  badDirection: TrendDirection;
}

export function SensorChart({ title, unit, data, badDirection }: SensorChartProps) {
  const degrading = isDegrading(data, badDirection);
  const lineColor = degrading ? "#9c2b1f" : "#2c6b46";
  // SVG gradient ids can't contain spaces — url(#fill-Partial Discharge) silently
  // truncates at the space and the fill falls back to solid black. Slugify so
  // multi-word titles (Partial Discharge, Oil Quality) render the same
  // gradient as single-word ones (Temperature, Vibration) did by accident.
  const gradientId = `fill-${title.replace(/\s+/g, "-")}`;

  return (
    <div className="border border-carbon-gray-20 bg-carbon-white p-5">
      <div className="mb-4 flex items-center justify-between border-b border-carbon-gray-20 pb-3">
        <h3 className="font-serif text-base font-semibold text-carbon-gray-100">
          {title} <span className="font-sans text-sm font-normal text-carbon-gray-70">({unit})</span>
        </h3>
        <span
          className={`font-sans text-xs font-semibold tracking-wide uppercase ${
            degrading ? "text-risk-critical" : "text-risk-low"
          }`}
        >
          {degrading ? "Degrading" : "Stable"}
        </span>
      </div>

      {data.length === 0 ? (
        <div className="flex h-40 items-center justify-center text-sm text-carbon-gray-60">
          No sensor data
        </div>
      ) : (
        <ResponsiveContainer width="100%" height={160}>
          <AreaChart data={data} margin={{ top: 4, right: 8, left: -20, bottom: 0 }}>
            <defs>
              <linearGradient id={gradientId} x1="0" y1="0" x2="0" y2="1">
                <stop offset="0%" stopColor={lineColor} stopOpacity={0.2} />
                <stop offset="100%" stopColor={lineColor} stopOpacity={0} />
              </linearGradient>
            </defs>
            <CartesianGrid stroke="#e6dfc9" strokeDasharray="2 4" vertical={false} />
            <XAxis
              dataKey="date"
              tick={{ fontSize: 10, fill: "#5c5440", fontFamily: "IBM Plex Mono" }}
              tickFormatter={(v: string) => v.slice(5)}
              axisLine={{ stroke: "#d6cbac" }}
              tickLine={false}
            />
            <YAxis
              tick={{ fontSize: 10, fill: "#5c5440", fontFamily: "IBM Plex Mono" }}
              tickFormatter={(v: number) => `${Math.round(v * 10) / 10}`}
              axisLine={false}
              tickLine={false}
              width={44}
            />
            <Tooltip
              contentStyle={{
                background: "#1c1810",
                border: "none",
                borderRadius: 0,
                fontSize: 12,
                fontFamily: "IBM Plex Sans",
                color: "#fffdf8"
              }}
              labelStyle={{ color: "#d6cbac", marginBottom: 4 }}
              formatter={(value) => [`${value}${unit}`, title]}
            />
            <Area
              type="monotone"
              dataKey="value"
              stroke={lineColor}
              strokeWidth={2}
              fill={`url(#${gradientId})`}
              dot={false}
            />
          </AreaChart>
        </ResponsiveContainer>
      )}
    </div>
  );
}
