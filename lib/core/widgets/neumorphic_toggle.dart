import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';
import '../theme/neumorphic_decorations.dart';

class NeumorphicToggleItem<T> {
  final T value;
  final String label;
  final IconData? icon;

  const NeumorphicToggleItem({
    required this.value,
    required this.label,
    this.icon,
  });
}

/// A segmented Neomorphic toggle control for filtering and modes.
class NeumorphicToggle<T> extends StatelessWidget {
  final List<NeumorphicToggleItem<T>> items;
  final T selectedValue;
  final ValueChanged<T> onSelected;
  final double height;
  final double borderRadius;
  final EdgeInsetsGeometry? margin;

  const NeumorphicToggle({
    super.key,
    required this.items,
    required this.selectedValue,
    required this.onSelected,
    this.height = 42.0,
    this.borderRadius = 14.0,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: height,
      margin: margin,
      padding: const EdgeInsets.all(4.0),
      decoration: NeumorphicDecorations.boxDecoration(
        context: context,
        shape: NeumorphicShape.debossed,
        borderRadius: borderRadius,
        depth: 2.0,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.max,
        children: items.map((item) {
          final isSelected = item.value == selectedValue;

          return Expanded(
            child: GestureDetector(
              onTap: () {
                if (!isSelected) {
                  HapticFeedback.selectionClick();
                  onSelected(item.value);
                }
              },
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                alignment: Alignment.center,
                decoration: isSelected
                    ? NeumorphicDecorations.boxDecoration(
                        context: context,
                        shape: NeumorphicShape.embossed,
                        borderRadius: borderRadius - 3,
                        depth: 2.5,
                        color: isDark ? AppColors.darkCard : AppColors.lightPaper,
                      )
                    : const BoxDecoration(color: Colors.transparent),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (item.icon != null) ...[
                      Icon(
                        item.icon,
                        size: 16,
                        color: isSelected
                            ? (isDark ? AppColors.darkPrimary : AppColors.lightPrimary)
                            : (isDark ? AppColors.darkMuted : AppColors.lightMuted),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Flexible(
                      child: Text(
                        item.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected
                              ? (isDark ? AppColors.darkInk : AppColors.lightInk)
                              : (isDark ? AppColors.darkMuted : AppColors.lightMuted),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
