import { useState } from "react";
import { Link } from "react-router-dom";
import { acknowledgeAlert, ApiError, getMyAlerts } from "../api/client";
import { useAsyncData } from "../hooks/useAsyncData";
import { useAuth } from "../auth/AuthContext";
import { RiskBadge } from "../components/RiskBadge";
import { EmptyBlock, ErrorBlock, LoadingBlock } from "../components/StatusStates";
import type { Alert, AlertInbox, RiskTier } from "../api/types";

const POLL_INTERVAL_MS = 30_000;

const EMPTY_INBOX: AlertInbox = { count: 0, scope: "", alerts: [] };

export function Alerts() {
  const { session } = useAuth();
  // No mock fallback here on purpose: inventing alerts on an operations screen
  // would be worse than showing the error.
  const { data, loading, error, refetch } = useAsyncData(
    getMyAlerts,
    () => EMPTY_INBOX,
    [session?.user_id],
    { pollIntervalMs: POLL_INTERVAL_MS },
  );

  const alerts = data?.alerts ?? [];
  const open = alerts.filter((a) => a.status === "open");
  const acknowledged = alerts.filter((a) => a.status === "acknowledged");

  return (
    <div className="space-y-10">
      <div className="border-b border-carbon-gray-20 pb-6">
        <p className="kicker mb-2">Your inbox</p>
        <h1 className="font-serif text-4xl font-semibold tracking-tight text-carbon-gray-100">
          Alerts
        </h1>
        <p className="mt-3 font-serif text-base italic text-carbon-gray-70">
          {data?.scope
            ? `Showing ${data.scope}.`
            : "Raised when an asset crosses up into High or Critical risk."}
        </p>
      </div>

      {loading && alerts.length === 0 && <LoadingBlock label="Loading your alerts" />}
      {error && alerts.length === 0 && <ErrorBlock message={error} onRetry={refetch} />}

      {!loading && alerts.length === 0 && !error && (
        <EmptyBlock message="Nothing needs your attention. Every asset you are assigned to is below the High risk threshold." />
      )}

      {open.length > 0 && (
        <section>
          <p className="kicker mb-4">Needs action — {open.length}</p>
          <div className="space-y-4">
            {open.map((alert) => (
              <AlertCard key={alert.id} alert={alert} onChanged={refetch} />
            ))}
          </div>
        </section>
      )}

      {acknowledged.length > 0 && (
        <section>
          <p className="kicker mb-4">Acknowledged — {acknowledged.length}</p>
          <div className="space-y-4">
            {acknowledged.map((alert) => (
              <AlertCard key={alert.id} alert={alert} onChanged={refetch} />
            ))}
          </div>
        </section>
      )}
    </div>
  );
}

const TIER_BORDER: Record<string, string> = {
  Critical: "border-l-risk-critical",
  High: "border-l-risk-high",
};

function AlertCard({ alert, onChanged }: { alert: Alert; onChanged: () => void }) {
  const [busy, setBusy] = useState(false);
  const [failure, setFailure] = useState<string | null>(null);

  async function handleAcknowledge() {
    setBusy(true);
    setFailure(null);
    try {
      await acknowledgeAlert(alert.id);
      onChanged();
    } catch (err) {
      setFailure(err instanceof ApiError ? err.message : "Could not acknowledge.");
    } finally {
      setBusy(false);
    }
  }

  return (
    <article
      className={`border border-l-2 border-carbon-gray-20 bg-carbon-white p-5 ${
        TIER_BORDER[alert.tier] ?? "border-l-carbon-gray-30"
      }`}
    >
      <div className="flex flex-wrap items-center gap-3">
        <RiskBadge tier={alert.tier as RiskTier} size="sm" />
        {alert.previous_tier && (
          <span className="font-mono text-xs text-carbon-gray-60">
            {alert.previous_tier} → {alert.tier}
          </span>
        )}
        <span className="ml-auto font-mono text-xs text-carbon-gray-60">
          {new Date(alert.raised_at).toLocaleString()}
        </span>
      </div>

      <h2 className="mt-3 font-serif text-xl font-semibold text-carbon-gray-100">
        <Link to={`/assets/${alert.asset_id}`} className="hover:text-carbon-blue-70">
          {alert.asset_name}
        </Link>
      </h2>
      <p className="mt-1 font-mono text-xs text-carbon-gray-60">
        {alert.region} · {alert.asset_id} · risk {alert.risk_score.toFixed(1)}/100
      </p>
      <p className="mt-3 text-sm text-carbon-gray-70">{alert.headline}</p>

      {alert.status === "acknowledged" && (
        <p className="mt-3 font-sans text-xs font-semibold text-risk-low">
          Acknowledged by {alert.acknowledged_by_name ?? "you"}
          {alert.acknowledged_at && ` · ${new Date(alert.acknowledged_at).toLocaleString()}`}
        </p>
      )}

      {failure && <p className="mt-3 font-sans text-xs text-risk-critical">{failure}</p>}

      {alert.status === "open" && (
        <button
          type="button"
          onClick={handleAcknowledge}
          disabled={busy}
          className="mt-4 border-b border-carbon-blue-60 font-sans text-sm font-semibold text-carbon-blue-60 transition-colors hover:text-carbon-blue-70 disabled:opacity-50"
        >
          {busy ? "Acknowledging…" : "I'll take it"}
        </button>
      )}
    </article>
  );
}
