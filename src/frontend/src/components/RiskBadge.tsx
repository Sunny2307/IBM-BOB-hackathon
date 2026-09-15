import type { RiskTier } from "../api/types";

const TIER_CLASSES: Record<RiskTier, string> = {
  Critical: "text-risk-critical border-risk-critical/50 bg-risk-critical/10",
  High: "text-risk-high border-risk-high/50 bg-risk-high/10",
  Medium: "text-risk-medium border-risk-medium/50 bg-risk-medium/10",
  Low: "text-risk-low border-risk-low/50 bg-risk-low/10",
};

const SIZE_CLASSES = {
  sm: "px-1.5 py-0.5 text-[10px]",
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
      className={`inline-flex items-center gap-1.5 border font-mono font-semibold tracking-widest uppercase ${TIER_CLASSES[tier]} ${SIZE_CLASSES[size]}`}
    >
      <span className="h-1.5 w-1.5 bg-current" />
      {tier}
    </span>
  );
}
