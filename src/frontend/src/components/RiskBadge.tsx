import type { RiskTier } from "../api/types";

/* ─── Color tokens per tier ──────────────────────────── */
const TIER_COLOR: Record<RiskTier, { text: string; bg: string; border: string }> = {
  Critical: {
    text: "var(--color-risk-critical)",
    bg:   "var(--color-risk-critical-dim)",
    border: "var(--color-risk-critical)",
  },
  High: {
    text: "var(--color-risk-high)",
    bg:   "var(--color-risk-high-dim)",
    border: "var(--color-risk-high)",
  },
  Medium: {
    text: "var(--color-risk-medium)",
    bg:   "var(--color-risk-medium-dim)",
    border: "var(--color-risk-medium)",
  },
  Low: {
    text: "var(--color-risk-low)",
    bg:   "var(--color-risk-low-dim)",
    border: "var(--color-risk-low)",
  },
};

const SIZE_CLASSES = {
  sm: { px: "6px 8px", fontSize: "10px" },
  md: { px: "6px 10px", fontSize: "11px" },
  lg: { px: "6px 12px", fontSize: "13px" },
};

interface RiskBadgeProps {
  tier: RiskTier;
  size?: keyof typeof SIZE_CLASSES;
}

export function RiskBadge({ tier, size = "md" }: RiskBadgeProps) {
  const c = TIER_COLOR[tier];
  const s = SIZE_CLASSES[size];
  const isCritical = tier === "Critical";

  return (
    <span
      className="inline-flex items-center gap-1.5 font-sans font-semibold tracking-wide"
      style={{
        color: c.text,
        backgroundColor: c.bg,
        border: `1px solid ${c.border}`,
        borderRadius: "2px",
        padding: s.px,
        fontSize: s.fontSize,
        letterSpacing: "0.04em",
        textTransform: "uppercase",
        whiteSpace: "nowrap",
      }}
    >
      {/* Dot indicator — pulsing ring for Critical only (Von Restorff) */}
      <span
        className="relative flex shrink-0 items-center justify-center"
        style={{ width: 8, height: 8 }}
        aria-hidden="true"
      >
        {/* Static solid dot */}
        <span
          className="absolute rounded-full"
          style={{ width: 5, height: 5, backgroundColor: c.text }}
        />
        {/* Pulse ring for Critical */}
        {isCritical && (
          <span
            className="absolute rounded-full"
            style={{
              width: 8,
              height: 8,
              border: `1.5px solid ${c.text}`,
              animation: "var(--animate-pulse-ring)",
            }}
          />
        )}
      </span>
      {tier}
    </span>
  );
}
