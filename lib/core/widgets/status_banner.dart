import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

enum StatusTone { success, error, warning, info, neutral }

/// Flat status banner with icon, title, optional message and optional action.
class StatusBanner extends StatelessWidget {
  final StatusTone tone;
  final String title;
  final String? message;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;
  final bool loading;

  const StatusBanner({
    super.key,
    required this.tone,
    required this.title,
    this.message,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final (color, icon) = switch (tone) {
      StatusTone.success => (
          isDark ? AppColors.darkSuccess : AppColors.lightSuccess,
          Icons.check_circle_rounded,
        ),
      StatusTone.error => (
          isDark ? AppColors.darkDanger : AppColors.lightDanger,
          Icons.error_rounded,
        ),
      StatusTone.warning => (
          isDark ? AppColors.darkWarning : AppColors.lightWarning,
          Icons.warning_amber_rounded,
        ),
      StatusTone.info => (
          isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
          Icons.info_rounded,
        ),
      StatusTone.neutral => (
          isDark ? AppColors.darkMuted : AppColors.lightMuted,
          Icons.help_outline_rounded,
        ),
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.14 : 0.09),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (loading)
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: color,
                ),
              ),
            )
          else
            Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.darkInk : AppColors.lightInk,
                  ),
                ),
                if (message != null && message!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    message!,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
                    ),
                  ),
                ],
                if (actionLabel != null && onAction != null) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: loading ? null : onAction,
                      style: TextButton.styleFrom(
                        foregroundColor: color,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: const Size(0, 32),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: Icon(actionIcon ?? Icons.refresh_rounded, size: 16),
                      label: Text(actionLabel!),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
