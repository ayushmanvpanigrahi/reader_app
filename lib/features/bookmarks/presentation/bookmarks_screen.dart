import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/neumorphic_decorations.dart';
import '../../../core/widgets/neumorphic_card.dart';
import '../../epub_reader/presentation/epub_reader_screen.dart';
import '../../highlights/controllers/highlights_controller.dart';
import '../../highlights/data/highlight_model.dart';
import '../../highlights/presentation/highlight_detail_sheet.dart';
import '../../library/controllers/library_controller.dart';
import '../../library/data/models/book_model.dart';
import '../../pdf_reader/presentation/pdf_reader_screen.dart';
import '../controllers/bookmarks_controller.dart';
import '../data/models/bookmark_model.dart';

class BookmarksScreen extends ConsumerStatefulWidget {
  const BookmarksScreen({super.key});

  @override
  ConsumerState<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends ConsumerState<BookmarksScreen> {
  int _tab = 0;

  void _openBookmark(BuildContext context, WidgetRef ref, BookmarkModel bookmark) {
    final libraryState = ref.read(libraryControllerProvider);
    final book = libraryState.books.firstWhere(
      (b) => b.id == bookmark.bookId,
      orElse: () => BookModel(
        id: bookmark.bookId,
        title: bookmark.bookTitle,
        author: 'Unknown',
        filePath: '',
        format: bookmark.format,
        currentPage: bookmark.pageNumber,
        addedAt: DateTime.now(),
      ),
    );

    if (bookmark.format == BookFormat.pdf) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PdfReaderScreen(
            book: book.copyWith(currentPage: bookmark.pageNumber),
          ),
        ),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => EpubReaderScreen(
            book: book.copyWith(currentPage: bookmark.pageNumber),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(bookmarksControllerProvider);
    final highlights = ref.watch(highlightsControllerProvider).highlights;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _tab == 0 ? 'Bookmarks' : 'Highlights',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: isDark ? AppColors.darkInk : AppColors.lightInk,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _tab == 0
                        ? '${state.bookmarks.length} Saved Passages & Pages'
                        : '${highlights.length} AI-Explained Highlights',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _SegmentedToggle(
                    value: _tab,
                    isDark: isDark,
                    onChanged: (index) => setState(() => _tab = index),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _tab == 0
                  ? _BookmarksList(
                      bookmarks: state.bookmarks,
                      controller: ref.read(bookmarksControllerProvider.notifier),
                      isDark: isDark,
                      onOpen: (bookmark) => _openBookmark(context, ref, bookmark),
                    )
                  : _HighlightsList(
                      highlights: highlights,
                      isDark: isDark,
                      onDelete: (id) =>
                          ref.read(highlightsControllerProvider.notifier).remove(id),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SegmentedToggle extends StatelessWidget {
  final int value;
  final bool isDark;
  final ValueChanged<int> onChanged;

  const _SegmentedToggle({
    required this.value,
    required this.isDark,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: NeumorphicDecorations.boxDecoration(
        context: context,
        shape: NeumorphicShape.debossed,
        borderRadius: 14,
        depth: 2,
      ),
      child: Row(
        children: [
          _segment(0, Icons.bookmark_outline_rounded, 'Bookmarks'),
          _segment(1, Icons.highlight_rounded, 'Highlights'),
        ],
      ),
    );
  }

  Widget _segment(int index, IconData icon, String label) {
    final isSelected = value == index;
    final primary = isDark ? AppColors.darkPrimary : AppColors.lightPrimary;
    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(index),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: isSelected
              ? BoxDecoration(
                  color: primary.withValues(alpha: isDark ? 0.22 : 0.14),
                  borderRadius: BorderRadius.circular(11),
                )
              : const BoxDecoration(color: Colors.transparent),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected
                    ? primary
                    : (isDark ? AppColors.darkMuted : AppColors.lightMuted),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isSelected
                      ? (isDark ? AppColors.darkInk : AppColors.lightInk)
                      : (isDark ? AppColors.darkMuted : AppColors.lightMuted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BookmarksList extends StatelessWidget {
  final List<BookmarkModel> bookmarks;
  final BookmarksController controller;
  final bool isDark;
  final void Function(BookmarkModel) onOpen;

  const _BookmarksList({
    required this.bookmarks,
    required this.controller,
    required this.isDark,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    if (bookmarks.isEmpty) {
      return const _EmptyState(
        icon: Icons.bookmark_outline_rounded,
        title: 'No Bookmarks Yet',
        message: 'Tap the bookmark icon while reading any PDF\nor EPUB to save key pages and insights here.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
      physics: const BouncingScrollPhysics(),
      itemCount: bookmarks.length,
      itemBuilder: (context, index) {
        final bookmark = bookmarks[index];
        final dateStr = DateFormat('MMM dd, yyyy • hh:mm a').format(bookmark.createdAt);

        return Padding(
          padding: const EdgeInsets.only(bottom: 14.0),
          child: Dismissible(
            key: ValueKey(bookmark.id),
            direction: DismissDirection.endToStart,
            onDismissed: (_) => controller.removeBookmark(bookmark.id),
            background: const _DeleteBackground(),
            child: NeumorphicCard(
              borderRadius: 18,
              depth: 3.5,
              padding: const EdgeInsets.all(16.0),
              onTap: () => onOpen(bookmark),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: bookmark.format == BookFormat.pdf
                              ? const Color(0xFFC2703D).withValues(alpha: 0.15)
                              : const Color(0xFF2C5E7A).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          bookmark.format == BookFormat.pdf ? 'PDF' : 'EPUB',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: bookmark.format == BookFormat.pdf
                                ? (isDark ? AppColors.darkPrimary : AppColors.lightPrimary)
                                : const Color(0xFF2C5E7A),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          bookmark.bookTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isDark ? AppColors.darkInk : AppColors.lightInk,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
                        visualDensity: VisualDensity.compact,
                        onPressed: () => controller.removeBookmark(bookmark.id),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_rounded,
                        size: 16,
                        color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        bookmark.chapterTitle ?? 'Page ${bookmark.pageNumber}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.darkInk : AppColors.lightInk,
                        ),
                      ),
                    ],
                  ),
                  if (bookmark.note != null && bookmark.note!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      bookmark.note!,
                      style: TextStyle(
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                        color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Text(
                    dateStr,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HighlightsList extends StatelessWidget {
  final List<HighlightModel> highlights;
  final bool isDark;
  final void Function(String id) onDelete;

  const _HighlightsList({
    required this.highlights,
    required this.isDark,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (highlights.isEmpty) {
      return const _EmptyState(
        icon: Icons.highlight_rounded,
        title: 'No Highlights Yet',
        message: 'Select text in a PDF and tap "Explain with AI"\nto save explained highlights here.',
      );
    }

    final primary = isDark ? AppColors.darkPrimary : AppColors.lightPrimary;

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
      physics: const BouncingScrollPhysics(),
      itemCount: highlights.length,
      itemBuilder: (context, index) {
        final highlight = highlights[index];
        final dateStr = DateFormat('MMM dd, yyyy').format(highlight.createdAt);

        return Padding(
          padding: const EdgeInsets.only(bottom: 14.0),
          child: Dismissible(
            key: ValueKey(highlight.id),
            direction: DismissDirection.endToStart,
            onDismissed: (_) => onDelete(highlight.id),
            background: const _DeleteBackground(),
            child: NeumorphicCard(
              borderRadius: 18,
              depth: 3.5,
              padding: const EdgeInsets.all(16.0),
              onTap: () => showHighlightDetailSheet(context, highlight),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.menu_book_rounded, size: 16, color: primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          highlight.bookTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isDark ? AppColors.darkInk : AppColors.lightInk,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Page ${highlight.pageNumber}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '"${highlight.selectedText}"',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      fontStyle: FontStyle.italic,
                      color: isDark ? AppColors.darkInk : AppColors.lightInk,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.star_border_rounded,
                        size: 16,
                        color: isDark ? AppColors.darkWarning : AppColors.lightWarning,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          highlight.explanation.takeaway,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            height: 1.4,
                            color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    dateStr,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DeleteBackground extends StatelessWidget {
  const _DeleteBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 20),
      decoration: BoxDecoration(
        color: AppColors.lightDanger,
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Icon(Icons.delete_rounded, color: Colors.white),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _EmptyState({required this.icon, required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            NeumorphicCard(
              shape: NeumorphicShape.debossed,
              borderRadius: 40,
              depth: 3.0,
              padding: const EdgeInsets.all(24),
              isCircle: true,
              child: Icon(
                icon,
                size: 48,
                color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.darkInk : AppColors.lightInk,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
