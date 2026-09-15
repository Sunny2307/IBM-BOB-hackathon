import { useEffect, useState } from "react";

interface LastUpdatedProps {
  timestamp: number | null;
  isRefreshing: boolean;
  onRefresh: () => void;
}

function formatRelative(ms: number): string {
  const s = Math.floor(ms / 1000);
  if (s < 5) return "just now";
  if (s < 60) return `${s}s ago`;
  const m = Math.floor(s / 60);
  if (m < 60) return `${m}m ago`;
  const h = Math.floor(m / 60);
  return `${h}h ago`;
}

/**
 * "Live-updating feel" indicator: relative time since the last successful
 * fetch (real or fallback), a pulsing dot while a background refresh is in
 * flight, and a manual refresh button. Ticks locally every second so the
 * label stays fresh without waiting on the next poll.
 */
export function LastUpdated({ timestamp, isRefreshing, onRefresh }: LastUpdatedProps) {
  const [, setTick] = useState(0);

  useEffect(() => {
    const id = setInterval(() => setTick((t) => t + 1), 1000);
    return () => clearInterval(id);
  }, []);

  return (
    <div className="flex items-center gap-3 font-sans text-xs text-carbon-gray-70">
      <span className="flex items-center gap-1.5">
        <span
          className={`h-1.5 w-1.5 rounded-full ${
            isRefreshing ? "animate-pulse bg-carbon-blue-60" : "bg-risk-low"
          }`}
          aria-hidden
        />
        Updated {timestamp ? formatRelative(Date.now() - timestamp) : "—"}
      </span>
      <button
        type="button"
        onClick={onRefresh}
        disabled={isRefreshing}
        className="border border-carbon-gray-30 px-2 py-1 font-sans text-xs font-medium text-carbon-blue-60 transition-colors hover:bg-carbon-gray-10 disabled:cursor-not-allowed disabled:opacity-50"
      >
        {isRefreshing ? "Refreshing…" : "Refresh"}
      </button>
    </div>
  );
}
