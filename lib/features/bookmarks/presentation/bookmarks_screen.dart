import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/neumorphic_decorations.dart';
import '../../../core/widgets/neumorphic_button.dart';
import '../../../core/widgets/neumorphic_card.dart';
import '../../epub_reader/presentation/epub_reader_screen.dart';
import '../../library/controllers/library_controller.dart';
import '../../library/data/models/book_model.dart';
import '../../pdf_reader/presentation/pdf_reader_screen.dart';
import '../controllers/bookmarks_controller.dart';
import '../data/models/bookmark_model.dart';

class BookmarksScreen extends ConsumerWidget {
  const BookmarksScreen({super.key});

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
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(bookmarksControllerProvider);
    final controller = ref.read(bookmarksControllerProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [


            // Top Bar
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bookmarks',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                            color: isDark ? AppColors.darkInk : AppColors.lightInk,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${state.bookmarks.length} Saved Passages & Pages',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
                          ),
                        ),
                      ],
                    ),
                    NeumorphicButton.icon(
                      icon: Icons.bookmark_added_rounded,
                      size: 44,
                      iconSize: 20,
                      isAccent: true,
                      onPressed: null,
                    ),
                  ],
                ),
              ),
            ),

            if (state.bookmarks.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
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
                            Icons.bookmark_outline_rounded,
                            size: 48,
                            color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'No Bookmarks Yet',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: isDark ? AppColors.darkInk : AppColors.lightInk,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap the bookmark icon while reading any PDF\nor EPUB to save key pages and insights here.',
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
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final bookmark = state.bookmarks[index];
                      final dateStr =
                          DateFormat('MMM dd, yyyy • hh:mm a').format(bookmark.createdAt);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14.0),
                        child: Dismissible(
                          key: ValueKey(bookmark.id),
                          direction: DismissDirection.endToStart,
                          onDismissed: (_) => controller.removeBookmark(bookmark.id),
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            decoration: BoxDecoration(
                              color: AppColors.lightDanger,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: const Icon(Icons.delete_rounded, color: Colors.white),
                          ),
                          child: NeumorphicCard(
                            borderRadius: 18,
                            depth: 3.5,
                            padding: const EdgeInsets.all(16.0),
                            onTap: () => _openBookmark(context, ref, bookmark),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
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
                                              ? (isDark
                                                  ? AppColors.darkPrimary
                                                  : AppColors.lightPrimary)
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
                    childCount: state.bookmarks.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
