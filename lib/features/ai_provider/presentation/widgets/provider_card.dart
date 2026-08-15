import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/surface_card.dart';
import '../../data/models/ai_provider.dart';
import '../../data/models/rate_limit_snapshot.dart';
import '../extensions.dart';

/// Flat, information-light provider card for the list screen.
class ProviderCard extends StatelessWidget {
  final AIProvider provider;
  final bool isActive;
  final int? modelCount;
  final RateLimitSnapshot? rateLimit;
  final VoidCallback? onTap;
  final VoidCallback? onToggle;

  const ProviderCard({
    super.key,
    required this.provider,
    required this.isActive,
    this.modelCount,
    this.rateLimit,
    this.onTap,
    this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = provider.type.accent(isDark);
    final statusColor = provider.lastStatus.color(isDark);

    return SurfaceCard(
      borderRadius: 18,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      borderColor: isActive ? accent.withValues(alpha: 0.45) : null,
      child: Row(
        children: [
          _ProviderAvatar(icon: provider.type.icon, accent: accent, isDark: isDark),
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
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.darkInk : AppColors.lightInk,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (isActive)
                      _ActiveBadge(accent: accent),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: statusColor),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${provider.lastStatus.label} · ${modelCount ?? provider.cachedModelIds.length} models',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (onToggle != null)
            IconButton(
              onPressed: onToggle,
              icon: Icon(
                isActive ? Icons.star_rounded : Icons.star_border_rounded,
                color: isActive ? accent : (isDark ? AppColors.darkMuted : AppColors.lightMuted),
                size: 22,
              ),
              tooltip: isActive ? 'Active provider' : 'Set as active',
            ),
          Icon(
            Icons.chevron_right_rounded,
            color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
          ),
        ],
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
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: accent.withValues(alpha: 0.12),
        border: Border.all(color: accent.withValues(alpha: 0.4), width: 1),
      ),
      child: Icon(icon, color: accent, size: 20),
    );
  }
}

class _ActiveBadge extends StatelessWidget {
  final Color accent;

  const _ActiveBadge({required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        'ACTIVE',
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.7,
          color: accent,
        ),
      ),
    );
  }
}
