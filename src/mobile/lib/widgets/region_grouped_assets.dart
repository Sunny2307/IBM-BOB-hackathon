import 'package:flutter/material.dart';

import '../api/types.dart';
import '../theme/app_theme.dart';
import '../util/formatting.dart';
import '../util/risk_colors.dart';
import 'risk_badge.dart';
import 'section_label.dart';

const Map<RiskTier, int> _tierRank = {
  RiskTier.low: 0,
  RiskTier.medium: 1,
  RiskTier.high: 2,
  RiskTier.critical: 3,
};

class RegionGroup {
  const RegionGroup({
    required this.region,
    required this.assets,
    required this.worstTier,
    required this.worstScore,
    required this.criticalCount,
    required this.highCount,
    required this.customers,
  });

  final String region;
  final List<Asset> assets;

  /// Highest tier present — what the region as a whole is judged on.
  final RiskTier worstTier;
  final double worstScore;
  final int criticalCount;
  final int highCount;
  final int customers;
}

/// Buckets assets by region, ordering both the groups and the assets inside
/// them by risk. Pure, so the ordering rule is testable without a widget.
List<RegionGroup> groupAssetsByRegion(List<Asset> assets, {bool sortDesc = true}) {
  final byRegion = <String, List<Asset>>{};
  for (final asset in assets) {
    byRegion.putIfAbsent(asset.region, () => []).add(asset);
  }

  final groups = <RegionGroup>[];
  byRegion.forEach((region, items) {
    final ordered = [...items]..sort(
        (a, b) => sortDesc
            ? b.riskScore.compareTo(a.riskScore)
            : a.riskScore.compareTo(b.riskScore),
      );
    var worst = RiskTier.low;
    for (final asset in ordered) {
      if ((_tierRank[asset.riskTier] ?? 0) > (_tierRank[worst] ?? 0)) {
        worst = asset.riskTier;
      }
    }
    groups.add(
      RegionGroup(
        region: region,
        assets: ordered,
        worstTier: worst,
        worstScore: ordered
            .map((a) => a.riskScore)
            .reduce((a, b) => a > b ? a : b),
        criticalCount:
            ordered.where((a) => a.riskTier == RiskTier.critical).length,
        highCount: ordered.where((a) => a.riskTier == RiskTier.high).length,
        customers: ordered.fold<int>(0, (sum, a) => sum + a.customersServed),
      ),
    );
  });

  // Regions carrying the worst asset come first: the operator's question is
  // "where do I send a crew", and that is a question about regions.
  groups.sort(
    (a, b) => sortDesc
        ? b.worstScore.compareTo(a.worstScore)
        : a.worstScore.compareTo(b.worstScore),
  );
  return groups;
}

/// The asset list as collapsible regions rather than one flat paged list.
///
/// A utility runs tens of assets per region, and on a phone a single ranked
/// list of everything is all scrolling and no structure. Each region collapses
/// to one line carrying what decides whether to open it — worst tier, how many
/// Critical/High, customers exposed — and expands to the assets inside. The
/// worst region starts open so the screen still answers "what is worst now"
/// without a tap.
class RegionGroupedAssets extends StatefulWidget {
  const RegionGroupedAssets({
    super.key,
    required this.assets,
    required this.sortDesc,
    required this.onOpenAsset,
  });

  final List<Asset> assets;
  final bool sortDesc;
  final void Function(String assetId) onOpenAsset;

  @override
  State<RegionGroupedAssets> createState() => _RegionGroupedAssetsState();
}

class _RegionGroupedAssetsState extends State<RegionGroupedAssets> {
  /// Null means "untouched" — fall back to opening the worst region.
  Set<String>? _open;

  bool _isOpen(List<RegionGroup> groups, String region) =>
      _open?.contains(region) ??
      (groups.isNotEmpty && groups.first.region == region);

  void _toggle(List<RegionGroup> groups, String region) {
    setState(() {
      final next = {
        ..._open ?? (groups.isEmpty ? <String>{} : {groups.first.region}),
      };
      if (!next.remove(region)) next.add(region);
      _open = next;
    });
  }

  @override
  Widget build(BuildContext context) {
    final groups =
        groupAssetsByRegion(widget.assets, sortDesc: widget.sortDesc);
    final allOpen = groups.isNotEmpty &&
        groups.every((g) => _isOpen(groups, g.region));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '${groups.length} ${groups.length == 1 ? "region" : "regions"}',
              style: AppText.mono(size: 11, color: AppColors.gray60),
            ),
            const Spacer(),
            InkWell(
              onTap: () => setState(() {
                _open = allOpen
                    ? <String>{}
                    : groups.map((g) => g.region).toSet();
              }),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Text(
                  allOpen ? 'Collapse all' : 'Expand all',
                  style: AppText.sans(size: 12, color: AppColors.blue60),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (final group in groups) ...[
          _RegionCard(
            group: group,
            expanded: _isOpen(groups, group.region),
            onToggle: () => _toggle(groups, group.region),
            onOpenAsset: widget.onOpenAsset,
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _RegionCard extends StatelessWidget {
  const _RegionCard({
    required this.group,
    required this.expanded,
    required this.onToggle,
    required this.onOpenAsset,
  });

  final RegionGroup group;
  final bool expanded;
  final VoidCallback onToggle;
  final void Function(String assetId) onOpenAsset;

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
          InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedRotation(
                    turns: expanded ? 0.25 : 0,
                    duration: const Duration(milliseconds: 150),
                    child: const Icon(
                      Icons.chevron_right,
                      size: 20,
                      color: AppColors.gray60,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group.region,
                          style: AppText.serif(
                            size: 18,
                            weight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 12,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            RiskBadge(
                              tier: group.worstTier,
                              size: BadgeSize.sm,
                            ),
                            Text(
                              '${group.assets.length} '
                              '${group.assets.length == 1 ? "asset" : "assets"}',
                              style: AppText.mono(
                                size: 11,
                                color: AppColors.gray60,
                              ),
                            ),
                            if (group.criticalCount > 0)
                              Text(
                                '${group.criticalCount} critical',
                                style: AppText.sans(
                                  size: 11,
                                  weight: FontWeight.w600,
                                  color: AppColors.riskCritical,
                                ),
                              ),
                            if (group.highCount > 0)
                              Text(
                                '${group.highCount} high',
                                style: AppText.sans(
                                  size: 11,
                                  weight: FontWeight.w600,
                                  color: AppColors.riskHigh,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${formatCount(group.customers)} customers',
                          style: AppText.sans(
                            size: 11,
                            color: AppColors.gray60,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        formatScore(group.worstScore),
                        style: AppText.mono(size: 22, weight: FontWeight.w600),
                      ),
                      Text('TOP', style: AppText.kicker(size: 9)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            const Hairline(),
            for (var i = 0; i < group.assets.length; i++) ...[
              if (i > 0) const Hairline(),
              _AssetRow(
                asset: group.assets[i],
                onTap: () => onOpenAsset(group.assets[i].assetId),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// One asset inside an expanded region. The region column the flat list used
/// to carry is dropped — it is the heading directly above.
class _AssetRow extends StatelessWidget {
  const _AssetRow({required this.asset, required this.onTap});

  final Asset asset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 3,
              height: 38,
              margin: const EdgeInsets.only(right: 12, top: 2),
              color: colorForTier(asset.riskTier),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    asset.name,
                    style: AppText.serif(size: 15, weight: FontWeight.w500),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${asset.type} · impact ${asset.gridImpactSeverity}/10 · '
                    '${formatCount(asset.customersServed)} customers',
                    style: AppText.sans(size: 11, color: AppColors.gray60),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              formatScore(asset.riskScore),
              style: AppText.mono(size: 16, weight: FontWeight.w600),
            ),
            const Icon(Icons.chevron_right, size: 18, color: AppColors.gray30),
          ],
        ),
      ),
    );
  }
}
