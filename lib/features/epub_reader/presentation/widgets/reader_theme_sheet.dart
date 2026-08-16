import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/neumorphic_button.dart';
import '../../../../core/widgets/neumorphic_slider.dart';

class ReaderThemeSheet extends StatelessWidget {
  final double fontSize;
  final String themePreset;
  final ValueChanged<double> onFontSizeChanged;
  final ValueChanged<String> onThemePresetChanged;

  const ReaderThemeSheet({
    super.key,
    required this.fontSize,
    required this.themePreset,
    required this.onFontSizeChanged,
    required this.onThemePresetChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkStage : AppColors.lightStage,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),

          Text(
            'Typography & Theme',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: isDark ? AppColors.darkInk : AppColors.lightInk,
            ),
          ),
          const SizedBox(height: 20),

          // Font Size Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Font Size',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.darkInk : AppColors.lightInk,
                ),
              ),
              Text(
                '${fontSize.toInt()} pt',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          Row(
            children: [
              NeumorphicButton.icon(
                icon: Icons.text_decrease_rounded,
                size: 38,
                iconSize: 18,
                onPressed: () => onFontSizeChanged(fontSize - 2),
              ),
              Expanded(
                child: NeumorphicSlider(
                  value: fontSize,
                  min: 12.0,
                  max: 32.0,
                  divisions: 10,
                  onChanged: onFontSizeChanged,
                ),
              ),
              NeumorphicButton.icon(
                icon: Icons.text_increase_rounded,
                size: 38,
                iconSize: 18,
                onPressed: () => onFontSizeChanged(fontSize + 2),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Reading Tone Presets
          Text(
            'Reading Tone',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.darkInk : AppColors.lightInk,
            ),
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              _buildPresetCard(
                context,
                presetId: 'paper',
                label: 'Original',
                bgColor: const Color(0xFFFDFAF4),
                textColor: const Color(0xFF181310),
              ),
              const SizedBox(width: 10),
              _buildPresetCard(
                context,
                presetId: 'sepia',
                label: 'Warm Sepia',
                bgColor: const Color(0xFFF4ECD8),
                textColor: const Color(0xFF533F2D),
              ),
              const SizedBox(width: 10),
              _buildPresetCard(
                context,
                presetId: 'dark',
                label: 'Night Charcoal',
                bgColor: const Color(0xFF1A1A1A),
                textColor: const Color(0xFFE2E2E2),
              ),
              const SizedBox(width: 10),
              _buildPresetCard(
                context,
                presetId: 'oled',
                label: 'E-Ink OLED',
                bgColor: const Color(0xFF000000),
                textColor: const Color(0xFFFFFFFF),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPresetCard(
    BuildContext context, {
    required String presetId,
    required String label,
    required Color bgColor,
    required Color textColor,
  }) {
    final isSelected = themePreset == presetId;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: GestureDetector(
        onTap: () => onThemePresetChanged(presetId),
        child: Container(
          height: 60,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? (isDark ? AppColors.darkPrimary : AppColors.lightPrimary)
                  : Colors.transparent,
              width: 2.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                offset: const Offset(0, 3),
                blurRadius: 5,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}
