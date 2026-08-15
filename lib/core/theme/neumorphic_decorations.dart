import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Defines the shape and light depth behavior of Neomorphic elements.
enum NeumorphicShape {
  flat,
  embossed, // Raised / convex
  debossed, // Sunken / concave
  accent,   // Primary-tinted elevated
}

class NeumorphicDecorations {
  NeumorphicDecorations._();

  /// Calculates dual soft shadows for an elevated (embossed) Neomorphic container.
  static List<BoxShadow> embossedShadows({
    required bool isDark,
    double depth = 4.0,
    double spread = 0.0,
    double intensity = 1.0,
  }) {
    if (isDark) {
      return [
        // Top-left soft highlight
        BoxShadow(
          color: const Color(0xFF2A2E36).withValues(alpha: 0.7 * intensity),
          offset: Offset(-depth, -depth),
          blurRadius: depth * 2.2,
          spreadRadius: spread,
        ),
        // Bottom-right deep ambient shadow
        BoxShadow(
          color: const Color(0xFF07080B).withValues(alpha: 0.85 * intensity),
          offset: Offset(depth, depth),
          blurRadius: depth * 2.2,
          spreadRadius: spread,
        ),
      ];
    } else {
      return [
        // Top-left crisp soft white light reflection
        BoxShadow(
          color: Colors.white.withValues(alpha: 0.95 * intensity),
          offset: Offset(-depth, -depth),
          blurRadius: depth * 2.0,
          spreadRadius: spread,
        ),
        // Bottom-right cool shadow
        BoxShadow(
          color: const Color(0xFFC9CDD4).withValues(alpha: 0.6 * intensity),
          offset: Offset(depth, depth),
          blurRadius: depth * 2.0,
          spreadRadius: spread,
        ),
      ];
    }
  }

  /// Calculates inner/sunken look shadows for debossed (pressed) states.
  static List<BoxShadow> debossedShadows({
    required bool isDark,
    double depth = 3.0,
  }) {
    if (isDark) {
      return [
        BoxShadow(
          color: const Color(0xFF090A0D).withValues(alpha: 0.6),
          offset: Offset(-depth * 0.7, -depth * 0.7),
          blurRadius: depth * 1.5,
        ),
        BoxShadow(
          color: const Color(0xFF2C3038).withValues(alpha: 0.4),
          offset: Offset(depth * 0.7, depth * 0.7),
          blurRadius: depth * 1.5,
        ),
      ];
    } else {
      return [
        BoxShadow(
          color: const Color(0xFFC9CDD4).withValues(alpha: 0.7),
          offset: Offset(-depth * 0.7, -depth * 0.7),
          blurRadius: depth * 1.5,
        ),
        BoxShadow(
          color: Colors.white.withValues(alpha: 0.8),
          offset: Offset(depth * 0.7, depth * 0.7),
          blurRadius: depth * 1.5,
        ),
      ];
    }
  }

  /// Generates a subtle bevel gradient for realistic 3D surface curvature.
  static Gradient? surfaceGradient({
    required bool isDark,
    required NeumorphicShape shape,
    Color? customBaseColor,
  }) {
    switch (shape) {

      case NeumorphicShape.embossed:
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  const Color(0xFF262A32),
                  const Color(0xFF1C2026),
                ]
              : [
                  const Color(0xFFFFFFFF),
                  const Color(0xFFF1F2F4),
                ],
        );
      case NeumorphicShape.debossed:
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  const Color(0xFF14171C),
                  const Color(0xFF1D2128),
                ]
              : [
                  const Color(0xFFE0E2E7),
                  const Color(0xFFF6F7F9),
                ],
        );
      case NeumorphicShape.accent:
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  AppColors.darkPrimary,
                  AppColors.primary,
                ]
              : [
                  AppColors.lightPrimary,
                  const Color(0xFF3A33B8),
                ],
        );
      case NeumorphicShape.flat:
        return null;
    }
  }

  /// Full BoxDecoration generator for clean reuse.
  static BoxDecoration boxDecoration({
    required BuildContext context,
    NeumorphicShape shape = NeumorphicShape.embossed,
    double borderRadius = 16.0,
    double depth = 4.0,
    BorderRadius? customBorderRadius,
    Color? color,
    Border? border,
    bool isCircle = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final r = customBorderRadius ?? (isCircle ? null : BorderRadius.circular(borderRadius));

    final baseColor = color ??
        (shape == NeumorphicShape.accent
            ? (isDark ? AppColors.darkPrimary : AppColors.lightPrimary)
            : (isDark ? AppColors.darkCard : AppColors.lightPaper));

    List<BoxShadow>? shadows;
    if (shape == NeumorphicShape.embossed || shape == NeumorphicShape.accent) {
      shadows = embossedShadows(isDark: isDark, depth: depth);
    } else if (shape == NeumorphicShape.debossed) {
      shadows = debossedShadows(isDark: isDark, depth: depth);
    }

    return BoxDecoration(
      shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
      borderRadius: isCircle ? null : r,
      color: baseColor,
      gradient: surfaceGradient(
        isDark: isDark,
        shape: shape,
        customBaseColor: color,
      ),
      boxShadow: shadows,
      border: border ??
          Border.all(
            color: isDark
                ? AppColors.darkBorder
                : Colors.white.withValues(alpha: 0.5),
            width: 0.8,
          ),
    );
  }
}
