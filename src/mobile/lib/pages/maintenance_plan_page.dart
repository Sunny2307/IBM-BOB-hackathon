import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../api/client.dart';
import '../api/mock_data.dart';
import '../api/types.dart';
import '../state/async_data.dart';
import '../theme/app_theme.dart';
import '../util/formatting.dart';
import '../widgets/recommended_action.dart' show urgentWindowDays;
import '../widgets/risk_badge.dart';
import '../widgets/section_label.dart';
import '../widgets/skeleton.dart';
import '../widgets/status_states.dart';

/// Port of the web frontend's `MaintenancePlan` page: region cards with a
/// weather summary and the prioritized action list underneath.
class MaintenancePlanPage extends StatefulWidget {
  const MaintenancePlanPage({super.key});

  @override
  State<MaintenancePlanPage> createState() => _MaintenancePlanPageState();
}

class _MaintenancePlanPageState extends State<MaintenancePlanPage> {
  late final AsyncData<MaintenancePlan> _plan = AsyncData<MaintenancePlan>(
    fetcher: api.getMaintenancePlan,
    fallback: buildMockMaintenancePlan,
  );

  @override
  void initState() {
    super.initState();
    _plan.addListener(_onData);
  }

  @override
  void dispose() {
    _plan.removeListener(_onData);
    _plan.dispose();
    super.dispose();
  }

  void _onData() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final plan = _plan.data;

    return RefreshIndicator(
      color: AppColors.blue60,
      backgroundColor: AppColors.white,
      onRefresh: () async => _plan.refetch(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 96),
        children: [
          const SectionLabel('Prioritized Actions'),
          const SizedBox(height: 8),
          Text(
            'Maintenance Plan',
            style: AppText.serif(
              size: 32,
              weight: FontWeight.w600,
              letterSpacing: -0.5,
            ),
          ),
          if (plan != null) ...[
            const SizedBox(height: 10),
            Text(
              'Generated ${formatGeneratedAt(plan.generatedAt)}',
              style: AppText.mono(size: 11, color: AppColors.gray60),
            ),
          ],
          const SizedBox(height: 20),
          const Hairline(),
          if (_plan.isFallback) ...[
            const SizedBox(height: 20),
            FallbackBanner(message: _plan.error),
          ],
          if (_plan.loading) ...[
            const SizedBox(height: 24),
            const MaintenancePlanSkeleton(),
          ],
          if (!_plan.loading && _plan.error != null && !_plan.isFallback) ...[
            const SizedBox(height: 24),
            ErrorBlock(message: _plan.error!, onRetry: _plan.refetch),
          ],
          if (!_plan.loading && plan != null && plan.regions.isEmpty) ...[
            const SizedBox(height: 24),
            const EmptyBlock(
              message: 'No maintenance actions recommended.',
            ),
          ],
          if (plan != null && plan.regions.isNotEmpty)
            for (final region in plan.regions) ...[
              const SizedBox(height: 28),
              _RegionCard(region: region),
            ],
        ],
      ),
    );
  }
}

class _RegionCard extends StatelessWidget {
  const _RegionCard({required this.region});

  final RegionPlan region;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border.all(color: AppColors.gray20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            color: AppColors.gray10,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  region.region,
                  style: AppText.serif(size: 22, weight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  region.weatherSummary,
                  style: AppText.sans(
                    size: 13,
                    color: AppColors.gray70,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          const Hairline(),
          if (region.items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: EmptyBlock(
                message: 'No actions recommended for this region.',
              ),
            )
          else
            for (var i = 0; i < region.items.length; i++) ...[
              if (i > 0) const Hairline(),
              _MaintenanceRow(item: region.items[i]),
            ],
        ],
      ),
    );
  }
}

class _MaintenanceRow extends StatelessWidget {
  const _MaintenanceRow({required this.item});

  final MaintenanceItem item;

  @override
  Widget build(BuildContext context) {
    final days = daysUntil(item.recommendedByDate);
    final isUrgent = days <= urgentWindowDays;
    final dueColor = isUrgent ? AppColors.riskCritical : AppColors.gray100;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              InkWell(
                onTap: () => context.push('/assets/${item.assetId}'),
                child: Text(
                  item.assetName,
                  style: AppText.serif(
                    size: 17,
                    weight: FontWeight.w600,
                    color: AppColors.blue70,
                  ),
                ),
              ),
              RiskBadge(tier: item.riskTier, size: BadgeSize.sm),
              Text(
                'score ${formatScore(item.riskScore)}',
                style: AppText.mono(size: 11, color: AppColors.gray60),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            item.recommendedAction,
            style: AppText.sans(size: 14, weight: FontWeight.w500, height: 1.4),
          ),
          const SizedBox(height: 6),
          Text(
            item.rationale,
            style: AppText.sans(
              size: 13,
              color: AppColors.gray70,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.only(left: 12),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: isUrgent ? AppColors.riskCritical : AppColors.gray30,
                  width: 2,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'By ${item.recommendedByDate}',
                  style: AppText.sans(
                    size: 13,
                    weight: FontWeight.w600,
                    color: dueColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  days >= 0 ? '${days}d remaining' : 'overdue',
                  style: AppText.mono(size: 11, color: AppColors.gray70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
