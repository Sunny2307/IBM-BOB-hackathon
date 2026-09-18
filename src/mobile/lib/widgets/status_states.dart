import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Port of the web frontend's `src/components/StatusStates.tsx`.

class LoadingBlock extends StatelessWidget {
  const LoadingBlock({super.key, this.label = 'Loading'});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        decoration: const BoxDecoration(
          color: AppColors.white,
          border: Border(
            left: BorderSide(color: AppColors.blue60, width: 2),
          ),
        ),
        child: Row(
          children: [
            const _PulsingDot(color: AppColors.blue60),
            const SizedBox(width: 12),
            Text(
              '$label…',
              style: AppText.sans(size: 14, weight: FontWeight.w500),
            ),
          ],
        ),
      );
}

class EmptyBlock extends StatelessWidget {
  const EmptyBlock({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 48),
        decoration: BoxDecoration(border: Border.all(color: AppColors.gray20)),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: AppText.serif(
            size: 16,
            color: AppColors.gray70,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
}

class ErrorBlock extends StatelessWidget {
  const ErrorBlock({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: const BoxDecoration(
          color: AppColors.white,
          border: Border(
            left: BorderSide(color: AppColors.riskCritical, width: 2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Connection Failed',
              style: AppText.sans(size: 14, weight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              message,
              style: AppText.sans(size: 14, color: AppColors.gray70),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: onRetry,
                style: OutlinedButton.styleFrom(
                  shape: const RoundedRectangleBorder(),
                  side: const BorderSide(color: AppColors.gray30),
                  foregroundColor: AppColors.blue60,
                ),
                child: Text(
                  'Retry',
                  style: AppText.sans(
                    size: 13,
                    weight: FontWeight.w600,
                    color: AppColors.blue60,
                  ),
                ),
              ),
            ],
          ],
        ),
      );
}

/// Unmissable full-width warning strip shown whenever the UI has fallen back
/// to local mock data because the live backend could not be reached. Must
/// never read as "the app is just static" — so this is deliberately loud
/// rather than a small inline note.
class FallbackBanner extends StatelessWidget {
  const FallbackBanner({super.key, this.message});

  final String? message;

  static const _defaultMessage =
      'Backend unreachable — showing cached demo data instead of live grid data.';

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: const BoxDecoration(
          color: AppColors.riskMediumBg,
          border: Border(
            left: BorderSide(color: AppColors.riskMedium, width: 2),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.riskMedium),
              ),
              child: Text(
                '!',
                style: AppText.serif(
                  size: 14,
                  weight: FontWeight.w600,
                  color: AppColors.riskMedium,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'SHOWING CACHED DEMO DATA',
                      style: AppText.sans(
                        size: 13,
                        weight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                    ),
                    TextSpan(
                      text: '  —  ',
                      style: AppText.sans(size: 13, color: AppColors.gray70),
                    ),
                    TextSpan(
                      text: message ?? _defaultMessage,
                      style: AppText.sans(size: 13),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
}

class _PulsingDot extends StatefulWidget {
  const _PulsingDot({required this.color});

  final Color color;

  static const double size = 6;

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: Tween<double>(begin: 0.35, end: 1).animate(_controller),
        child: Container(
          width: _PulsingDot.size,
          height: _PulsingDot.size,
          decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
        ),
      );
}
