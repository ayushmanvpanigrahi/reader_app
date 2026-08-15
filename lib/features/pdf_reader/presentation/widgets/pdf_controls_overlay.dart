import 'package:flutter/material.dart';
import 'package:reader_app/core/constants/app_colors.dart';
import 'package:reader_app/core/theme/neumorphic_decorations.dart';
import 'package:reader_app/core/widgets/neumorphic_button.dart';
import 'package:reader_app/features/library/data/models/book_model.dart';
import 'package:reader_app/features/pdf_reader/controllers/pdf_reader_controller.dart';
import 'pdf_page_slider.dart';

class PdfControlsOverlay extends StatelessWidget {
  final BookModel book;
  final PdfReaderState state;
  final bool isBookmarked;
  final VoidCallback onToggleBookmark;
  final VoidCallback onToggleScrollDirection;
  final ValueChanged<PdfReadingMode> onSelectReadingMode;
  final ValueChanged<int> onPageSelected;
  final VoidCallback onBack;

  const PdfControlsOverlay({
    super.key,
    required this.book,
    required this.state,
    required this.isBookmarked,
    required this.onToggleBookmark,
    required this.onToggleScrollDirection,
    required this.onSelectReadingMode,
    required this.onPageSelected,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedOpacity(
      opacity: state.showControls ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOut,
      child: IgnorePointer(
        ignoring: !state.showControls,
        child: Stack(
          children: [
            // Top App Bar HUD
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: NeumorphicDecorations.boxDecoration(
                      context: context,
                      shape: NeumorphicShape.embossed,
                      borderRadius: 24,
                      depth: 4.5,
                      color: isDark ? AppColors.darkCard : AppColors.lightPaper,
                    ),
                    child: Row(
                      children: [
                        NeumorphicButton.icon(
                          icon: Icons.arrow_back_rounded,
                          size: 38,
                          iconSize: 18,
                          onPressed: onBack,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                book.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? AppColors.darkInk : AppColors.lightInk,
                                ),
                              ),
                              Text(
                                book.author,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Reading Mode (Standard / Sepia / Dark)
                        NeumorphicButton.icon(
                          icon: Icons.tune_rounded,
                          size: 38,
                          iconSize: 18,
                          tooltip: 'Color Filter Mode',
                          onPressed: () => _showModeSheet(context),
                        ),
                        const SizedBox(width: 6),
                        // Bookmark Toggle
                        NeumorphicButton.icon(
                          icon: isBookmarked
                              ? Icons.bookmark_rounded
                              : Icons.bookmark_border_rounded,
                          size: 38,
                          iconSize: 18,
                          iconColor: isBookmarked
                              ? (isDark ? AppColors.darkPrimary : AppColors.lightPrimary)
                              : null,
                          isSelected: isBookmarked,
                          tooltip: 'Bookmark Page',
                          onPressed: onToggleBookmark,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Bottom Navigation HUD
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Quick Action Bar
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          NeumorphicButton.icon(
                            icon: state.scrollDirection == Axis.vertical
                                ? Icons.swap_vert_rounded
                                : Icons.swap_horiz_rounded,
                            size: 40,
                            iconSize: 18,
                            tooltip: 'Toggle Scroll Direction',
                            onPressed: onToggleScrollDirection,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Page Scrubber Slider
                      PdfPageSlider(
                        currentPage: state.currentPage,
                        totalPages: state.totalPages,
                        onPageSelected: onPageSelected,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showModeSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.darkStage : AppColors.lightStage,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Reading Color Filter',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.darkInk : AppColors.lightInk,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildModeOption(
                  ctx,
                  label: 'Original',
                  mode: PdfReadingMode.standard,
                  bgColor: Colors.white,
                  textColor: Colors.black87,
                ),
                const SizedBox(width: 12),
                _buildModeOption(
                  ctx,
                  label: 'Warm Sepia',
                  mode: PdfReadingMode.sepia,
                  bgColor: const Color(0xFFF4ECD8),
                  textColor: const Color(0xFF5B4636),
                ),
                const SizedBox(width: 12),
                _buildModeOption(
                  ctx,
                  label: 'Night Invert',
                  mode: PdfReadingMode.darkInverted,
                  bgColor: const Color(0xFF1E1A17),
                  textColor: const Color(0xFFEDE5D8),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeOption(
    BuildContext context, {
    required String label,
    required PdfReadingMode mode,
    required Color bgColor,
    required Color textColor,
  }) {
    final isSelected = state.readingMode == mode;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          onSelectReadingMode(mode);
          Navigator.pop(context);
        },
        child: Container(
          height: 64,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? (isDark ? AppColors.darkPrimary : AppColors.lightPrimary)
                  : Colors.transparent,
              width: 2.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                offset: const Offset(0, 3),
                blurRadius: 6,
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
