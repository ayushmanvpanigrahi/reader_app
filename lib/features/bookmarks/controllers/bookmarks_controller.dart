import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/bookmark_model.dart';
import '../../library/controllers/library_controller.dart';
import '../../library/data/local_storage_service.dart';

class BookmarksState {
  final List<BookmarkModel> bookmarks;
  final bool isLoading;

  const BookmarksState({
    this.bookmarks = const [],
    this.isLoading = false,
  });

  BookmarksState copyWith({
    List<BookmarkModel>? bookmarks,
    bool? isLoading,
  }) {
    return BookmarksState(
      bookmarks: bookmarks ?? this.bookmarks,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

final bookmarksControllerProvider =
    StateNotifierProvider<BookmarksController, BookmarksState>((ref) {
  final storage = ref.watch(localStorageServiceProvider);
  return BookmarksController(storage);
});

class BookmarksController extends StateNotifier<BookmarksState> {
  final LocalStorageService _storage;

  BookmarksController(this._storage) : super(const BookmarksState()) {
    loadBookmarks();
  }

  void loadBookmarks() {
    final list = _storage.getBookmarks();
    state = state.copyWith(bookmarks: list);
  }

  Future<void> addBookmark({
    required String bookId,
    required String bookTitle,
    required dynamic format,
    required int pageNumber,
    String? epubCfi,
    String? chapterTitle,
    String? note,
  }) async {
    final bookmark = BookmarkModel(
      id: 'bm_${DateTime.now().millisecondsSinceEpoch}',
      bookId: bookId,
      bookTitle: bookTitle,
      format: format,
      pageNumber: pageNumber,
      epubCfi: epubCfi,
      chapterTitle: chapterTitle,
      note: note,
      createdAt: DateTime.now(),
    );

    await _storage.addBookmark(bookmark);
    loadBookmarks();
  }

  Future<void> removeBookmark(String bookmarkId) async {
    await _storage.deleteBookmark(bookmarkId);
    loadBookmarks();
  }

  bool isPageBookmarked(String bookId, int pageNumber) {
    return state.bookmarks.any((bm) => bm.bookId == bookId && bm.pageNumber == pageNumber);
  }
}
