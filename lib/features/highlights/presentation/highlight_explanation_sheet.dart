import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/theme/neumorphic_decorations.dart';
import '../controllers/highlights_controller.dart';
import '../data/highlight_model.dart';

Future<void> showHighlightExplanationSheet(
  BuildContext context, {
  required String bookId,
  required String bookTitle,
  required int pageNumber,
  required String selectedText,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => HighlightExplanationSheet(
      bookId: bookId,
      bookTitle: bookTitle,
      pageNumber: pageNumber,
      selectedText: selectedText,
    ),
  );
}

class HighlightExplanationSheet extends ConsumerStatefulWidget {
  final String bookId;
  final String bookTitle;
  final int pageNumber;
  final String selectedText;

  const HighlightExplanationSheet({
    super.key,
    required this.bookId,
    required this.bookTitle,
    required this.pageNumber,
    required this.selectedText,
  });

  @override
  ConsumerState<HighlightExplanationSheet> createState() =>
      _HighlightExplanationSheetState();
}

class _HighlightExplanationSheetState
    extends ConsumerState<HighlightExplanationSheet> {
  HighlightExplanation? _explanation;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _explain();
  }

  Future<void> _explain() async {
    final result = await ref
        .read(highlightsControllerProvider.notifier)
        .explain(
          bookId: widget.bookId,
          bookTitle: widget.bookTitle,
          pageNumber: widget.pageNumber,
          selectedText: widget.selectedText,
        );
    if (!mounted) return;
    if (result == null) {
      final error = ref.read(highlightsControllerProvider).error;
      if (error != null) {
        setState(() => _failed = true);
      }
    } else {
      setState(() => _explanation = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isExplaining = ref.watch(highlightsControllerProvider).isExplaining;

    return SafeArea(
      child: Container(
        height: MediaQuery.of(context).size.height * 0.75,
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
                Icon(
                  Icons.highlight_rounded,
                  color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Highlight Explained',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: isDark ? AppColors.darkInk : AppColors.lightInk,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _QuoteBlock(text: widget.selectedText, isDark: isDark),
            const SizedBox(height: 16),
            Expanded(
              child: isExplaining && _explanation == null
                  ? const _LoadingState()
                  : _failed
                      ? _ErrorState(
                          onRetry: () {
                            setState(() => _failed = false);
                            _explain();
                          },
                        )
                      : _explanation == null
                          ? const _LoadingState()
                          : _ExplanationList(explanation: _explanation!, isDark: isDark),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuoteBlock extends StatelessWidget {
  final String text;
  final bool isDark;

  const _QuoteBlock({required this.text, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: NeumorphicDecorations.boxDecoration(
        context: context,
        shape: NeumorphicShape.debossed,
        borderRadius: 14,
        depth: 2.5,
      ),
      child: Text(
        '"${text.trim()}"',
        maxLines: 4,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 13,
          height: 1.45,
          fontStyle: FontStyle.italic,
          color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
        ),
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            'Reading with AI…',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;

  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 36,
            color: isDark ? AppColors.darkDanger : AppColors.lightDanger,
          ),
          const SizedBox(height: 12),
          Text(
            'Could not explain this highlight.\nMake sure an AI provider is configured.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
            ),
          ),
          const SizedBox(height: 16),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _ExplanationList extends StatelessWidget {
  final HighlightExplanation explanation;
  final bool isDark;

  const _ExplanationList({required this.explanation, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final primary = isDark ? AppColors.darkPrimary : AppColors.lightPrimary;
    return ListView(
      physics: const BouncingScrollPhysics(),
      children: [
        _SectionCard(
          icon: Icons.lightbulb_outline_rounded,
          title: 'Simple meaning',
          body: explanation.simpleMeaning,
          accent: primary,
          isDark: isDark,
        ),
        const SizedBox(height: 12),
        _SectionCard(
          icon: Icons.menu_book_outlined,
          title: 'Why the author wrote it',
          body: explanation.authorContext,
          accent: isDark ? AppColors.darkSuccess : AppColors.lightSuccess,
          isDark: isDark,
        ),
        const SizedBox(height: 12),
        _SectionCard(
          icon: Icons.psychology_rounded,
          title: 'Reflect',
          body: explanation.reflectionQuestion,
          accent: isDark ? AppColors.darkWarning : AppColors.lightWarning,
          isDark: isDark,
        ),
        const SizedBox(height: 12),
        _SectionCard(
          icon: Icons.workspace_premium_outlined,
          title: 'Analogy',
          body: explanation.analogy,
          accent: isDark ? AppColors.darkMuted : AppColors.lightMuted,
          isDark: isDark,
        ),
        const SizedBox(height: 12),
        _SectionCard(
          icon: Icons.star_border_rounded,
          title: 'Takeaway',
          body: explanation.takeaway,
          accent: primary,
          isDark: isDark,
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final Color accent;
  final bool isDark;

  const _SectionCard({
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
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: accent,
                  ),
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
