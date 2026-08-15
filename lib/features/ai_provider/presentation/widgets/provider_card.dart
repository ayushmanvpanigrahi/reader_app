import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/neumorphic_decorations.dart';
import '../../../../core/widgets/neumorphic_card.dart';
import '../../data/models/ai_provider.dart';
import '../../data/models/rate_limit_snapshot.dart';
import '../extensions.dart';

class ProviderCard extends StatelessWidget {
  final AIProvider provider;
  final bool isActive;
  final int? modelCount;
  final RateLimitSnapshot? rateLimit;
  final VoidCallback? onTap;
  final VoidCallback? onToggle;
  final VoidCallback? onDelete;

  const ProviderCard({
    super.key,
    required this.provider,
    required this.isActive,
    this.modelCount,
    this.rateLimit,
    this.onTap,
    this.onToggle,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = provider.type.accent(isDark);
    final statusColor = provider.lastStatus.color(isDark);

    return GestureDetector(
      onLongPress: onToggle,
      child: NeumorphicCard(
        borderRadius: 20,
        depth: isActive ? 5.5 : 3.5,
        padding: EdgeInsets.zero,
        shape: isActive ? NeumorphicShape.accent : NeumorphicShape.embossed,
        onTap: onTap,
        child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _ProviderAvatar(
                  icon: provider.type.icon,
                  accent: accent,
                  isDark: isDark,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              provider.displayName,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: isDark ? AppColors.darkInk : AppColors.lightInk,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (isActive)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'ACTIVE',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                  color: accent,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        provider.type.label,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                _StatusPill(statusColor: statusColor, label: provider.lastStatus.label, isDark: isDark),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _StatChip(
                  icon: Icons.token_rounded,
                  label: '${modelCount ?? provider.cachedModelIds.length} models',
                  isDark: isDark,
                ),
                const SizedBox(width: 10),
                _StatChip(
                  icon: Icons.av_timer_rounded,
                  label: rateLimit == null
                      ? 'No rate data'
                      : '${rateLimit!.requestUsagePercent * 100 >= 80 ? '⚠ ' : ''}${rateLimit!.remainingRequests ?? 0} req left',
                  isDark: isDark,
                  warn: rateLimit != null && rateLimit!.requestUsagePercent >= 0.8,
                ),
                const Spacer(),
                IconButton(
                  onPressed: onToggle,
                  icon: Icon(
                    isActive ? Icons.star_rounded : Icons.star_border_rounded,
                    color: accent,
                    size: 24,
                  ),
                  tooltip: isActive ? 'Deactivate' : 'Set as active',
                ),
                if (onDelete != null)
                  IconButton(
                    onPressed: onDelete,
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
                      size: 22,
                    ),
                    tooltip: 'Delete provider',
                  ),
              ],
            ),
          ],
        ),
        ),
      ),
    );
  }
}

class _ProviderAvatar extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final bool isDark;

  const _ProviderAvatar({required this.icon, required this.accent, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: accent.withValues(alpha: 0.12),
        border: Border.all(color: accent.withValues(alpha: 0.4), width: 1),
      ),
      child: Icon(icon, color: accent, size: 22),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final Color statusColor;
  final String label;
  final bool isDark;

  const _StatusPill({required this.statusColor, required this.label, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(shape: BoxShape.circle, color: statusColor),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: statusColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDark;
  final bool warn;

  const _StatChip({required this.icon, required this.label, required this.isDark, this.warn = false});

  @override
  Widget build(BuildContext context) {
    final color = warn
        ? (isDark ? AppColors.darkWarning : AppColors.lightWarning)
        : (isDark ? AppColors.darkMuted : AppColors.lightMuted);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: (isDark ? AppColors.darkInput : AppColors.secondary).withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
