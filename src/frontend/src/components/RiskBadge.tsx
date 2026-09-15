import type { RiskTier } from "../api/types";

const TIER_CLASSES: Record<RiskTier, string> = {
  Critical: "text-risk-critical bg-risk-critical-bg",
  High: "text-risk-high bg-risk-high-bg",
  Medium: "text-risk-medium bg-risk-medium-bg",
  Low: "text-risk-low bg-risk-low-bg",
};

const SIZE_CLASSES = {
  sm: "px-2 py-0.5 text-[10px]",
  md: "px-2 py-0.5 text-xs",
  lg: "px-3 py-1 text-sm",
};

interface RiskBadgeProps {
  tier: RiskTier;
  size?: keyof typeof SIZE_CLASSES;
}

export function RiskBadge({ tier, size = "md" }: RiskBadgeProps) {
  return (
    <span
      className={`inline-flex items-center gap-1.5 rounded-full font-sans font-medium tracking-wide ${TIER_CLASSES[tier]} ${SIZE_CLASSES[size]}`}
    >
      <span className="h-1.5 w-1.5 rounded-full bg-current" />
      {tier}
    </span>
  );
}
