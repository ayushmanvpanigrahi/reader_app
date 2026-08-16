import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:reader_app/core/constants/app_colors.dart';
import 'package:reader_app/features/bookmarks/controllers/bookmarks_controller.dart';
import 'package:reader_app/features/highlights/presentation/highlight_explanation_sheet.dart';
import 'package:reader_app/features/library/controllers/library_controller.dart';
import 'package:reader_app/features/library/data/models/book_model.dart';
import 'package:reader_app/features/rag/controllers/rag_controller.dart';
import 'package:reader_app/features/rag/data/rag_models.dart';
import '../controllers/pdf_reader_controller.dart';
import 'widgets/pdf_controls_overlay.dart';

class PdfReaderScreen extends ConsumerStatefulWidget {
  final BookModel book;

  const PdfReaderScreen({super.key, required this.book});

  @override
  ConsumerState<PdfReaderScreen> createState() => _PdfReaderScreenState();
}

class _PdfReaderScreenState extends ConsumerState<PdfReaderScreen> {
  late final PdfViewerController _pdfController;

  @override
  void initState() {
    super.initState();
    _pdfController = PdfViewerController();
    _maybeIngestForRag();
  }

  void _maybeIngestForRag() {
    final rag = ref.read(ragControllerProvider);
    if (!rag.enabled) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(ragControllerProvider.notifier).ingestBook(widget.book);
    });
  }

  Future<void> _explainSelection(PdfTextSelectionDelegate selection) async {
    try {
      final text = await selection.getSelectedText();
      if (!mounted || text.trim().isEmpty) return;
      final state = ref.read(pdfReaderControllerProvider(widget.book.id));
      await showHighlightExplanationSheet(
        context,
        bookId: widget.book.id,
        bookTitle: widget.book.title,
        pageNumber: state.currentPage,
        selectedText: text,
      );
    } catch (_) {
      // Ignore selection failures.
    }
  }

  void _onPageChanged(int page, int totalPages) {
    ref.read(pdfReaderControllerProvider(widget.book.id).notifier).onPageChanged(page);
    final progress = totalPages > 0 ? (page / totalPages) : 0.0;
    ref.read(libraryControllerProvider.notifier).updateBookProgress(
          bookId: widget.book.id,
          currentPage: page,
          totalPages: totalPages,
          progress: progress,
        );
  }

  void _goToPage(int page) {
    if (_pdfController.isReady) {
      _pdfController.goToPage(pageNumber: page);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(pdfReaderControllerProvider(widget.book.id));
    final controller = ref.read(pdfReaderControllerProvider(widget.book.id).notifier);
    final bookmarksState = ref.watch(bookmarksControllerProvider);
    final bookmarksController = ref.read(bookmarksControllerProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final isBookmarked = bookmarksController.isPageBookmarked(
      widget.book.id,
      state.currentPage,
    );

    final fileExists = widget.book.filePath.isNotEmpty && File(widget.book.filePath).existsSync();

    Widget viewerWidget;

    if (fileExists) {
      viewerWidget = PdfViewer.file(
        widget.book.filePath,
        controller: _pdfController,
        params: PdfViewerParams(
          margin: 8,
          textSelectionParams: PdfTextSelectionParams(
            enabled: true,
            showContextMenuAutomatically: true,
          ),
          customizeContextMenuItems: (params, items) {
            items.add(
              ContextMenuButtonItem(
                type: ContextMenuButtonType.custom,
                label: 'Explain with AI',
                onPressed: () {
                  params.dismissContextMenu();
                  _explainSelection(params.textSelectionDelegate);
                },
              ),
            );
          },
          onDocumentChanged: (document) {

            final pages = document?.pages.length ?? 1;
            controller.onDocumentLoaded(pages, widget.book.currentPage);
            if (widget.book.currentPage > 1) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _goToPage(widget.book.currentPage);
              });
            }
          },
          onPageChanged: (pageNumber) {
            if (pageNumber != null) {
              _onPageChanged(pageNumber, state.totalPages);
            }
          },
        ),
      );
    } else {
      // Demo / Sample Book preview
      viewerWidget = _buildSamplePdfView(isDark, state, controller);
    }

    // Apply color filter mode (Standard / Sepia / Dark Invert)
    if (state.readingMode == PdfReadingMode.sepia) {
      viewerWidget = ColorFiltered(
        colorFilter: const ColorFilter.matrix(<double>[
          0.90, 0.05, 0.05, 0, 0, // Red
          0.05, 0.85, 0.05, 0, 0, // Green
          0.05, 0.05, 0.65, 0, 0, // Blue
          0, 0, 0, 1, 0,          // Alpha
        ]),
        child: viewerWidget,
      );
    } else if (state.readingMode == PdfReadingMode.darkInverted) {
      viewerWidget = ColorFiltered(
        colorFilter: const ColorFilter.matrix(<double>[
          -1, 0, 0, 0, 255, // Red Invert
          0, -1, 0, 0, 255, // Green Invert
          0, 0, -1, 0, 255, // Blue Invert
          0, 0, 0, 1, 0,    // Alpha
        ]),
        child: viewerWidget,
      );
    }

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkStage : AppColors.lightStage,
      body: Stack(
        children: [
          // Gesture detector to toggle overlay HUD
          GestureDetector(
            onTap: controller.toggleControls,
            behavior: HitTestBehavior.translucent,
            child: RepaintBoundary(
              child: viewerWidget,
            ),
          ),

          // Top and Bottom Neomorphic Overlays
          PdfControlsOverlay(
            book: widget.book,
            state: state,
            isBookmarked: isBookmarked,
            onToggleBookmark: () {
              if (isBookmarked) {
                final matches = bookmarksState.bookmarks.where(
                  (b) => b.bookId == widget.book.id && b.pageNumber == state.currentPage,
                );
                if (matches.isNotEmpty) {
                  bookmarksController.removeBookmark(matches.first.id);
                }
              } else {
                bookmarksController.addBookmark(
                  bookId: widget.book.id,
                  bookTitle: widget.book.title,
                  format: widget.book.format,
                  pageNumber: state.currentPage,
                  chapterTitle: 'Page ${state.currentPage}',
                );
              }
            },
            onToggleScrollDirection: controller.toggleScrollDirection,
            onSelectReadingMode: controller.setReadingMode,
            onPageSelected: (page) {
              controller.onPageChanged(page);
              _goToPage(page);
            },
            onBack: () => Navigator.pop(context),
          ),

          // RAG indexing status chip
          _ragReaderChip(bookId: widget.book.id, isDark: isDark),
        ],
      ),
    );
  }

  Widget _ragReaderChip({required String bookId, required bool isDark}) {
    final rag = ref.watch(ragControllerProvider);
    if (!rag.enabled) return const SizedBox.shrink();
    final index = rag.indexFor(bookId);
    if (index.status == RagBookStatus.notIndexed) return const SizedBox.shrink();

    final (text, icon) = switch (index.status) {
      RagBookStatus.ingesting => (
          'Indexing for RAG… ${(index.progress * 100).toStringAsFixed(0)}%',
          Icons.hourglass_top_rounded,
        ),
      RagBookStatus.completed => (
          'Indexed · Ask about this book in Chat',
          Icons.check_circle_rounded,
        ),
      RagBookStatus.failed => ('Index failed', Icons.error_outline_rounded),
      RagBookStatus.notIndexed => ('', Icons.hub_outlined),
    };
    final accent = isDark ? AppColors.darkPrimary : AppColors.lightPrimary;

    return Positioned(
      left: 0,
      right: 0,
      bottom: 12,
      child: Center(
        child: GestureDetector(
          onTap: () => ref.read(ragControllerProvider.notifier).ingestBook(widget.book),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard.withValues(alpha: 0.9) : AppColors.lightPaper.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: accent.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 14,
                  color: index.status == RagBookStatus.failed
                      ? const Color(0xFFE57373)
                      : accent,
                ),
                const SizedBox(width: 6),
                Text(
                  text,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: index.status == RagBookStatus.failed
                        ? const Color(0xFFE57373)
                        : (isDark ? AppColors.darkInk : AppColors.lightInk),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSamplePdfView(
    bool isDark,
    PdfReaderState state,
    PdfReaderController controller,
  ) {
    return PageView.builder(
      itemCount: 15,
      controller: PageController(initialPage: (widget.book.currentPage - 1).clamp(0, 14)),
      onPageChanged: (page) {
        _onPageChanged(page + 1, 15);
      },
      itemBuilder: (context, index) {
        final pageNum = index + 1;
        return Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 80),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkPaper : AppColors.paper,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  offset: const Offset(0, 4),
                  blurRadius: 12,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.book.title,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
                      ),
                    ),
                    Text(
                      'Page $pageNum',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 32),
                Text(
                  'Chapter ${((pageNum - 1) ~/ 3) + 1}: The Philosophy of Form and Reading',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: isDark ? AppColors.darkInk : AppColors.lightInk,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: Text(
                    'To read deeply is to immerse oneself in the deliberate cadence of the author\'s mind. Every paragraph serves as a sanctuary for thought, structured to elevate intellect above the noise of ephemeral distractions.\n\n'
                    'In this neomorphic reading environment, light and shadow converge to produce an organic, tactile sensation reminiscent of authentic parchment, eliminating visual fatigue while preserving the timeless reverence of physical books.\n\n'
                    'Feel the soft dual-shadow bevels as you navigate chapters, adjust your reading themes, and record lasting bookmarks.\n\n'
                    'Tip: Tap anywhere on the screen to toggle the Neomorphic reading controls, switch color temperature modes, or scrub through pages with the tactile slider.',
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.65,
                      color: isDark ? AppColors.darkInk : AppColors.lightInk,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
