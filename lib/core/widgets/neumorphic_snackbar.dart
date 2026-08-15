import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../theme/neumorphic_decorations.dart';

enum NeoSnackbarType { success, error, info, warning }

class NeumorphicSnackbar {
  NeumorphicSnackbar._();

  static void show(
    BuildContext context, {
    required String message,
    NeoSnackbarType type = NeoSnackbarType.info,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = switch (type) {
      NeoSnackbarType.success =>
        isDark ? AppColors.darkSuccess : AppColors.lightSuccess,
      NeoSnackbarType.error => isDark ? AppColors.darkDanger : AppColors.lightDanger,
      NeoSnackbarType.warning => isDark ? AppColors.darkWarning : AppColors.lightWarning,
      NeoSnackbarType.info => isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
    };
    final icon = switch (type) {
      NeoSnackbarType.success => Icons.check_circle_rounded,
      NeoSnackbarType.error => Icons.error_rounded,
      NeoSnackbarType.warning => Icons.warning_amber_rounded,
      NeoSnackbarType.info => Icons.info_rounded,
    };

    final overlay = Overlay.of(context);
    final entry = OverlayEntry(
      builder: (context) {
        return Positioned(
          left: 20,
          right: 20,
          bottom: MediaQuery.of(context).viewPadding.bottom + 90,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            builder: (context, t, child) => Opacity(
              opacity: t,
              child: Transform.translate(
                offset: Offset(0, (1 - t) * 24),
                child: child,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: NeumorphicDecorations.boxDecoration(
                  context: context,
                  shape: NeumorphicShape.embossed,
                  borderRadius: 16,
                ),
                child: Row(
                  children: [
                    Icon(icon, color: color, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        message,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.darkInk : AppColors.lightInk,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    overlay.insert(entry);
    Future.delayed(const Duration(milliseconds: 3000), () {
      if (entry.mounted) entry.remove();
    });
  }
}
