import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The web's `.skeleton` shimmer utility, as a widget.
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({
    super.key,
    this.width = double.infinity,
    required this.height,
  });

  final double width;
  final double height;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: AppColors.skeletonBase,
            gradient: LinearGradient(
              begin: Alignment(-1 + 3 * t, 0),
              end: Alignment(-0.4 + 3 * t, 0),
              colors: const [
                AppColors.skeletonBase,
                AppColors.skeletonShine,
                AppColors.skeletonBase,
              ],
            ),
          ),
        );
      },
    );
  }
}

class DashboardSkeleton extends StatelessWidget {
  const DashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: List.generate(
              2,
              (i) => Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: i == 0 ? 12 : 0),
                  child: const SkeletonBox(height: 84),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: List.generate(
              2,
              (i) => Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: i == 0 ? 12 : 0),
                  child: const SkeletonBox(height: 84),
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),
          const SkeletonBox(height: 280),
          const SizedBox(height: 28),
          ...List.generate(
            4,
            (_) => const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: SkeletonBox(height: 96),
            ),
          ),
        ],
      );
}

class AssetDetailSkeleton extends StatelessWidget {
  const AssetDetailSkeleton({super.key});

  @override
  Widget build(BuildContext context) => const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonBox(width: 220, height: 34),
          SizedBox(height: 20),
          SkeletonBox(height: 120),
          SizedBox(height: 28),
          SkeletonBox(height: 200),
          SizedBox(height: 16),
          SkeletonBox(height: 200),
        ],
      );
}

class MaintenancePlanSkeleton extends StatelessWidget {
  const MaintenancePlanSkeleton({super.key});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(
          3,
          (_) => const Padding(
            padding: EdgeInsets.only(bottom: 20),
            child: SkeletonBox(height: 190),
          ),
        ),
      );
}
