import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import {
  ApiError,
  getAssignableAssets,
  getUsers,
  sendAlert,
} from "../api/client";
import type { AssignableAsset, OperatorUser, SentAlert } from "../api/types";

/**
 * Admin-only: raise a real alert so a named person is notified now.
 *
 * The automatic monitor only fires when an asset crosses up into High or
 * Critical on its own, which is correct in production and useless in a demo or
 * a drill. This sends the same kind of alert through the same pipeline — there
 * is deliberately no separate "test notification" path, because a test that
 * skips the real pipeline proves nothing about the real pipeline.
 *
 * Alerts are scoped by assignment, so a recipient with no coverage cannot see
 * anything sent to them. Rather than let an admin fire into the void, the asset
 * options are fetched per recipient and an unassigned user is shown the fix.
 */
export function SendAlertPanel({ onSent }: { onSent: () => void }) {
  const [open, setOpen] = useState(false);
  const [users, setUsers] = useState<OperatorUser[]>([]);
  const [recipientId, setRecipientId] = useState<number | "">("");
  const [assets, setAssets] = useState<AssignableAsset[] | null>(null);
  const [assetId, setAssetId] = useState("");
  const [busy, setBusy] = useState(false);
  const [failure, setFailure] = useState<string | null>(null);
  const [sent, setSent] = useState<SentAlert | null>(null);

  useEffect(() => {
    if (!open || users.length > 0) return;
    getUsers()
      .then(setUsers)
      .catch((err) =>
        setFailure(
          err instanceof ApiError ? err.message : "Could not load the team.",
        ),
      );
  }, [open, users.length]);

  // What a recipient can see is entirely a function of who they are, so the
  // asset options are reloaded whenever the recipient changes. The effect only
  // FETCHES — clearing the previous recipient's selection happens in the
  // change handler, which is the event that actually caused it.
  useEffect(() => {
    if (recipientId === "") return;
    let cancelled = false;

    getAssignableAssets(Number(recipientId))
      .then((list) => {
        if (!cancelled) setAssets(list);
      })
      .catch((err) => {
        if (cancelled) return;
        setFailure(
          err instanceof ApiError
            ? err.message
            : "Could not load their assets.",
        );
      });

    return () => {
      cancelled = true;
    };
  }, [recipientId]);

  async function handleSend() {
    if (recipientId === "") return;
    setBusy(true);
    setFailure(null);
    setSent(null);
    try {
      const result = await sendAlert({
        user_id: Number(recipientId),
        ...(assetId ? { asset_id: assetId } : {}),
      });
      setSent(result);
      onSent();
    } catch (err) {
      setFailure(
        err instanceof ApiError ? err.message : "Could not send the alert.",
      );
    } finally {
      setBusy(false);
    }
  }

  if (!open) {
    return (
      <div className="flex flex-wrap items-center gap-4 border border-carbon-gray-20 bg-carbon-white px-5 py-4">
        <div className="min-w-0 flex-1">
          <p className="font-serif text-lg font-semibold text-carbon-gray-100">
            Trigger an alert
          </p>
          <p className="mt-0.5 text-sm text-carbon-gray-70">
            Notify a specific crew member now, without waiting for an asset to
            cross tiers on its own.
          </p>
        </div>
        <button
          type="button"
          onClick={() => setOpen(true)}
          className="bg-carbon-blue-60 px-5 py-2.5 font-sans text-xs font-semibold tracking-wide text-carbon-white uppercase transition-colors hover:bg-carbon-blue-70 focus:ring-2 focus:ring-carbon-blue-60 focus:outline-none"
        >
          Send alert
        </button>
      </div>
    );
  }

  const hasNoScope = assets !== null && assets.length === 0;
  const recipient = users.find((user) => user.id === Number(recipientId));

  return (
    <section className="border border-carbon-gray-20 bg-carbon-white">
      <header className="flex items-center justify-between border-b border-carbon-gray-20 bg-carbon-gray-10/60 px-5 py-3">
        <p className="kicker">Trigger an alert</p>
        <button
          type="button"
          onClick={() => setOpen(false)}
          className="font-sans text-xs text-carbon-gray-60 transition-colors hover:text-carbon-gray-100"
        >
          Close
        </button>
      </header>

      <div className="space-y-5 p-5">
        <label className="block">
          <span className="kicker">Recipient</span>
          <select
            value={recipientId}
            onChange={(event) => {
              const value = event.target.value;
              setRecipientId(value === "" ? "" : Number(value));
              // Last recipient's options and result no longer apply.
              setAssets(null);
              setAssetId("");
              setSent(null);
              setFailure(null);
            }}
            className="mt-2 w-full border border-carbon-gray-30 bg-carbon-white px-3 py-2 font-sans text-sm text-carbon-gray-100 focus:border-carbon-blue-60 focus:outline-none"
          >
            <option value="">Choose a person…</option>
            {users.map((user) => (
              <option key={user.id} value={user.id}>
                {user.full_name} — {user.email} ({user.role})
              </option>
            ))}
          </select>
        </label>

        {recipientId !== "" && assets === null && !failure && (
          <p className="font-sans text-sm text-carbon-gray-60">
            Checking their coverage…
          </p>
        )}

        {hasNoScope && (
          <div className="border-l-2 border-risk-medium bg-risk-medium-bg px-4 py-3">
            <p className="font-sans text-sm font-bold text-carbon-gray-100">
              {recipient?.full_name ?? "That user"} has no coverage yet
            </p>
            <p className="mt-1 text-sm text-carbon-gray-70">
              Alerts only reach the people responsible for an asset. Assign them
              a region on{" "}
              <Link
                to="/admin/assignments"
                className="text-carbon-blue-70 underline"
              >
                Coverage
              </Link>
              , then send.
            </p>
          </div>
        )}

        {assets !== null && assets.length > 0 && (
          <label className="block">
            <span className="kicker">Asset</span>
            <select
              value={assetId}
              onChange={(event) => setAssetId(event.target.value)}
              className="mt-2 w-full border border-carbon-gray-30 bg-carbon-white px-3 py-2 font-sans text-sm text-carbon-gray-100 focus:border-carbon-blue-60 focus:outline-none"
            >
              <option value="">
                Highest risk in their area — {assets[0].name} (
                {assets[0].risk_score.toFixed(1)}/100)
              </option>
              {assets.map((asset) => (
                <option key={asset.asset_id} value={asset.asset_id}>
                  {asset.name} · {asset.region} ·{" "}
                  {asset.risk_score.toFixed(1)}/100
                </option>
              ))}
            </select>
          </label>
        )}

        {failure && (
          <div className="border-l-2 border-risk-critical bg-carbon-gray-10 px-4 py-3">
            <p className="text-sm text-carbon-gray-100">{failure}</p>
          </div>
        )}

        {sent && (
          <div className="border-l-2 border-risk-low bg-risk-low-bg px-4 py-3">
            <p className="font-sans text-sm font-bold text-carbon-gray-100">
              Alert #{sent.alert.id} sent to {sent.notified}
            </p>
            <p className="mt-1 text-sm text-carbon-gray-70">
              {sent.alert.headline}
            </p>
            <p className="mt-1 font-mono text-xs text-carbon-gray-60">
              In their inbox now · their phone notifies on the next poll.
            </p>
          </div>
        )}

        <button
          type="button"
          onClick={handleSend}
          disabled={busy || recipientId === "" || hasNoScope}
          className="w-full bg-carbon-blue-60 px-5 py-3 font-sans text-xs font-semibold tracking-wide text-carbon-white uppercase transition-colors hover:bg-carbon-blue-70 focus:ring-2 focus:ring-carbon-blue-60 focus:outline-none disabled:cursor-not-allowed disabled:bg-carbon-gray-20 disabled:text-carbon-gray-60"
        >
          {busy
            ? "Sending…"
            : recipient
              ? `Send alert to ${recipient.full_name}`
              : "Send alert"}
        </button>
      </div>
    </section>
  );
}
