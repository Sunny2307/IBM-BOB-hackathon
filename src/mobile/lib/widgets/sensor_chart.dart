import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../api/types.dart';
import '../theme/app_theme.dart';
import '../util/formatting.dart';
import '../util/sensor_trend.dart';

/// Port of the web frontend's `SensorChart` (Recharts area chart). Same
/// degrading/stable heuristic, same ink-red / ink-green line colors, same
/// gradient fill fading to transparent.
class SensorChart extends StatelessWidget {
  const SensorChart({
    super.key,
    required this.title,
    required this.unit,
    required this.data,
    required this.badDirection,
  });

  final String title;
  final String unit;
  final List<SensorReading> data;
  final TrendDirection badDirection;

  @override
  Widget build(BuildContext context) {
    final degrading = isDegrading(data, badDirection);
    final lineColor =
        degrading ? AppColors.riskCritical : AppColors.riskLow;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border.all(color: AppColors.gray20),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: title,
                        style:
                            AppText.serif(size: 16, weight: FontWeight.w600),
                      ),
                      TextSpan(
                        text: ' ($unit)',
                        style:
                            AppText.sans(size: 14, color: AppColors.gray70),
                      ),
                    ],
                  ),
                ),
              ),
              Text(
                degrading ? 'DEGRADING' : 'STABLE',
                style: AppText.sans(
                  size: 12,
                  weight: FontWeight.w600,
                  color: lineColor,
                  letterSpacing: 0.7,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(height: 1, color: AppColors.gray20),
          const SizedBox(height: 16),
          SizedBox(
            height: 170,
            child: data.isEmpty
                ? Center(
                    child: Text(
                      'No sensor data',
                      style: AppText.sans(size: 14, color: AppColors.gray60),
                    ),
                  )
                : LineChart(_chartData(lineColor)),
          ),
        ],
      ),
    );
  }

  LineChartData _chartData(Color lineColor) {
    final spots = <FlSpot>[
      for (var i = 0; i < data.length; i++)
        FlSpot(i.toDouble(), data[i].value),
    ];

    final values = data.map((r) => r.value).toList();
    final minValue = values.reduce((a, b) => a < b ? a : b);
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final pad = ((maxValue - minValue).abs() * 0.15).clamp(0.5, double.infinity);

    // Roughly 4 x-axis labels regardless of series length.
    final xInterval = (data.length / 4).ceilToDouble().clamp(1, 1000).toDouble();

    return LineChartData(
      minY: minValue - pad,
      maxY: maxValue + pad,
      minX: 0,
      maxX: (data.length - 1).toDouble(),
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        getDrawingHorizontalLine: (_) => const FlLine(
          color: AppColors.gray20,
          strokeWidth: 1,
          dashArray: [2, 4],
        ),
      ),
      borderData: FlBorderData(
        show: true,
        border: const Border(
          bottom: BorderSide(color: AppColors.gray30),
        ),
      ),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 42,
            getTitlesWidget: (value, meta) => Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Text(
                '${(value * 10).round() / 10}',
                textAlign: TextAlign.right,
                style: AppText.mono(size: 10, color: AppColors.gray70),
              ),
            ),
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 24,
            interval: xInterval,
            getTitlesWidget: (value, meta) {
              final index = value.round();
              if (index < 0 || index >= data.length) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  shortDate(data[index].date),
                  style: AppText.mono(size: 10, color: AppColors.gray70),
                ),
              );
            },
          ),
        ),
      ),
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipColor: (_) => AppColors.gray100,
          tooltipBorderRadius: BorderRadius.zero,
          getTooltipItems: (touchedSpots) => touchedSpots.map((spot) {
            final index = spot.x.round();
            final date =
                index >= 0 && index < data.length ? data[index].date : '';
            return LineTooltipItem(
              '${shortDate(date)}\n',
              AppText.sans(size: 11, color: AppColors.gray30),
              children: [
                TextSpan(
                  text: '${spot.y}$unit',
                  style: AppText.sans(
                    size: 12,
                    weight: FontWeight.w600,
                    color: AppColors.white,
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          curveSmoothness: 0.25,
          preventCurveOverShooting: true,
          color: lineColor,
          barWidth: 2,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                lineColor.withValues(alpha: 0.2),
                lineColor.withValues(alpha: 0),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
