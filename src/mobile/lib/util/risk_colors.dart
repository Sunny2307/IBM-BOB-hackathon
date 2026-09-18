import 'package:flutter/material.dart';

import '../api/types.dart';
import '../theme/app_theme.dart';

/// Single source of truth for risk-tier color values, mirroring the web
/// frontend's `src/lib/riskColors.ts` and the `--color-risk-*` tokens in
/// `src/index.css`.
const Map<RiskTier, Color> riskTierColor = {
  RiskTier.critical: AppColors.riskCritical,
  RiskTier.high: AppColors.riskHigh,
  RiskTier.medium: AppColors.riskMedium,
  RiskTier.low: AppColors.riskLow,
};

const Map<RiskTier, Color> riskTierBgColor = {
  RiskTier.critical: AppColors.riskCriticalBg,
  RiskTier.high: AppColors.riskHighBg,
  RiskTier.medium: AppColors.riskMediumBg,
  RiskTier.low: AppColors.riskLowBg,
};

const List<RiskTier> riskTierOrder = [
  RiskTier.critical,
  RiskTier.high,
  RiskTier.medium,
  RiskTier.low,
];

Color colorForTier(RiskTier tier) => riskTierColor[tier] ?? AppColors.riskLow;
