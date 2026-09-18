import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../api/client.dart';
import '../api/mock_data.dart';
import '../api/types.dart';
import '../state/async_data.dart';
import '../theme/app_theme.dart';
import '../util/formatting.dart';
import '../util/risk_colors.dart';
import '../widgets/grid_map.dart';
import '../widgets/last_updated.dart';
import '../widgets/risk_badge.dart';
import '../widgets/section_label.dart';
import '../widgets/skeleton.dart';
import '../widgets/status_states.dart';

const _pollInterval = Duration(seconds: 30);
const _pageSize = 10;

/// Port of the web frontend's `Dashboard` page. Same data, same sections, same
/// filters and pagination — the asset table becomes a stack of rows, which is
/// how the same columns fit on a phone.
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late final AsyncData<List<Asset>> _assets = AsyncData<List<Asset>>(
    fetcher: api.getAssets,
    fallback: () => mockAssets,
    pollInterval: _pollInterval,
  );

  String _regionFilter = 'all';
  String _tierFilter = 'all';
  bool _sortDesc = true;
  int _page = 1;

  @override
  void initState() {
    super.initState();
    _assets.addListener(_onData);
  }

  @override
  void dispose() {
    _assets.removeListener(_onData);
    _assets.dispose();
    super.dispose();
  }

  void _onData() {
    if (mounted) setState(() {});
  }

  List<Asset> get _rows {
    final all = _assets.data ?? const <Asset>[];
    final filtered = all
        .where((a) =>
            (_regionFilter == 'all' || a.region == _regionFilter) &&
            (_tierFilter == 'all' || a.riskTier.label == _tierFilter))
        .toList();
    filtered.sort((a, b) => _sortDesc
        ? b.riskScore.compareTo(a.riskScore)
        : a.riskScore.compareTo(b.riskScore));
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final assets = _assets.data;
    final rows = _rows;
    final pageCount = (rows.length / _pageSize).ceil().clamp(1, 1 << 30);
    final clampedPage = _page.clamp(1, pageCount);
    final pageRows = rows
        .skip((clampedPage - 1) * _pageSize)
        .take(_pageSize)
        .toList(growable: false);

    return RefreshIndicator(
      color: AppColors.blue60,
      backgroundColor: AppColors.white,
      onRefresh: () async => _assets.refetch(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 96),
        children: [
          _pageHeader(),
          if (_assets.isFallback) ...[
            const SizedBox(height: 20),
            FallbackBanner(message: _assets.error),
          ],
          if (_assets.loading) ...[
            const SizedBox(height: 28),
            const DashboardSkeleton(),
          ],
          if (!_assets.loading && _assets.error != null && !_assets.isFallback)
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: ErrorBlock(
                message: _assets.error!,
                onRetry: _assets.refetch,
              ),
            ),
          if (!_assets.loading && assets != null) ...[
            const SizedBox(height: 28),
            _StatTileGrid(stats: _DashboardStats.from(assets)),
            const SizedBox(height: 36),
            const SectionLabel('Geographic Distribution'),
            const SizedBox(height: 12),
            GridMap(
              assets: assets,
              onOpenAsset: (id) => context.push('/assets/$id'),
            ),
            const SizedBox(height: 36),
            _filterBar(assets, rows.length),
            const SizedBox(height: 16),
            if (rows.isEmpty)
              const EmptyBlock(message: 'No assets match the current filters.')
            else ...[
              Container(
                decoration: BoxDecoration(
                  color: AppColors.white,
                  border: Border.all(color: AppColors.gray20),
                ),
                child: Column(
                  children: [
                    for (var i = 0; i < pageRows.length; i++) ...[
                      if (i > 0) const Hairline(),
                      _AssetRow(
                        asset: pageRows[i],
                        onTap: () =>
                            context.push('/assets/${pageRows[i].assetId}'),
                      ),
                    ],
                    const Hairline(),
                    _Pagination(
                      page: clampedPage,
                      pageCount: pageCount,
                      onChange: (p) => setState(() => _page = p),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _pageHeader() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('Live Overview'),
          const SizedBox(height: 8),
          Text(
            'Asset Risk Overview',
            style: AppText.serif(
              size: 32,
              weight: FontWeight.w600,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'All monitored grid assets, ranked by predicted failure risk.',
            style: AppText.serif(
              size: 15,
              color: AppColors.gray70,
              fontStyle: FontStyle.italic,
              height: 1.5,
            ),
          ),
          if (_assets.data != null) ...[
            const SizedBox(height: 16),
            LastUpdated(
              timestamp: _assets.lastUpdatedAt,
              isRefreshing: _assets.isRefreshing,
              onRefresh: _assets.refetch,
            ),
          ],
          const SizedBox(height: 20),
          const Hairline(),
        ],
      );

  Widget _filterBar(List<Asset> assets, int matchCount) {
    final regions = assets.map((a) => a.region).toSet().toList()..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const SectionLabel('All Assets'),
            const Spacer(),
            Text(
              '$matchCount of ${assets.length}',
              style: AppText.mono(size: 11, color: AppColors.gray60),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 20,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _FilterDropdown(
              label: 'Region',
              value: _regionFilter,
              options: ['all', ...regions],
              onChanged: (v) => setState(() {
                _regionFilter = v;
                _page = 1;
              }),
            ),
            _FilterDropdown(
              label: 'Risk Tier',
              value: _tierFilter,
              options: ['all', ...riskTierOrder.map((t) => t.label)],
              onChanged: (v) => setState(() {
                _tierFilter = v;
                _page = 1;
              }),
            ),
            InkWell(
              onTap: () => setState(() {
                _sortDesc = !_sortDesc;
                _page = 1;
              }),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Risk Score',
                    style: AppText.sans(size: 13, color: AppColors.gray70),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _sortDesc ? '↓' : '↑',
                    style: AppText.sans(size: 13, weight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _DashboardStats {
  const _DashboardStats({
    required this.total,
    required this.critical,
    required this.avgScore,
    required this.regionCount,
  });

  factory _DashboardStats.from(List<Asset> assets) {
    final total = assets.length;
    final critical =
        assets.where((a) => a.riskTier == RiskTier.critical).length;
    final avgScore = total == 0
        ? 0
        : (assets.fold<double>(0, (sum, a) => sum + a.riskScore) / total)
            .round();
    final regionCount = assets.map((a) => a.region).toSet().length;
    return _DashboardStats(
      total: total,
      critical: critical,
      avgScore: avgScore,
      regionCount: regionCount,
    );
  }

  final int total;
  final int critical;
  final int avgScore;
  final int regionCount;
}

class _StatTileGrid extends StatelessWidget {
  const _StatTileGrid({required this.stats});

  final _DashboardStats stats;

  @override
  Widget build(BuildContext context) {
    final tiles = <(String, String, Color)>[
      ('Total Assets', '${stats.total}', AppColors.blue60),
      ('Critical Tier', '${stats.critical}', AppColors.riskCritical),
      ('Avg. Risk Score', '${stats.avgScore}', AppColors.riskMedium),
      ('Regions', '${stats.regionCount}', AppColors.riskLow),
    ];

    return Container(
      decoration: const BoxDecoration(
        border: Border.symmetric(
          horizontal: BorderSide(color: AppColors.gray20),
        ),
      ),
      child: Column(
        children: [
          for (var row = 0; row < 2; row++) ...[
            if (row > 0) const Hairline(),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var col = 0; col < 2; col++) ...[
                    if (col > 0)
                      const VerticalDivider(width: 1, color: AppColors.gray20),
                    Expanded(child: _tile(tiles[row * 2 + col])),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _tile((String, String, Color) tile) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            SectionLabel(tile.$1),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: tile.$3, width: 2)),
              ),
              child: Text(
                tile.$2,
                style: AppText.mono(size: 30, weight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
}

/// One row of the web's asset table, re-laid-out for a narrow screen. Every
/// column the table shows is still here: name, type, region, tier, risk score,
/// grid impact, customers.
class _AssetRow extends StatelessWidget {
  const _AssetRow({required this.asset, required this.onTap});

  final Asset asset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    asset.name,
                    style: AppText.serif(size: 16, weight: FontWeight.w500),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${asset.type} · ${asset.region}',
                    style: AppText.sans(size: 13, color: AppColors.gray70),
                  ),
                  const SizedBox(height: 8),
                  RiskBadge(tier: asset.riskTier, size: BadgeSize.sm),
                  const SizedBox(height: 8),
                  Text(
                    'Grid impact ${asset.gridImpactSeverity}/10  ·  '
                    '${formatCount(asset.customersServed)} customers',
                    style: AppText.sans(size: 12, color: AppColors.gray60),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatScore(asset.riskScore),
                  style: AppText.mono(size: 22, weight: FontWeight.w600),
                ),
                Text(
                  'SCORE',
                  style: AppText.kicker(size: 9),
                ),
              ],
            ),
            const Icon(Icons.chevron_right, color: AppColors.gray30),
          ],
        ),
      ),
    );
  }
}

class _Pagination extends StatelessWidget {
  const _Pagination({
    required this.page,
    required this.pageCount,
    required this.onChange,
  });

  final int page;
  final int pageCount;
  final ValueChanged<int> onChange;

  List<int> _pageNumbersAround() {
    const span = 1;
    final start = (page - span).clamp(1, pageCount);
    final end = (page + span).clamp(1, pageCount);
    return [for (var n = start; n <= end; n++) n];
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Text(
            'Page $page of $pageCount',
            style: AppText.mono(size: 11, color: AppColors.gray60),
          ),
          const Spacer(),
          _button('«', page > 1, () => onChange(1)),
          _button('‹', page > 1, () => onChange(page - 1)),
          for (final n in _pageNumbersAround())
            _NumberButton(
              number: n,
              isCurrent: n == page,
              onTap: () => onChange(n),
            ),
          _button('›', page < pageCount, () => onChange(page + 1)),
          _button('»', page < pageCount, () => onChange(pageCount)),
        ],
      ),
    );
  }

  Widget _button(String glyph, bool enabled, VoidCallback onTap) => InkWell(
        onTap: enabled ? onTap : null,
        child: Container(
          width: 30,
          height: 32,
          alignment: Alignment.center,
          child: Text(
            glyph,
            style: AppText.mono(
              size: 14,
              color: enabled ? AppColors.gray60 : AppColors.gray30,
            ),
          ),
        ),
      );
}

class _NumberButton extends StatelessWidget {
  const _NumberButton({
    required this.number,
    required this.isCurrent,
    required this.onTap,
  });

  final int number;
  final bool isCurrent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minWidth: 30),
          height: 32,
          alignment: Alignment.center,
          decoration: isCurrent
              ? const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: AppColors.gray100, width: 2),
                  ),
                )
              : null,
          child: Text(
            '$number',
            style: AppText.mono(
              size: 14,
              weight: isCurrent ? FontWeight.w600 : FontWeight.w400,
              color: isCurrent ? AppColors.gray100 : AppColors.gray60,
            ),
          ),
        ),
      );
}

class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: AppText.sans(size: 13, color: AppColors.gray70),
        ),
        const SizedBox(width: 8),
        Container(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.gray60)),
          ),
          child: DropdownButton<String>(
            value: options.contains(value) ? value : options.first,
            onChanged: (v) => v == null ? null : onChanged(v),
            underline: const SizedBox.shrink(),
            isDense: true,
            borderRadius: BorderRadius.zero,
            dropdownColor: AppColors.white,
            style: AppText.sans(size: 13),
            items: [
              for (final option in options)
                DropdownMenuItem(
                  value: option,
                  child: Text(option == 'all' ? 'All' : option),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
