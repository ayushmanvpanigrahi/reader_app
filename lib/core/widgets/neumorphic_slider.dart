import 'package:flutter/material.dart';
import '../constants/app_colors.dart';


/// A sleek Neomorphic slider with debossed track and elevated glowing thumb.
class NeumorphicSlider extends StatelessWidget {
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeEnd;
  final int? divisions;
  final Color? activeColor;
  final double trackHeight;

  const NeumorphicSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0.0,
    this.max = 1.0,
    this.onChangeEnd,
    this.divisions,
    this.activeColor,
    this.trackHeight = 8.0,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = activeColor ??
        (isDark ? AppColors.darkPrimary : AppColors.lightPrimary);

    return SliderTheme(
      data: SliderThemeData(
        trackHeight: trackHeight,
        activeTrackColor: primaryColor,
        inactiveTrackColor: isDark
            ? const Color(0xFF191614)
            : const Color(0xFFDFD9D1),
        thumbColor: isDark ? AppColors.darkCard : AppColors.lightPaper,
        overlayColor: primaryColor.withValues(alpha: 0.15),
        thumbShape: _NeumorphicThumbShape(isDark: isDark, primaryColor: primaryColor),
        trackShape: const _NeumorphicTrackShape(),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
      ),
      child: Slider(
        value: value.clamp(min, max),
        min: min,
        max: max,
        divisions: divisions,
        onChanged: onChanged,
        onChangeEnd: onChangeEnd,
      ),
    );
  }
}

class _NeumorphicThumbShape extends SliderComponentShape {
  final bool isDark;
  final Color primaryColor;

  const _NeumorphicThumbShape({required this.isDark, required this.primaryColor});

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => const Size(22, 22);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final Canvas canvas = context.canvas;

    // Shadow
    final shadowPaint = Paint()
      ..color = isDark
          ? const Color(0xFF0A0908).withValues(alpha: 0.8)
          : const Color(0xFFB5ADA2).withValues(alpha: 0.7)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5);
    canvas.drawCircle(center + const Offset(1.5, 1.5), 10, shadowPaint);

    // Highlight
    final highlightPaint = Paint()
      ..color = isDark
          ? const Color(0xFF4A423B).withValues(alpha: 0.7)
          : Colors.white.withValues(alpha: 0.9)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
    canvas.drawCircle(center + const Offset(-1.5, -1.5), 10, highlightPaint);

    // Main thumb body
    final bodyPaint = Paint()
      ..color = isDark ? const Color(0xFF332D28) : const Color(0xFFFAF7F2)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 9, bodyPaint);

    // Center accent dot
    final dotPaint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 4, dotPaint);
  }
}

class _NeumorphicTrackShape extends RoundedRectSliderTrackShape {
  const _NeumorphicTrackShape();

  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final trackHeight = sliderTheme.trackHeight ?? 6;
    final trackLeft = offset.dx + 12;
    final trackTop = offset.dy + (parentBox.size.height - trackHeight) / 2;
    final trackWidth = parentBox.size.width - 24;
    return Rect.fromLTWH(trackLeft, trackTop, trackWidth, trackHeight);
  }
}
