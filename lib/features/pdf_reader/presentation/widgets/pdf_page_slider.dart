import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/neumorphic_decorations.dart';
import '../../../../core/widgets/neumorphic_slider.dart';

class PdfPageSlider extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final ValueChanged<int> onPageSelected;

  const PdfPageSlider({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.onPageSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final maxP = totalPages > 1 ? totalPages.toDouble() : 1.0;
    final curP = currentPage.clamp(1, totalPages).toDouble();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: NeumorphicDecorations.boxDecoration(
        context: context,
        shape: NeumorphicShape.embossed,
        borderRadius: 24,
        depth: 4.0,
        color: isDark ? AppColors.darkCard : AppColors.lightPaper,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Page $currentPage of $totalPages',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.darkInk : AppColors.lightInk,
                ),
              ),
              Text(
                '${((currentPage / (totalPages > 0 ? totalPages : 1)) * 100).toInt()}% completed',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          NeumorphicSlider(
            value: curP,
            min: 1.0,
            max: maxP,
            divisions: totalPages > 1 ? totalPages - 1 : null,
            onChanged: (val) {
              onPageSelected(val.round());
            },
          ),
        ],
      ),
    );
  }
}
