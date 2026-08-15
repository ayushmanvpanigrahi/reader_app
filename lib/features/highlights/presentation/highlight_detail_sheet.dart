import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/theme/neumorphic_decorations.dart';
import '../data/highlight_model.dart';

Future<void> showHighlightDetailSheet(BuildContext context, HighlightModel highlight) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => HighlightDetailSheet(highlight: highlight),
  );
}

class HighlightDetailSheet extends StatelessWidget {
  final HighlightModel highlight;

  const HighlightDetailSheet({super.key, required this.highlight});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? AppColors.darkPrimary : AppColors.lightPrimary;
    final explanation = highlight.explanation;

    return SafeArea(
      child: Container(
        height: MediaQuery.of(context).size.height * 0.72,
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkPaper : AppColors.lightPaper,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.highlight_rounded, color: primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        highlight.bookTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: isDark ? AppColors.darkInk : AppColors.lightInk,
                        ),
                      ),
                      Text(
                        'Page ${highlight.pageNumber}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: NeumorphicDecorations.boxDecoration(
                context: context,
                shape: NeumorphicShape.debossed,
                borderRadius: 14,
                depth: 2.5,
              ),
              child: Text(
                '"${highlight.selectedText}"',
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  fontStyle: FontStyle.italic,
                  color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                children: [
                  _Section(icon: Icons.lightbulb_outline_rounded, title: 'Simple meaning',
                      body: explanation.simpleMeaning, accent: primary, isDark: isDark),
                  const SizedBox(height: 12),
                  _Section(icon: Icons.menu_book_outlined, title: 'Why the author wrote it',
                      body: explanation.authorContext,
                      accent: isDark ? AppColors.darkSuccess : AppColors.lightSuccess, isDark: isDark),
                  const SizedBox(height: 12),
                  _Section(icon: Icons.psychology_rounded, title: 'Reflect',
                      body: explanation.reflectionQuestion,
                      accent: isDark ? AppColors.darkWarning : AppColors.lightWarning, isDark: isDark),
                  const SizedBox(height: 12),
                  _Section(icon: Icons.workspace_premium_outlined, title: 'Analogy',
                      body: explanation.analogy,
                      accent: isDark ? AppColors.darkMuted : AppColors.lightMuted, isDark: isDark),
                  const SizedBox(height: 12),
                  _Section(icon: Icons.star_border_rounded, title: 'Takeaway',
                      body: explanation.takeaway, accent: primary, isDark: isDark),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final Color accent;
  final bool isDark;

  const _Section({
    required this.icon,
    required this.title,
    required this.body,
    required this.accent,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: NeumorphicDecorations.boxDecoration(
        context: context,
        shape: NeumorphicShape.embossed,
        borderRadius: 14,
        depth: 2.5,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: accent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: accent),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.5,
                    color: isDark ? AppColors.darkInk : AppColors.lightInk,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
