import 'dart:io' as io;
import 'package:flutter/material.dart';
import 'package:flutter_epub_viewer/flutter_epub_viewer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reader_app/core/constants/app_colors.dart';
import 'package:reader_app/core/theme/neumorphic_decorations.dart';
import 'package:reader_app/core/widgets/neumorphic_button.dart';
import 'package:reader_app/features/bookmarks/controllers/bookmarks_controller.dart';
import 'package:reader_app/features/library/controllers/library_controller.dart';
import 'package:reader_app/features/library/data/models/book_model.dart';
import '../controllers/epub_reader_controller.dart';
import 'widgets/epub_toc_sheet.dart';
import 'widgets/reader_theme_sheet.dart';

class EpubReaderScreen extends ConsumerStatefulWidget {
  final BookModel book;

  const EpubReaderScreen({super.key, required this.book});

  @override
  ConsumerState<EpubReaderScreen> createState() => _EpubReaderScreenState();
}

class _EpubReaderScreenState extends ConsumerState<EpubReaderScreen> {
  late final EpubController _epubController;

  @override
  void initState() {
    super.initState();
    _epubController = EpubController();
  }

  void _syncProgress(double progress) {
    ref.read(epubReaderControllerProvider(widget.book.id).notifier).setProgress(progress);
    ref.read(libraryControllerProvider.notifier).updateBookProgress(
          bookId: widget.book.id,
          currentPage: (progress * widget.book.totalPages).round().clamp(1, widget.book.totalPages),
          totalPages: widget.book.totalPages,
          progress: progress,
        );
  }

  void _showToc(BuildContext context, EpubReaderState state) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => EpubTocSheet(
        chapters: state.chapters.isNotEmpty
            ? state.chapters
            : [
                const EpubChapterItem(
                    title: 'Chapter 1: The Grand Hall', href: '#ch1', index: 0),
                const EpubChapterItem(
                    title: 'Chapter 2: Whispers in the Library', href: '#ch2', index: 1),
                const EpubChapterItem(
                    title: 'Chapter 3: The Secret Parchment', href: '#ch3', index: 2),
                const EpubChapterItem(
                    title: 'Chapter 4: The Midnight Journey', href: '#ch4', index: 3),
              ],
        currentChapterTitle: state.currentChapterTitle,
        onSelectChapter: (chapter) {
          ref
              .read(epubReaderControllerProvider(widget.book.id).notifier)
              .setCurrentChapter(chapter.title);
          Navigator.pop(ctx);
        },
      ),
    );
  }

  void _showThemeSheet(BuildContext context, EpubReaderState state) {
    final notifier = ref.read(epubReaderControllerProvider(widget.book.id).notifier);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ReaderThemeSheet(
        fontSize: state.fontSize,
        themePreset: state.themePreset,
        onFontSizeChanged: (size) {
          notifier.setFontSize(size);
        },
        onThemePresetChanged: (preset) {
          notifier.setThemePreset(preset);
          Navigator.pop(ctx);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(epubReaderControllerProvider(widget.book.id));
    final controller = ref.read(epubReaderControllerProvider(widget.book.id).notifier);
    final bookmarksState = ref.watch(bookmarksControllerProvider);
    final bookmarksController = ref.read(bookmarksControllerProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final isBookmarked = bookmarksState.bookmarks.any(
      (b) =>
          b.bookId == widget.book.id &&
          state.currentChapterTitle != null &&
          b.chapterTitle == state.currentChapterTitle,
    );

    final fileExists = widget.book.filePath.isNotEmpty && io.File(widget.book.filePath).existsSync();

    final Color bgColor = switch (state.themePreset) {
      'sepia' => const Color(0xFFF4ECD8),
      'dark' => const Color(0xFF2B2723),
      'oled' => const Color(0xFF0D0B0A),
      _ => isDark ? AppColors.darkPaper : const Color(0xFFFDFAF4),
    };

    final Color textColor = switch (state.themePreset) {
      'sepia' => const Color(0xFF533F2D),
      'dark' => const Color(0xFFF3EDDF),
      'oled' => const Color(0xFFD4CEC3),
      _ => isDark ? AppColors.darkInk : const Color(0xFF181310),
    };

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          // EPUB Viewer Content
          GestureDetector(
            onTap: controller.toggleControls,
            behavior: HitTestBehavior.translucent,
            child: RepaintBoundary(
              child: fileExists
                  ? EpubViewer(
                      epubController: _epubController,
                      epubSource: EpubSource.fromFile(io.File(widget.book.filePath) as dynamic),
                      onChaptersLoaded: (chapters) {

                        final items = chapters.map((c) {
                          return EpubChapterItem(
                            title: c.title,
                            href: c.href,
                            index: 0,
                          );
                        }).toList();
                        controller.setChapters(items);
                      },
                      onRelocated: (location) {
                        final progress = location.progress;
                        _syncProgress(progress);
                      },
                    )
                  : _buildSampleEpubView(state, bgColor, textColor),
            ),
          ),

          // Top Neomorphic Overlay Bar
          AnimatedPositioned(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            top: state.showControls ? 0 : -100,
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
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.book.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: isDark ? AppColors.darkInk : AppColors.lightInk,
                              ),
                            ),
                            Text(
                              state.currentChapterTitle ?? widget.book.author,
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
                      const SizedBox(width: 6),
                      // TOC
                      NeumorphicButton.icon(
                        icon: Icons.list_rounded,
                        size: 38,
                        iconSize: 18,
                        tooltip: 'Table of Contents',
                        onPressed: () => _showToc(context, state),
                      ),
                      const SizedBox(width: 6),
                      // Typography Theme
                      NeumorphicButton.icon(
                        icon: Icons.format_size_rounded,
                        size: 38,
                        iconSize: 18,
                        tooltip: 'Font & Theme Presets',
                        onPressed: () => _showThemeSheet(context, state),
                      ),
                      const SizedBox(width: 6),
                      // Bookmark
                      NeumorphicButton.icon(
                        icon: isBookmarked
                            ? Icons.bookmark_rounded
                            : Icons.bookmark_border_rounded,
                        size: 38,
                        iconSize: 18,
                        isSelected: isBookmarked,
                        iconColor: isBookmarked
                            ? (isDark ? AppColors.darkPrimary : AppColors.lightPrimary)
                            : null,
                        tooltip: 'Bookmark',
                        onPressed: () {
                          if (isBookmarked) {
                            final bm = bookmarksState.bookmarks.firstWhere(
                              (b) =>
                                  b.bookId == widget.book.id &&
                                  b.chapterTitle == state.currentChapterTitle,
                            );
                            bookmarksController.removeBookmark(bm.id);
                          } else {
                            bookmarksController.addBookmark(
                              bookId: widget.book.id,
                              bookTitle: widget.book.title,
                              format: widget.book.format,
                              pageNumber: (state.progress * widget.book.totalPages).round(),
                              chapterTitle: state.currentChapterTitle ?? 'Current Chapter',
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Bottom Reading Progress HUD
          AnimatedPositioned(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            bottom: state.showControls ? 0 : -100,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: NeumorphicDecorations.boxDecoration(
                    context: context,
                    shape: NeumorphicShape.embossed,
                    borderRadius: 24,
                    depth: 4.0,
                    color: isDark ? AppColors.darkCard : AppColors.lightPaper,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'EPUB Reader',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
                        ),
                      ),
                      Text(
                        '${(state.progress * 100).toInt()}% completed',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSampleEpubView(
    EpubReaderState state,
    Color bgColor,
    Color textColor,
  ) {
    return PageView(
      onPageChanged: (page) {
        final prog = (page + 1) / 5.0;
        _syncProgress(prog);
      },
      children: List.generate(5, (index) {
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 100, 28, 100),
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'CHAPTER ${index + 1}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'The Alchemy of Typography and Quiet Thought',
                style: TextStyle(
                  fontSize: state.fontSize + 6,
                  fontWeight: FontWeight.w800,
                  height: 1.25,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'In the quiet sanctuary of the afternoon, the words flowed like ancient water across stone. An electronic book is not merely digital ink on a screen; it is an intimate architecture built for human consciousness.\n\n'
                'When we open a book in this Neomorphic reading app, every element is designed to minimize visual friction. The soft lighting, bevel contours, and tactile buttons create a calming sensory environment that allows total concentration.\n\n'
                'Adjust your typography presets at any time using the top toolbar to find your ideal font size, contrast, and tone.',
                style: TextStyle(
                  fontSize: state.fontSize,
                  height: 1.7,
                  color: textColor,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}
