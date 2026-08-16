import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:reader_app/core/constants/app_colors.dart';
import 'package:reader_app/core/widgets/tap_to_toggle.dart';
import 'package:reader_app/features/bookmarks/controllers/bookmarks_controller.dart';
import 'package:reader_app/features/highlights/presentation/highlight_explanation_sheet.dart';
import 'package:reader_app/features/library/controllers/library_controller.dart';
import 'package:reader_app/features/library/data/models/book_model.dart';
import 'package:reader_app/features/library/data/services/book_enrichment_service.dart';
import 'package:reader_app/features/rag/controllers/rag_controller.dart';
import 'package:reader_app/features/rag/data/rag_models.dart';
import '../controllers/pdf_reader_controller.dart';
import 'widgets/pdf_controls_overlay.dart';
import 'widgets/reading_tone_matrices.dart';

class PdfReaderScreen extends ConsumerStatefulWidget {
  final BookModel book;

  const PdfReaderScreen({super.key, required this.book});

  @override
  ConsumerState<PdfReaderScreen> createState() => _PdfReaderScreenState();
}

class _PdfReaderScreenState extends ConsumerState<PdfReaderScreen> {
  late final PdfViewerController _pdfController;
  Timer? _progressDebounce;
  int? _pendingPage;
  int? _pendingTotalPages;
  bool _isInitialLoad = true;

  @override
  void initState() {
    super.initState();
    _pdfController = PdfViewerController();
    _maybeIngestForRag();
    _maybeEnrichMetadata();
  }

  @override
  void dispose() {
    _progressDebounce?.cancel();
    if (_pendingPage != null) _flushProgress();
    super.dispose();
  }

  void _maybeIngestForRag() {
    final rag = ref.read(ragControllerProvider);
    if (!rag.enabled) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(ragControllerProvider.notifier).ingestBook(widget.book);
    });
  }

  void _maybeEnrichMetadata() {
    if (widget.book.enrichmentStatus == EnrichmentStatus.pending) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(bookEnrichmentServiceProvider).enqueue(widget.book);
      });
    }
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
    // Debounce the disk write so rapid page flips don't hammer storage.
    _pendingPage = page;
    _pendingTotalPages = totalPages;
    _progressDebounce?.cancel();
    _progressDebounce = Timer(const Duration(seconds: 2), _flushProgress);
  }

  void _flushProgress() {
    _progressDebounce?.cancel();
    final page = _pendingPage;
    final totalPages = _pendingTotalPages;
    _pendingPage = null;
    _pendingTotalPages = null;
    if (page == null || totalPages == null || totalPages <= 0) return;
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

  /// Returns `true` when the viewer is showing the cover page (page 1).
  /// Uses the saved position as a fallback before `onPageChanged` fires so
  /// the filter is correct from the very first frame (avoids a brief flash
  /// of unfiltered content when reopening a book mid-way).
  bool _isCoverPage(PdfReaderState state) {
    final effectivePage = state.currentPage > 1
        ? state.currentPage
        : widget.book.currentPage;
    return effectivePage <= 1;
  }

  Axis? _lastScrollDirection;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(pdfReaderControllerProvider(widget.book.id));
    final controller = ref.read(pdfReaderControllerProvider(widget.book.id).notifier);

    // If scroll direction switched, force pdfrx to re-layout with the new
    // layoutPages callback. pdfrx requires an explicit invalidate() call
    // after param changes that affect page layout.
    if (_lastScrollDirection != null && _lastScrollDirection != state.scrollDirection) {
      _lastScrollDirection = state.scrollDirection;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _pdfController.isReady) {
          _pdfController.invalidate();
          _pdfController.goToPage(pageNumber: state.currentPage);
        }
      });
    } else {
      _lastScrollDirection = state.scrollDirection;
    }

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
        // Resume directly at the saved page so the engine positions itself on
        // load; no post-open jump is needed and the first page cannot be written
        // over the saved progress.
        initialPageNumber: widget.book.currentPage < 1 ? 1 : widget.book.currentPage,
        params: PdfViewerParams(
          margin: 8,
          layoutPages: state.scrollDirection == Axis.horizontal ? _layoutHorizontal : null,
          scrollPhysics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          textSelectionParams: const PdfTextSelectionParams(
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
          },
          onViewerReady: (document, controller) {
            _isInitialLoad = false;
          },
          onPageChanged: (pageNumber) {
            // Ignore the events fired while the engine positions itself on the
            // initial page so a stale page 1 can never overwrite saved progress.
            if (pageNumber != null && !_isInitialLoad) {
              _onPageChanged(pageNumber, state.totalPages);
            }
          },
        ),
      );
    } else {
      // Demo / Sample Book preview
      viewerWidget = _buildSamplePdfView(isDark, state, controller);
    }

    // Apply the reading tone (Original / Warm Sepia / Night Charcoal /
    // E-Ink OLED).
    //
    // E-Ink OLED uses a per-page bypass: the cover page (page 1) is
    // rendered without any filter so original artwork shows in true colour,
    // while reading pages (page 2+) get the full luminance invert for true
    // OLED black + white text + natural monochrome illustrations.
    final bool isOledCoverBypass =
        state.readingMode == PdfReadingMode.oledDark && _isCoverPage(state);
    if (state.readingMode != PdfReadingMode.standard && !isOledCoverBypass) {
      viewerWidget = ColorFiltered(
        colorFilter: colorFilterFor(state.readingMode),
        child: viewerWidget,
      );
    }

    return Scaffold(
      backgroundColor: state.readingMode == PdfReadingMode.oledDark
          ? Colors.black
          : (isDark ? AppColors.darkStage : AppColors.lightStage),
      body: Stack(
        children: [
          // Raw pointer tap detection (bypasses the gesture arena the PDF
          // engine wins) so a single tap always toggles the HUD.
          TapToToggle(
            onTap: controller.toggleControls,
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

  static PdfPageLayout _layoutHorizontal(
    List<PdfPage> pages,
    PdfViewerParams params,
  ) {
    final margin = params.margin;
    double maxHeight = 0;
    for (final page in pages) {
      if (page.height > maxHeight) maxHeight = page.height;
    }
    double currentX = margin;
    final rects = <Rect>[];
    for (final page in pages) {
      final top = margin + (maxHeight - page.height) / 2;
      rects.add(Rect.fromLTWH(currentX, top, page.width, page.height));
      currentX += page.width + margin;
    }
    return PdfPageLayout(
      pageLayouts: rects,
      documentSize: Size(currentX, maxHeight + margin * 2),
    );
  }

  Widget _buildSamplePdfView(
    bool isDark,
    PdfReaderState state,
    PdfReaderController controller,
  ) {
    return PageView.builder(
      scrollDirection: state.scrollDirection,
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
