import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/surface_card.dart';
import '../../data/models/daily_usage_bucket.dart';

/// Compact neomorphic bar chart of per-day token usage over the last N days.
class UsageSparkline extends StatelessWidget {
  final List<DailyUsageBucket> buckets;
  final int days;

  const UsageSparkline({super.key, required this.buckets, this.days = 14});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final byDay = {for (final b in buckets) b.day: b};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final values = <double>[];
    for (var i = days - 1; i >= 0; i--) {
      final day = today.subtract(Duration(days: i));
      values.add(byDay[day]?.tokens.toDouble() ?? 0);
    }

    final maxVal = values.fold<double>(0, (a, b) => a > b ? a : b);
    final primary = isDark ? AppColors.darkPrimary : AppColors.lightPrimary;

    return SurfaceCard(
      borderRadius: 20,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Usage · last $days days',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.darkInk : AppColors.lightInk,
                ),
              ),
              Text(
                _totalTokens(values),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 120,
            child: values.every((v) => v == 0)
                ? Center(
                    child: Text(
                      'No usage recorded yet',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
                      ),
                    ),
                  )
                : BarChart(
                    BarChartData(
                      maxY: maxVal == 0 ? 1 : maxVal * 1.2,
                      alignment: BarChartAlignment.spaceAround,
                      barTouchData: BarTouchData(enabled: false),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: maxVal == 0 ? 1 : (maxVal * 1.2 / 3),
                        getDrawingHorizontalLine: (_) => FlLine(
                          color: (isDark ? AppColors.darkBorder : AppColors.border)
                              .withValues(alpha: 0.6),
                          strokeWidth: 1,
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        leftTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 24,
                            getTitlesWidget: (value, meta) {
                              final idx = value.toInt();
                              if (idx < 0 || idx >= values.length) return const SizedBox.shrink();
                              final day = today.subtract(Duration(days: days - 1 - idx));
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  '${day.day}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      barGroups: [
                        for (var i = 0; i < values.length; i++)
                          BarChartGroupData(
                            x: i,
                            barRods: [
                              BarChartRodData(
                                toY: values[i],
                                width: 6,
                                borderRadius: BorderRadius.circular(3),
                                color: i == values.length - 1 ? primary : primary.withValues(alpha: 0.55),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  String _totalTokens(List<double> values) {
    final total = values.reduce((a, b) => a + b).toInt();
    if (total >= 1000000) return '${(total / 1000000).toStringAsFixed(1)}M tokens';
    if (total >= 1000) return '${(total / 1000).toStringAsFixed(1)}k tokens';
    return '$total tokens';
  }
}
