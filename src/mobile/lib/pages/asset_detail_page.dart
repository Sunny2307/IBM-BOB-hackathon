import 'package:flutter/material.dart';

import '../api/client.dart';
import '../api/mock_data.dart';
import '../api/types.dart';
import '../state/async_data.dart';
import '../theme/app_theme.dart';
import '../util/formatting.dart';
import '../util/sensor_trend.dart';
import '../widgets/last_updated.dart';
import '../widgets/risk_badge.dart';
import '../widgets/section_label.dart';
import '../widgets/sensor_chart.dart';
import '../widgets/skeleton.dart';
import '../widgets/status_states.dart';

const _pollInterval = Duration(seconds: 30);

/// Port of the web frontend's `AssetDetail` page: header, "Why This Score",
/// four sensor trend charts, and the 7-day weather context.
class AssetDetailPage extends StatefulWidget {
  const AssetDetailPage({super.key, required this.assetId});

  final String assetId;

  @override
  State<AssetDetailPage> createState() => _AssetDetailPageState();
}

class _AssetDetailPageState extends State<AssetDetailPage> {
  late AsyncData<Asset> _asset;
  late AsyncData<RiskBreakdown> _breakdown;

  @override
  void initState() {
    super.initState();
    _createControllers();
  }

  @override
  void didUpdateWidget(AssetDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.assetId != widget.assetId) {
      _disposeControllers();
      _createControllers();
    }
  }

  void _createControllers() {
    _asset = AsyncData<Asset>(
      fetcher: () => api.getAsset(widget.assetId),
      fallback: () => getMockAsset(widget.assetId),
      pollInterval: _pollInterval,
    )..addListener(_onData);
    _breakdown = AsyncData<RiskBreakdown>(
      fetcher: () => api.getRiskBreakdown(widget.assetId),
      fallback: () => getMockRiskBreakdown(widget.assetId),
      pollInterval: _pollInterval,
    )..addListener(_onData);
  }

  void _disposeControllers() {
    _asset
      ..removeListener(_onData)
      ..dispose();
    _breakdown
      ..removeListener(_onData)
      ..dispose();
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  void _onData() {
    if (mounted) setState(() {});
  }

  void _refreshAll() {
    _asset.refetch();
    _breakdown.refetch();
  }

  @override
  Widget build(BuildContext context) {
    final isFallback = _asset.isFallback || _breakdown.isFallback;
    final isLoading = _asset.loading || _breakdown.loading;
    final isRefreshing = _asset.isRefreshing || _breakdown.isRefreshing;
    final fatalError =
        !isLoading && _asset.error != null && _asset.data == null
            ? _asset.error
            : null;

    final assetStamp = _asset.lastUpdatedAt;
    final breakdownStamp = _breakdown.lastUpdatedAt;
    final lastUpdatedAt = assetStamp != null && breakdownStamp != null
        ? (assetStamp.isBefore(breakdownStamp) ? assetStamp : breakdownStamp)
        : (assetStamp ?? breakdownStamp);

    final asset = _asset.data;
    final breakdown = _breakdown.data;

    return RefreshIndicator(
      color: AppColors.blue60,
      backgroundColor: AppColors.white,
      onRefresh: () async => _refreshAll(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 96),
        children: [
          if (asset != null)
            LastUpdated(
              timestamp: lastUpdatedAt,
              isRefreshing: isRefreshing,
              onRefresh: _refreshAll,
            ),
          const SizedBox(height: 16),
          const Hairline(),
          if (isFallback) ...[
            const SizedBox(height: 20),
            FallbackBanner(message: _asset.error ?? _breakdown.error),
          ],
          if (isLoading) ...[
            const SizedBox(height: 24),
            const AssetDetailSkeleton(),
          ],
          if (fatalError != null) ...[
            const SizedBox(height: 24),
            ErrorBlock(message: fatalError, onRetry: _refreshAll),
          ],
          if (!isLoading && fatalError == null && asset == null) ...[
            const SizedBox(height: 24),
            const EmptyBlock(message: 'Asset not found.'),
          ],
          if (asset != null) ...[
            const SizedBox(height: 24),
            _AssetHeader(asset: asset),
            if (breakdown != null) ...[
              const SizedBox(height: 32),
              _WhyThisScore(components: breakdown.components),
              const SizedBox(height: 32),
              const SectionLabel('Sensor Trends'),
              const SizedBox(height: 16),
              SensorChart(
                title: 'Temperature',
                unit: '°C',
                data: breakdown.sensorSeries.temperature,
                badDirection: TrendDirection.up,
              ),
              const SizedBox(height: 16),
              SensorChart(
                title: 'Vibration',
                unit: 'mm/s',
                data: breakdown.sensorSeries.vibration,
                badDirection: TrendDirection.up,
              ),
              const SizedBox(height: 16),
              SensorChart(
                title: 'Partial Discharge',
                unit: 'pC',
                data: breakdown.sensorSeries.partialDischarge,
                badDirection: TrendDirection.up,
              ),
              const SizedBox(height: 16),
              SensorChart(
                title: 'Oil Quality',
                unit: '%',
                data: breakdown.sensorSeries.oilQuality,
                badDirection: TrendDirection.down,
              ),
              const SizedBox(height: 32),
              _WeatherPanel(weather: breakdown.weatherContext),
            ],
          ],
        ],
      ),
    );
  }
}

class _AssetHeader extends StatelessWidget {
  const _AssetHeader({required this.asset});

  final Asset asset;

  @override
  Widget build(BuildContext context) {
    final fields = <(String, String)>[
      ('Installed', '${asset.installYear}'),
      ('Capacity', '${formatScore(asset.capacityMva)} MVA'),
      ('Customers Served', formatCount(asset.customersServed)),
      ('Grid Impact', '${asset.gridImpactSeverity}/10'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel('${asset.type} — ${asset.region}'),
        const SizedBox(height: 8),
        Text(
          asset.name,
          style: AppText.serif(
            size: 30,
            weight: FontWeight.w600,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.only(left: 16),
          decoration: const BoxDecoration(
            border: Border(left: BorderSide(color: AppColors.gray20)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RiskBadge(tier: asset.riskTier, size: BadgeSize.lg),
                  const SizedBox(height: 6),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: formatScore(asset.riskScore),
                          style: AppText.mono(
                            size: 40,
                            weight: FontWeight.w600,
                          ),
                        ),
                        TextSpan(
                          text: '/100',
                          style:
                              AppText.mono(size: 18, color: AppColors.gray60),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 32,
          runSpacing: 16,
          children: [
            for (final field in fields)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SectionLabel(field.$1),
                  const SizedBox(height: 6),
                  Text(
                    field.$2,
                    style: AppText.mono(size: 14, weight: FontWeight.w500),
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 24),
        const Hairline(),
      ],
    );
  }
}

class _WhyThisScore extends StatelessWidget {
  const _WhyThisScore({required this.components});

  final List<RiskComponent> components;

  @override
  Widget build(BuildContext context) {
    if (components.isEmpty) return const SizedBox.shrink();

    final sorted = [...components]
      ..sort((a, b) => b.contribution.compareTo(a.contribution));

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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: const SectionLabel('Why This Score'),
          ),
          const Hairline(),
          for (var i = 0; i < sorted.length; i++) ...[
            if (i > 0) const Hairline(),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 56,
                    child: Text(
                      '+${formatScore(sorted[i].contribution)}',
                      style:
                          AppText.mono(size: 17, weight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sorted[i].factor,
                          style: AppText.serif(
                            size: 15,
                            weight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          sorted[i].explanation,
                          style: AppText.sans(
                            size: 13,
                            color: AppColors.gray70,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _WeatherPanel extends StatelessWidget {
  const _WeatherPanel({required this.weather});

  final WeatherContext weather;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel('7-Day Weather Context — ${weather.region}'),
        const SizedBox(height: 16),
        if (weather.forecast.isEmpty)
          const EmptyBlock(message: 'No forecast data available.')
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.white,
                border: Border.all(color: AppColors.gray20),
              ),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < weather.forecast.length; i++) ...[
                      if (i > 0)
                        const VerticalDivider(
                          width: 1,
                          color: AppColors.gray20,
                        ),
                      _DayCell(day: weather.forecast[i]),
                    ],
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({required this.day});

  final DailyForecast day;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 112,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                shortDate(day.date),
                style: AppText.mono(size: 11, color: AppColors.gray60),
              ),
              const SizedBox(height: 8),
              Text(
                '${formatScore(day.tempHighF)}°F',
                style: AppText.mono(size: 19, weight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                'Wind ${formatScore(day.windSpeedMph)} mph',
                style: AppText.sans(size: 11, color: AppColors.gray70),
              ),
              Text(
                'Precip ${(day.precipProbability * 100).round()}%',
                style: AppText.sans(size: 11, color: AppColors.gray70),
              ),
              if (day.stormWarning) ...[
                const SizedBox(height: 8),
                Text(
                  'STORM WARNING',
                  style: AppText.sans(
                    size: 10,
                    weight: FontWeight.w700,
                    color: AppColors.riskCritical,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
}
