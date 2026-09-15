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
  const lineColor = degrading ? "#da1e28" : "#24a148";

  return (
    <div className="border border-carbon-gray-20 bg-carbon-white p-4 shadow-sm">
      <div className="mb-4 flex items-center justify-between border-b border-carbon-gray-20 pb-2">
        <h3 className="font-sans text-sm font-semibold text-carbon-gray-100">
          {title} <span className="font-normal text-carbon-gray-70">({unit})</span>
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
              <linearGradient id={`fill-${title}`} x1="0" y1="0" x2="0" y2="1">
                <stop offset="0%" stopColor={lineColor} stopOpacity={0.2} />
                <stop offset="100%" stopColor={lineColor} stopOpacity={0} />
              </linearGradient>
            </defs>
            <CartesianGrid stroke="#e0e0e0" strokeDasharray="2 4" vertical={false} />
            <XAxis
              dataKey="date"
              tick={{ fontSize: 10, fill: "#525252", fontFamily: "IBM Plex Mono" }}
              tickFormatter={(v: string) => v.slice(5)}
              axisLine={{ stroke: "#c6c6c6" }}
              tickLine={false}
            />
            <YAxis
              tick={{ fontSize: 10, fill: "#525252", fontFamily: "IBM Plex Mono" }}
              tickFormatter={(v: number) => `${Math.round(v * 10) / 10}`}
              axisLine={false}
              tickLine={false}
              width={44}
            />
            <Tooltip
              contentStyle={{
                background: "#161616",
                border: "none",
                borderRadius: 0,
                fontSize: 12,
                fontFamily: "IBM Plex Sans",
                color: "#ffffff"
              }}
              labelStyle={{ color: "#c6c6c6", marginBottom: 4 }}
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
