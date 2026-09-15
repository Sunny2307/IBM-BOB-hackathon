import type { RiskTier } from "../api/types";

const TIER_TEXT: Record<RiskTier, string> = {
  Critical: "text-risk-critical",
  High: "text-risk-high",
  Medium: "text-risk-medium",
  Low: "text-risk-low",
};

const SIZE_CLASSES = {
  sm: { text: "text-[11px]", dot: "h-1.5 w-1.5" },
  md: { text: "text-xs", dot: "h-2 w-2" },
  lg: { text: "text-sm", dot: "h-2.5 w-2.5" },
};

interface RiskBadgeProps {
  tier: RiskTier;
  size?: keyof typeof SIZE_CLASSES;
}

/** A small, precise accent — a colored dot plus label, not a filled chip.
 * Risk-tier color is the only color signal in the UI, so it stays legible
 * as ink-colored text rather than being diluted into a pastel background. */
export function RiskBadge({ tier, size = "md" }: RiskBadgeProps) {
  const { text, dot } = SIZE_CLASSES[size];
  return (
    <span
      className={`inline-flex items-center gap-2 font-sans font-medium tracking-wide uppercase ${TIER_TEXT[tier]} ${text}`}
    >
      <span className={`${dot} shrink-0 rounded-full bg-current`} />
      {tier}
    </span>
  );
}
