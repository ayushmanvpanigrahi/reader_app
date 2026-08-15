import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/surface_card.dart';
import '../../data/models/rate_limit_snapshot.dart';
import '../../data/services/rate_limit_parser.dart';

/// Live rate-limit card with two circular gauges (requests / tokens) and a
/// ticking countdown to the next reset window.
class RateLimitRing extends StatefulWidget {
  final RateLimitSnapshot? snapshot;

  const RateLimitRing({super.key, this.snapshot});

  @override
  State<RateLimitRing> createState() => _RateLimitRingState();
}

class _RateLimitRingState extends State<RateLimitRing> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final snapshot = widget.snapshot;

    if (snapshot == null || snapshot.isEmpty) {
      return SurfaceCard(
        borderRadius: 20,
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Icon(
              Icons.speed_rounded,
              color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Make an API call to see live rate limits.',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final countdown = RateLimitHeaderParser.countdown(snapshot);
    final requestColor = _statusColor(snapshot.requestUsagePercent, isDark);
    final tokenColor = _statusColor(snapshot.tokenUsagePercent, isDark);

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
                'Rate Limit Status',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.darkInk : AppColors.lightInk,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.av_timer_rounded,
                    size: 16,
                    color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${snapshot.remainingRequests ?? 0} requests remaining',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'resets in ${RateLimitHeaderParser.formatCountdown(countdown)}',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _RingGauge(
                  label: 'Requests',
                  percent: snapshot.requestUsagePercent,
                  remaining: snapshot.remainingRequests,
                  color: requestColor,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _RingGauge(
                  label: 'Tokens',
                  percent: snapshot.tokenUsagePercent,
                  remaining: snapshot.remainingTokens,
                  color: tokenColor,
                  isDark: isDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _statusColor(double usagePercent, bool isDark) {
    final remaining = 1.0 - usagePercent;
    if (remaining > 0.5) return isDark ? AppColors.darkSuccess : AppColors.lightSuccess;
    if (remaining > 0.2) return isDark ? AppColors.darkWarning : AppColors.lightWarning;
    return isDark ? AppColors.darkDanger : AppColors.lightDanger;
  }
}

class _RingGauge extends StatelessWidget {
  final String label;
  final double percent;
  final int? remaining;
  final Color color;
  final bool isDark;

  const _RingGauge({
    required this.label,
    required this.percent,
    required this.remaining,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final usedPercent = (percent * 100).clamp(0, 100);
    return Column(
      children: [
        SizedBox(
          width: 88,
          height: 88,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 88,
                height: 88,
                child: CircularProgressIndicator(
                  value: percent.clamp(0.0, 1.0),
                  strokeWidth: 9,
                  strokeCap: StrokeCap.round,
                  backgroundColor: isDark ? AppColors.darkInput : AppColors.secondary,
                  valueColor: AlwaysStoppedAnimation(color),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${usedPercent.round()}%',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: isDark ? AppColors.darkInk : AppColors.lightInk,
                    ),
                  ),
                  Text(
                    'used',
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.darkInk : AppColors.lightInk,
          ),
        ),
        Text(
          remaining == null ? 'n/a' : '$remaining left',
          style: TextStyle(
            fontSize: 11,
            color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
          ),
        ),
      ],
    );
  }
}
