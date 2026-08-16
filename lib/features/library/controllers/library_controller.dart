import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import '../data/local_storage_service.dart';
import '../data/models/book_model.dart';
import '../data/parsers/book_metadata_parser.dart';

enum LibraryFilter { all, pdf, epub, reading, finished, favorites }

enum LibraryViewMode { grid, list }

class LibraryState {
  final List<BookModel> books;
  final bool isLoading;
  final String searchQuery;
  final LibraryFilter filter;
  final LibraryViewMode viewMode;
  final String? errorMessage;

  const LibraryState({
    this.books = const [],
    this.isLoading = false,
    this.searchQuery = '',
    this.filter = LibraryFilter.all,
    this.viewMode = LibraryViewMode.grid,
    this.errorMessage,
  });

  List<BookModel> get filteredBooks {
    var result = books;

    // Apply category filter
    switch (filter) {
      case LibraryFilter.all:
        break;
      case LibraryFilter.pdf:
        result = result.where((b) => b.isPdf).toList();
        break;
      case LibraryFilter.epub:
        result = result.where((b) => b.isEpub).toList();
        break;
      case LibraryFilter.reading:
        result = result
            .where((b) => b.progress > 0.0 && b.progress < 1.0)
            .toList();
        break;
      case LibraryFilter.finished:
        result = result.where((b) => b.progress >= 1.0).toList();
        break;
      case LibraryFilter.favorites:
        result = result.where((b) => b.isFavorite).toList();
        break;
    }

    // Apply search query
    if (searchQuery.trim().isNotEmpty) {
      final q = searchQuery.toLowerCase().trim();
      result = result.where((b) {
        return b.title.toLowerCase().contains(q) ||
            b.author.toLowerCase().contains(q);
      }).toList();
    }

    return result;
  }

  LibraryState copyWith({
    List<BookModel>? books,
    bool? isLoading,
    String? searchQuery,
    LibraryFilter? filter,
    LibraryViewMode? viewMode,
    String? errorMessage,
    bool clearError = false,
  }) {
    return LibraryState(
      books: books ?? this.books,
      isLoading: isLoading ?? this.isLoading,
      searchQuery: searchQuery ?? this.searchQuery,
      filter: filter ?? this.filter,
      viewMode: viewMode ?? this.viewMode,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

final localStorageServiceProvider = Provider<LocalStorageService>((ref) {
  throw UnimplementedError(
    'Initialize localStorageServiceProvider in main.dart',
  );
});

final libraryControllerProvider =
    StateNotifierProvider<LibraryController, LibraryState>((ref) {
      final storage = ref.watch(localStorageServiceProvider);
      return LibraryController(storage);
    });

class LibraryController extends StateNotifier<LibraryState> {
  final LocalStorageService _storage;

  LibraryController(this._storage) : super(const LibraryState()) {
    loadBooks();
  }

  void loadBooks() {
    state = state.copyWith(isLoading: true);
    final books = _storage.getBooks();
    state = state.copyWith(books: books, isLoading: false);
  }

  /// Updates a single book in state without triggering a full disk reload.
  void updateBookInState(BookModel updated) {
    final list = [...state.books];
    final index = list.indexWhere((b) => b.id == updated.id);
    if (index >= 0) {
      list[index] = updated;
      state = state.copyWith(books: list);
    }
  }

  /// Clears any pending import error after the UI has shown it.
  void clearError() {
    if (state.errorMessage != null) {
      state = state.copyWith(clearError: true);
    }
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setFilter(LibraryFilter filter) {
    state = state.copyWith(filter: filter);
  }

  void toggleViewMode() {
    final next = state.viewMode == LibraryViewMode.grid
        ? LibraryViewMode.list
        : LibraryViewMode.grid;
    state = state.copyWith(viewMode: next);
  }

  /// Picks and imports PDF or EPUB files from local storage.
  Future<BookModel?> importFile() async {
    try {
      final result = await FilePickerPlatform.instance.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'epub'],
      );

      if (result.isEmpty) {
        return null;
      }

      final platformFile = result.first;
      final path = platformFile.path;
      if (path == null || path.isEmpty) {
        state = state.copyWith(
          errorMessage: 'Could not access the selected file path.',
        );
        return null;
      }

      final file = File(path);
      if (!await file.exists()) {
        state = state.copyWith(errorMessage: 'Selected file does not exist.');
        return null;
      }

      final extension = p.extension(path).toLowerCase();
      final format = extension.contains('epub')
          ? BookFormat.epub
          : BookFormat.pdf;
      final fileSizeBytes = await file.length();

      // Tier 1: Instant Native Metadata & Filename Pattern Parsing
      final parsed = await BookMetadataParser.parseFile(path, format);
      final isConfident =
          parsed.isConfident &&
          parsed.author != null &&
          parsed.author!.isNotEmpty;
      final author = isConfident
          ? parsed.author!
          : (parsed.author ?? 'Imported Document');
      final title = parsed.title;
      final enrichmentStatus = isConfident
          ? EnrichmentStatus.notNeeded
          : EnrichmentStatus.pending;

      final newBook = BookModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        author: author,
        filePath: path,
        format: format,
        fileSizeBytes: fileSizeBytes,
        totalPages: 1,
        currentPage: 1,
        progress: 0.0,
        coverColorIndex: (state.books.length % 5),
        isFavorite: false,
        addedAt: DateTime.now(),
        lastReadAt: DateTime.now(),
        enrichmentStatus: enrichmentStatus,
      );

      await _storage.saveBook(newBook);
      loadBooks();
      return newBook;
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to import file: $e');
      return null;
    }
  }

  Future<void> updateBookProgress({
    required String bookId,
    required int currentPage,
    required int totalPages,
    required double progress,
    String? epubCfi,
  }) async {
    final books = [...state.books];
    final index = books.indexWhere((b) => b.id == bookId);
    if (index >= 0) {
      final updated = books[index].copyWith(
        currentPage: currentPage,
        totalPages: totalPages > 0 ? totalPages : books[index].totalPages,
        progress: progress.clamp(0.0, 1.0),
        epubCfi: epubCfi ?? books[index].epubCfi,
        lastReadAt: DateTime.now(),
      );
      books[index] = updated;
      state = state.copyWith(books: books);
      await _storage.saveBook(updated);
    }
  }

  Future<void> toggleFavorite(String bookId) async {
    final books = [...state.books];
    final index = books.indexWhere((b) => b.id == bookId);
    if (index >= 0) {
      final updated = books[index].copyWith(
        isFavorite: !books[index].isFavorite,
      );
      books[index] = updated;
      state = state.copyWith(books: books);
      await _storage.saveBook(updated);
    }
  }

  Future<void> deleteBook(String bookId) async {
    await _storage.deleteBook(bookId);
    loadBooks();
  }
}
