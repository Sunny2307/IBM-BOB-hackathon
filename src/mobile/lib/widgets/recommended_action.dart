import 'package:flutter/material.dart';

import '../api/client.dart';
import '../api/mock_data.dart';
import '../api/types.dart';
import '../state/async_data.dart';
import '../theme/app_theme.dart';
import '../util/formatting.dart';
import 'section_label.dart';

/// Inside this many days, a recommended action reads as urgent. Same threshold
/// the maintenance plan uses, so one screen never calls something urgent while
/// the other does not.
const int urgentWindowDays = 7;

/// This asset's entry in the maintenance plan, plus the region context around
/// it. Returns null when the asset is below the threshold for recommended
/// work — a normal state, not an error.
({MaintenanceItem item, String weatherSummary})? findPlanItem(
  MaintenancePlan? plan,
  String assetId,
) {
  if (plan == null) return null;
  for (final region in plan.regions) {
    for (final item in region.items) {
      if (item.assetId == assetId) {
        return (item: item, weatherSummary: region.weatherSummary);
      }
    }
  }
  return null;
}

/// The asset's recommended maintenance, shown on the asset detail page.
///
/// Without it, tapping an asset in the Maintenance Plan opens a page identical
/// to the one reached from the Dashboard — the recommended action, the
/// deadline and the reasoning all disappear at exactly the moment the operator
/// drilled in to read them.
///
/// The plan is fetched here rather than handed over through navigation, so the
/// section is right however the page was reached: deep link, back button, or a
/// tap from either list.
class RecommendedAction extends StatefulWidget {
  const RecommendedAction({super.key, required this.assetId});

  final String assetId;

  @override
  State<RecommendedAction> createState() => _RecommendedActionState();
}

class _RecommendedActionState extends State<RecommendedAction> {
  late final AsyncData<MaintenancePlan> _plan = AsyncData<MaintenancePlan>(
    fetcher: api.getMaintenancePlan,
    fallback: buildMockMaintenancePlan,
  )..addListener(_onChanged);

  @override
  void dispose() {
    _plan.removeListener(_onChanged);
    _plan.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_plan.loading) return const SizedBox.shrink();

    final found = findPlanItem(_plan.data, widget.assetId);

    if (found == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('Recommended Action'),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: AppColors.white,
              border: Border.all(color: AppColors.gray20),
            ),
            child: Text(
              'No maintenance action is currently recommended for this asset.',
              style: AppText.serif(
                size: 15,
                color: AppColors.gray70,
                fontStyle: FontStyle.italic,
                height: 1.45,
              ),
            ),
          ),
        ],
      );
    }

    final item = found.item;
    final days = daysUntil(item.recommendedByDate);
    final isUrgent = days <= urgentWindowDays;
    final accent = isUrgent ? AppColors.riskCritical : AppColors.gray30;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel('Recommended Action'),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: AppColors.white,
            border: Border(
              top: const BorderSide(color: AppColors.gray20),
              right: const BorderSide(color: AppColors.gray20),
              bottom: const BorderSide(color: AppColors.gray20),
              left: BorderSide(color: accent, width: 2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.recommendedAction,
                      style: AppText.serif(
                        size: 17,
                        weight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.rationale,
                      style: AppText.sans(
                        size: 13,
                        color: AppColors.gray70,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SectionLabel('Due'),
                            const SizedBox(height: 4),
                            Text(
                              item.recommendedByDate,
                              style: AppText.mono(
                                size: 17,
                                weight: FontWeight.w600,
                                color: isUrgent
                                    ? AppColors.riskCritical
                                    : AppColors.gray100,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Text(
                          days >= 0
                              ? '${days}d remaining'
                              : '${days.abs()}d overdue',
                          style: AppText.mono(
                            size: 12,
                            color: isUrgent
                                ? AppColors.riskCritical
                                : AppColors.gray70,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Hairline(),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Text(
                      'priority ${item.priorityScore.round()}',
                      style: AppText.mono(size: 11, color: AppColors.gray60),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        found.weatherSummary,
                        style: AppText.sans(
                          size: 12,
                          color: AppColors.gray70,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
