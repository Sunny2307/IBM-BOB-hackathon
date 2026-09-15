import type { RiskTier } from "../api/types";

// Single source of truth for risk-tier color values, mirroring the Tailwind
// tokens defined in src/index.css (--color-risk-*). RiskBadge uses the
// Tailwind utility classes directly; anything that needs a raw CSS/hex value
// (map markers, inline styles, canvas/SVG) should import this instead of
// re-declaring the palette.
export const RISK_TIER_HEX: Record<RiskTier, string> = {
  Critical: "#da1e28",
  High: "#ff832b",
  Medium: "#f1c21b",
  Low: "#24a148",
};

export const RISK_TIER_ORDER: RiskTier[] = ["Critical", "High", "Medium", "Low"];
