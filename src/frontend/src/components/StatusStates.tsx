/* ─── Loading — skeleton shimmer ───────────────────────── */
interface LoadingBlockProps {
  label?: string;
}

export function LoadingBlock({ label = "Loading" }: LoadingBlockProps) {
  return (
    <div
      className="rounded-sm px-4 py-6"
      style={{ backgroundColor: "var(--color-surface-1)", border: "1px solid var(--color-border-subtle)" }}
      role="status"
      aria-label={`${label}…`}
    >
      {/* Label row */}
      <div className="mb-4 flex items-center gap-2">
        <span
          className="h-1.5 w-1.5 rounded-full"
          style={{ backgroundColor: "var(--color-accent)", animation: "var(--animate-pulse-ring)", display: "inline-block" }}
          aria-hidden="true"
        />
        <span
          className="font-sans text-xs font-medium"
          style={{ color: "var(--color-text-secondary)" }}
        >
          {label}…
        </span>
      </div>

      {/* Shimmer bars */}
      <div className="space-y-3">
        {[80, 60, 72].map((w) => (
          <div
            key={w}
            className="skeleton h-3 rounded-sm"
            style={{ width: `${w}%` }}
          />
        ))}
      </div>
    </div>
  );
}

/* ─── Empty ─────────────────────────────────────────────── */
interface EmptyBlockProps {
  message: string;
}

export function EmptyBlock({ message }: EmptyBlockProps) {
  return (
    <div
      className="flex flex-col items-center gap-4 px-4 py-12 text-center"
      style={{ backgroundColor: "var(--color-surface-1)", border: "1px solid var(--color-border-subtle)" }}
    >
      {/* Grid/signal icon */}
      <svg
        width="36"
        height="36"
        viewBox="0 0 36 36"
        fill="none"
        aria-hidden="true"
      >
        <rect x="4" y="4" width="8" height="8" rx="1" fill="var(--color-border-strong)" />
        <rect x="14" y="4" width="8" height="8" rx="1" fill="var(--color-border-default)" />
        <rect x="24" y="4" width="8" height="8" rx="1" fill="var(--color-border-subtle)" />
        <rect x="4" y="14" width="8" height="8" rx="1" fill="var(--color-border-default)" />
        <rect x="14" y="14" width="8" height="8" rx="1" fill="var(--color-border-subtle)" />
        <rect x="24" y="14" width="8" height="8" rx="1" fill="var(--color-border-subtle)" />
        <rect x="4" y="24" width="8" height="8" rx="1" fill="var(--color-border-subtle)" />
        <rect x="14" y="24" width="8" height="8" rx="1" fill="var(--color-border-subtle)" />
        <rect x="24" y="24" width="8" height="8" rx="1" fill="var(--color-border-subtle)" />
      </svg>

      <p
        className="font-sans text-sm"
        style={{ color: "var(--color-text-secondary)" }}
      >
        {message}
      </p>
    </div>
  );
}

/* ─── Error ─────────────────────────────────────────────── */
interface ErrorBlockProps {
  message: string;
}

export function ErrorBlock({ message }: ErrorBlockProps) {
  return (
    <div
      className="flex items-start gap-4 rounded-sm px-5 py-4"
      style={{
        backgroundColor: "var(--color-risk-critical-dim)",
        border: "1px solid rgba(255 77 79 / 0.3)",
        borderLeft: "3px solid var(--color-risk-critical)",
      }}
      role="alert"
    >
      {/* Error icon */}
      <svg
        width="16"
        height="16"
        viewBox="0 0 16 16"
        fill="none"
        aria-hidden="true"
        className="mt-0.5 shrink-0"
      >
        <circle cx="8" cy="8" r="7" stroke="var(--color-risk-critical)" strokeWidth="1.5" />
        <path d="M8 5v3.5" stroke="var(--color-risk-critical)" strokeWidth="1.5" strokeLinecap="round" />
        <circle cx="8" cy="11" r="0.75" fill="var(--color-risk-critical)" />
      </svg>

      <div>
        <p
          className="font-sans text-sm font-semibold"
          style={{ color: "var(--color-risk-critical)" }}
        >
          Connection Failed
        </p>
        <p
          className="mt-1 font-sans text-sm"
          style={{ color: "var(--color-text-secondary)" }}
        >
          {message}
        </p>
      </div>
    </div>
  );
}

/* ─── Fallback banner ────────────────────────────────────── */
interface FallbackBannerProps {
  message?: string;
}

export function FallbackBanner({
  message = "Backend unreachable — showing local demo data.",
}: FallbackBannerProps) {
  return (
    <div
      className="flex items-center gap-3 rounded-sm px-4 py-3"
      style={{
        backgroundColor: "var(--color-risk-medium-dim)",
        border: "1px solid rgba(250 219 20 / 0.2)",
        borderLeft: "3px solid var(--color-risk-medium)",
      }}
      role="status"
    >
      {/* Warning icon */}
      <svg
        width="14"
        height="14"
        viewBox="0 0 14 14"
        fill="none"
        aria-hidden="true"
        className="shrink-0"
      >
        <path
          d="M7 1L13 12H1L7 1Z"
          stroke="var(--color-risk-medium)"
          strokeWidth="1.5"
          strokeLinejoin="round"
        />
        <path d="M7 5.5v3" stroke="var(--color-risk-medium)" strokeWidth="1.5" strokeLinecap="round" />
        <circle cx="7" cy="10" r="0.75" fill="var(--color-risk-medium)" />
      </svg>

      <span className="font-sans text-sm" style={{ color: "var(--color-text-primary)" }}>
        <strong>Demo Data</strong> —{" "}
        <span style={{ color: "var(--color-text-secondary)" }}>{message}</span>
      </span>
    </div>
  );
}
