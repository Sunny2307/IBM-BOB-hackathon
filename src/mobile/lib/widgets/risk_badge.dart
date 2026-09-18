import 'package:flutter/material.dart';

import '../api/types.dart';
import '../theme/app_theme.dart';
import '../util/risk_colors.dart';

enum BadgeSize { sm, md, lg }

/// A small, precise accent — a colored dot plus label, not a filled chip.
/// Risk-tier color is the only color signal in the UI, so it stays legible
/// as ink-colored text rather than being diluted into a pastel background.
class RiskBadge extends StatelessWidget {
  const RiskBadge({super.key, required this.tier, this.size = BadgeSize.md});

  final RiskTier tier;
  final BadgeSize size;

  double get _textSize => switch (size) {
        BadgeSize.sm => 11,
        BadgeSize.md => 12,
        BadgeSize.lg => 14,
      };

  double get _dotSize => switch (size) {
        BadgeSize.sm => 6,
        BadgeSize.md => 8,
        BadgeSize.lg => 10,
      };

  @override
  Widget build(BuildContext context) {
    final color = colorForTier(tier);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: _dotSize,
          height: _dotSize,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          tier.label.toUpperCase(),
          style: AppText.sans(
            size: _textSize,
            weight: FontWeight.w500,
            color: color,
            letterSpacing: 0.6,
          ),
        ),
      ],
    );
  }
}
