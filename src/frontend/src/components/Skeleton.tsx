// Shimmer placeholder blocks shaped like the real content they stand in for.
// Pure CSS animation (see .skeleton in src/index.css); prefers-reduced-motion
// disables the shimmer sweep globally.

interface BarProps {
  className?: string;
}

function Bar({ className = "" }: BarProps) {
  return <div className={`skeleton ${className}`} />;
}

export function StatTileRowSkeleton({ count = 4 }: { count?: number }) {
  return (
    <div className="grid grid-cols-2 gap-px border border-carbon-gray-20 bg-carbon-gray-20 sm:grid-cols-4">
      {Array.from({ length: count }).map((_, i) => (
        <div key={i} className="space-y-3 bg-carbon-white p-4">
          <Bar className="h-3 w-16" />
          <Bar className="h-8 w-20" />
        </div>
      ))}
    </div>
  );
}

export function MapSkeleton({ height = 380 }: { height?: number }) {
  return (
    <div className="border border-carbon-gray-20 bg-carbon-white p-2 shadow-sm" style={{ height }}>
      <Bar className="h-full w-full" />
    </div>
  );
}

export function ChartSkeleton() {
  return (
    <div className="border border-carbon-gray-20 bg-carbon-white p-4 shadow-sm">
      <div className="mb-4 flex items-center justify-between border-b border-carbon-gray-20 pb-2">
        <Bar className="h-4 w-32" />
        <Bar className="h-4 w-16" />
      </div>
      <Bar className="h-40 w-full" />
    </div>
  );
}

export function TableSkeleton({ rows = 6, cols = 7 }: { rows?: number; cols?: number }) {
  return (
    <div className="border border-carbon-gray-20 bg-carbon-white shadow-sm">
      <div className="flex items-center gap-4 border-b border-carbon-gray-20 px-4 py-3">
        <Bar className="h-6 w-28" />
        <Bar className="h-6 w-28" />
        <Bar className="ml-auto h-4 w-20" />
      </div>
      <div className="divide-y divide-carbon-gray-20">
        {Array.from({ length: rows }).map((_, r) => (
          <div key={r} className="flex items-center gap-6 px-4 py-3">
            {Array.from({ length: cols }).map((_, c) => (
              <Bar key={c} className="h-3 flex-1" />
            ))}
          </div>
        ))}
      </div>
    </div>
  );
}

export function AssetHeaderSkeleton() {
  return (
    <div className="border border-carbon-gray-20 bg-carbon-white p-6 shadow-sm">
      <div className="flex flex-wrap items-start justify-between gap-6">
        <div className="flex-1 space-y-6">
          <Bar className="h-7 w-64" />
          <div className="grid grid-cols-2 gap-x-12 gap-y-4 sm:grid-cols-3">
            {Array.from({ length: 6 }).map((_, i) => (
              <div key={i} className="space-y-2">
                <Bar className="h-3 w-16" />
                <Bar className="h-4 w-20" />
              </div>
            ))}
          </div>
        </div>
        <div className="space-y-3">
          <Bar className="h-6 w-20" />
          <Bar className="h-10 w-24" />
        </div>
      </div>
    </div>
  );
}

export function DashboardSkeleton() {
  return (
    <div className="space-y-6">
      <StatTileRowSkeleton />
      <MapSkeleton />
      <TableSkeleton />
    </div>
  );
}

export function MaintenancePlanSkeleton() {
  return (
    <div className="space-y-6">
      {Array.from({ length: 2 }).map((_, i) => (
        <div key={i} className="border border-carbon-gray-20 bg-carbon-white shadow-sm">
          <div className="space-y-2 border-b border-carbon-gray-20 bg-carbon-gray-10 px-6 py-4">
            <Bar className="h-4 w-40" />
            <Bar className="h-3 w-64" />
          </div>
          <div className="divide-y divide-carbon-gray-20">
            {Array.from({ length: 2 }).map((_, j) => (
              <div key={j} className="space-y-3 px-6 py-5">
                <Bar className="h-3 w-48" />
                <Bar className="h-3 w-full" />
                <Bar className="h-3 w-3/4" />
              </div>
            ))}
          </div>
        </div>
      ))}
    </div>
  );
}

export function AssetDetailSkeleton() {
  return (
    <div className="space-y-6">
      <AssetHeaderSkeleton />
      <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
        <ChartSkeleton />
        <ChartSkeleton />
        <ChartSkeleton />
        <ChartSkeleton />
      </div>
    </div>
  );
}
