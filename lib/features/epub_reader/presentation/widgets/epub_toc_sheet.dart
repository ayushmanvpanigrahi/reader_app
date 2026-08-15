import 'package:flutter/material.dart';
import 'package:reader_app/core/constants/app_colors.dart';
import 'package:reader_app/core/theme/neumorphic_decorations.dart';
import 'package:reader_app/core/widgets/neumorphic_card.dart';
import 'package:reader_app/features/epub_reader/controllers/epub_reader_controller.dart';

class EpubTocSheet extends StatelessWidget {
  final List<EpubChapterItem> chapters;
  final String? currentChapterTitle;
  final ValueChanged<EpubChapterItem> onSelectChapter;

  const EpubTocSheet({
    super.key,
    required this.chapters,
    required this.currentChapterTitle,
    required this.onSelectChapter,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.65,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkStage : AppColors.lightStage,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
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
          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Table of Contents',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: isDark ? AppColors.darkInk : AppColors.lightInk,
                ),
              ),
              Text(
                '${chapters.length} Chapters',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          Expanded(
            child: chapters.isEmpty
                ? Center(
                    child: Text(
                      'No table of contents available.',
                      style: TextStyle(
                        color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: chapters.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {

                      final chapter = chapters[index];
                      final isCurrent = chapter.title == currentChapterTitle;

                      return NeumorphicCard(
                        shape: isCurrent
                            ? NeumorphicShape.debossed
                            : NeumorphicShape.embossed,
                        borderRadius: 14,
                        depth: isCurrent ? 2.0 : 3.0,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        onTap: () => onSelectChapter(chapter),
                        child: Row(
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isCurrent
                                    ? (isDark
                                        ? AppColors.darkPrimary
                                        : AppColors.lightPrimary)
                                    : (isDark
                                        ? AppColors.darkCard
                                        : AppColors.lightSecondary),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '${index + 1}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: isCurrent
                                      ? Colors.white
                                      : (isDark
                                          ? AppColors.darkInk
                                          : AppColors.lightInk),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                chapter.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: isCurrent
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: isCurrent
                                      ? (isDark
                                          ? AppColors.darkPrimary
                                          : AppColors.lightPrimary)
                                      : (isDark
                                          ? AppColors.darkInk
                                          : AppColors.lightInk),
                                ),
                              ),
                            ),
                            if (isCurrent)
                              Icon(
                                Icons.check_circle_rounded,
                                size: 18,
                                color: isDark
                                    ? AppColors.darkPrimary
                                    : AppColors.lightPrimary,
                              ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
