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
  const lineColor = degrading ? "#ef4444" : "#34d399";

  return (
    <div className="border border-console-700 bg-console-900 p-4">
      <div className="mb-3 flex items-center justify-between">
        <h3 className="font-mono text-xs font-semibold tracking-widest text-slate-300 uppercase">
          {title} <span className="text-slate-500 normal-case">({unit})</span>
        </h3>
        <span
          className={`font-mono text-[10px] font-semibold tracking-widest uppercase ${
            degrading ? "text-risk-critical" : "text-risk-low"
          }`}
        >
          {degrading ? "Degrading" : "Stable"}
        </span>
      </div>

      {data.length === 0 ? (
        <div className="flex h-40 items-center justify-center text-xs text-slate-600">
          No sensor data
        </div>
      ) : (
        <ResponsiveContainer width="100%" height={160}>
          <AreaChart data={data} margin={{ top: 4, right: 8, left: -20, bottom: 0 }}>
            <defs>
              <linearGradient id={`fill-${title}`} x1="0" y1="0" x2="0" y2="1">
                <stop offset="0%" stopColor={lineColor} stopOpacity={0.35} />
                <stop offset="100%" stopColor={lineColor} stopOpacity={0} />
              </linearGradient>
            </defs>
            <CartesianGrid stroke="#1e293b" strokeDasharray="2 4" vertical={false} />
            <XAxis
              dataKey="date"
              tick={{ fontSize: 10, fill: "#64748b", fontFamily: "JetBrains Mono" }}
              tickFormatter={(v: string) => v.slice(5)}
              axisLine={{ stroke: "#334155" }}
              tickLine={false}
            />
            <YAxis
              tick={{ fontSize: 10, fill: "#64748b", fontFamily: "JetBrains Mono" }}
              tickFormatter={(v: number) => `${Math.round(v * 10) / 10}`}
              axisLine={false}
              tickLine={false}
              width={44}
            />
            <Tooltip
              contentStyle={{
                background: "#0f172a",
                border: "1px solid #334155",
                borderRadius: 0,
                fontSize: 12,
                fontFamily: "JetBrains Mono",
              }}
              labelStyle={{ color: "#94a3b8" }}
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
