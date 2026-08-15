import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/neumorphic_decorations.dart';
import '../../../core/widgets/neumorphic_button.dart';
import '../../../core/widgets/neumorphic_card.dart';
import '../../epub_reader/presentation/epub_reader_screen.dart';
import '../../pdf_reader/presentation/pdf_reader_screen.dart';
import '../controllers/library_controller.dart';
import '../data/models/book_model.dart';
import 'widgets/book_grid_card.dart';
import 'widgets/book_list_card.dart';
import 'widgets/import_book_fab.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openBook(BookModel book) {
    if (book.isPdf) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => PdfReaderScreen(book: book),
        ),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => EpubReaderScreen(book: book),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(libraryControllerProvider);
    final controller = ref.read(libraryControllerProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Top App Bar
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Library',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                            color: isDark ? AppColors.darkInk : AppColors.lightInk,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${state.books.length} Books in your sanctuary',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        NeumorphicButton.icon(
                          icon: state.viewMode == LibraryViewMode.grid
                              ? Icons.view_list_rounded
                              : Icons.grid_view_rounded,
                          size: 44,
                          iconSize: 20,
                          tooltip: 'Toggle View Mode',
                          onPressed: controller.toggleViewMode,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Search Bar
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: NeumorphicCard(
                  shape: NeumorphicShape.debossed,
                  borderRadius: 18,
                  depth: 2.5,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                  child: Row(
                    children: [
                      Icon(
                        Icons.search_rounded,
                        size: 22,
                        color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: controller.setSearchQuery,
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? AppColors.darkInk : AppColors.lightInk,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Search by title, author, or keywords...',
                            hintStyle: TextStyle(
                              fontSize: 14,
                              color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      if (_searchController.text.isNotEmpty)
                        GestureDetector(
                          onTap: () {
                            _searchController.clear();
                            controller.setSearchQuery('');
                          },
                          child: Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // Filter Tabs
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      _buildFilterChip(
                        label: 'All Books',
                        icon: Icons.auto_stories_rounded,
                        isSelected: state.filter == LibraryFilter.all,
                        onTap: () => controller.setFilter(LibraryFilter.all),
                        isDark: isDark,
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        label: 'Reading',
                        icon: Icons.timelapse_rounded,
                        isSelected: state.filter == LibraryFilter.reading,
                        onTap: () => controller.setFilter(LibraryFilter.reading),
                        isDark: isDark,
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        label: 'PDFs',
                        icon: Icons.picture_as_pdf_rounded,
                        isSelected: state.filter == LibraryFilter.pdf,
                        onTap: () => controller.setFilter(LibraryFilter.pdf),
                        isDark: isDark,
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        label: 'EPUBs',
                        icon: Icons.menu_book_rounded,
                        isSelected: state.filter == LibraryFilter.epub,
                        onTap: () => controller.setFilter(LibraryFilter.epub),
                        isDark: isDark,
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        label: 'Favorites',
                        icon: Icons.favorite_rounded,
                        isSelected: state.filter == LibraryFilter.favorites,
                        onTap: () => controller.setFilter(LibraryFilter.favorites),
                        isDark: isDark,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 12)),

            // Books Content
            if (state.filteredBooks.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _buildEmptyState(isDark),
              )
            else if (state.viewMode == LibraryViewMode.grid)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.62,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final book = state.filteredBooks[index];
                      return BookGridCard(
                        book: book,
                        onTap: () => _openBook(book),
                        onToggleFavorite: () => controller.toggleFavorite(book.id),
                        onDelete: () => controller.deleteBook(book.id),
                      );
                    },
                    childCount: state.filteredBooks.length,
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final book = state.filteredBooks[index];
                      return BookListCard(
                        book: book,
                        onTap: () => _openBook(book),
                        onToggleFavorite: () => controller.toggleFavorite(book.id),
                        onDelete: () => controller.deleteBook(book.id),
                      );
                    },
                    childCount: state.filteredBooks.length,
                  ),
                ),
              ),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 80, right: 8),
        child: ImportBookFab(
          onBookImported: _openBook,
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: isSelected
            ? NeumorphicDecorations.boxDecoration(
                context: context,
                shape: NeumorphicShape.embossed,
                borderRadius: 20,
                depth: 3.0,
                color: isDark ? AppColors.darkCard : AppColors.lightPaper,
              )
            : BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: Colors.transparent,
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.border,
                  width: 0.8,
                ),
              ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected
                  ? (isDark ? AppColors.darkPrimary : AppColors.lightPrimary)
                  : (isDark ? AppColors.darkMuted : AppColors.lightMuted),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? (isDark ? AppColors.darkInk : AppColors.lightInk)
                    : (isDark ? AppColors.darkMuted : AppColors.lightMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
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
                Icons.menu_book_rounded,
                size: 48,
                color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No Books Found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.darkInk : AppColors.lightInk,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Import PDF or EPUB files from your device\nto start reading in your personal library.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
              ),
            ),
            const SizedBox(height: 24),
            ImportBookFab(
              onBookImported: _openBook,
            ),
          ],
        ),
      ),
    );
  }
}
