import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The web's `.kicker` utility class: an uppercase, wide-tracked section
/// label used instead of heavier headings.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.color = AppColors.gray60});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: AppText.kicker(color: color),
      );
}

/// A 1px hairline rule — the editorial alternative to boxed cards.
class Hairline extends StatelessWidget {
  const Hairline({super.key, this.height = 1});

  final double height;

  @override
  Widget build(BuildContext context) =>
      Container(height: height, color: AppColors.gray20);
}
