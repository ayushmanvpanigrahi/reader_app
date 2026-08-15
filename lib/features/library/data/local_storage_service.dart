import 'package:shared_preferences/shared_preferences.dart';

import 'models/book_model.dart';
import '../../bookmarks/data/models/bookmark_model.dart';

class LocalStorageService {
  static const String _keyBooks = 'reader_app_books_v1';
  static const String _keyBookmarks = 'reader_app_bookmarks_v1';
  static const String _keyThemeMode = 'reader_app_theme_mode_v1';
  static const String _keyReaderFontSize = 'reader_app_font_size_v1';
  static const String _keyReaderThemePreset = 'reader_app_preset_v1';
  static const String _keyInitialized = 'reader_app_seeded_v1';

  final SharedPreferences _prefs;

  LocalStorageService(this._prefs);

  static Future<LocalStorageService> init() async {
    final prefs = await SharedPreferences.getInstance();
    final service = LocalStorageService(prefs);
    await service._seedInitialDataIfNeeded();
    return service;
  }

  /// Seeds initial welcome books on first install so the library looks great immediately.
  Future<void> _seedInitialDataIfNeeded() async {
    final alreadySeeded = _prefs.getBool(_keyInitialized) ?? false;
    if (!alreadySeeded) {
      final sampleBooks = [
        BookModel(
          id: 'sample-book-1',
          title: 'The Art of Deep Reading',
          author: 'Mortimer J. Adler',
          filePath: '',
          format: BookFormat.pdf,
          fileSizeBytes: 2450000,
          totalPages: 148,
          currentPage: 34,
          progress: 0.23,
          coverColorIndex: 0,
          isFavorite: true,
          addedAt: DateTime.now().subtract(const Duration(days: 3)),
          lastReadAt: DateTime.now().subtract(const Duration(hours: 4)),
          isAssetSample: true,
        ),
        BookModel(
          id: 'sample-book-2',
          title: 'The Great Gatsby & Modern Classics',
          author: 'F. Scott Fitzgerald',
          filePath: '',
          format: BookFormat.epub,
          fileSizeBytes: 1820000,
          totalPages: 210,
          currentPage: 125,
          progress: 0.60,
          coverColorIndex: 1,
          isFavorite: false,
          addedAt: DateTime.now().subtract(const Duration(days: 6)),
          lastReadAt: DateTime.now().subtract(const Duration(days: 1)),
          isAssetSample: true,
        ),
        BookModel(
          id: 'sample-book-3',
          title: 'Meditations & Stoic Thoughts',
          author: 'Marcus Aurelius',
          filePath: '',
          format: BookFormat.pdf,
          fileSizeBytes: 1200000,
          totalPages: 96,
          currentPage: 96,
          progress: 1.0,
          coverColorIndex: 2,
          isFavorite: true,
          addedAt: DateTime.now().subtract(const Duration(days: 12)),
          lastReadAt: DateTime.now().subtract(const Duration(days: 2)),
          isAssetSample: true,
        ),
      ];

      final sampleBookmarks = [
        BookmarkModel(
          id: 'bm-1',
          bookId: 'sample-book-1',
          bookTitle: 'The Art of Deep Reading',
          format: BookFormat.pdf,
          pageNumber: 34,
          chapterTitle: 'Chapter 3: The Rules of Analytical Reading',
          note: 'Marked key rules on classifying a book by its substance.',
          createdAt: DateTime.now().subtract(const Duration(hours: 4)),
          colorHex: 0xFFE57C20,
        ),
        BookmarkModel(
          id: 'bm-2',
          bookId: 'sample-book-2',
          bookTitle: 'The Great Gatsby & Modern Classics',
          format: BookFormat.epub,
          pageNumber: 125,
          chapterTitle: 'Chapter 5: The Green Light',
          note: 'Favorite quote about hope and the restless harbor.',
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
          colorHex: 0xFFC2703D,
        ),
      ];

      await saveBooks(sampleBooks);
      await saveBookmarks(sampleBookmarks);
      await _prefs.setBool(_keyInitialized, true);
    }
  }

  // --- Books Persistence ---

  List<BookModel> getBooks() {
    final rawList = _prefs.getStringList(_keyBooks);
    if (rawList == null || rawList.isEmpty) return [];
    try {
      return rawList.map((str) => BookModel.fromJson(str)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveBooks(List<BookModel> books) async {
    final rawList = books.map((b) => b.toJson()).toList();
    await _prefs.setStringList(_keyBooks, rawList);
  }

  Future<void> saveBook(BookModel book) async {
    final books = getBooks();
    final index = books.indexWhere((b) => b.id == book.id);
    if (index >= 0) {
      books[index] = book;
    } else {
      books.insert(0, book);
    }
    await saveBooks(books);
  }

  Future<void> deleteBook(String id) async {
    final books = getBooks().where((b) => b.id != id).toList();
    await saveBooks(books);
    // Also remove associated bookmarks
    final bookmarks = getBookmarks().where((bm) => bm.bookId != id).toList();
    await saveBookmarks(bookmarks);
  }

  // --- Bookmarks Persistence ---

  List<BookmarkModel> getBookmarks() {
    final rawList = _prefs.getStringList(_keyBookmarks);
    if (rawList == null || rawList.isEmpty) return [];
    try {
      return rawList.map((str) => BookmarkModel.fromJson(str)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveBookmarks(List<BookmarkModel> bookmarks) async {
    final rawList = bookmarks.map((bm) => bm.toJson()).toList();
    await _prefs.setStringList(_keyBookmarks, rawList);
  }

  Future<void> addBookmark(BookmarkModel bookmark) async {
    final bookmarks = getBookmarks();
    bookmarks.insert(0, bookmark);
    await saveBookmarks(bookmarks);
  }

  Future<void> deleteBookmark(String id) async {
    final bookmarks = getBookmarks().where((bm) => bm.id != id).toList();
    await saveBookmarks(bookmarks);
  }

  // --- Settings Persistence ---

  String getThemeMode() => _prefs.getString(_keyThemeMode) ?? 'system';
  Future<void> setThemeMode(String mode) => _prefs.setString(_keyThemeMode, mode);

  double getReaderFontSize() => _prefs.getDouble(_keyReaderFontSize) ?? 18.0;
  Future<void> setReaderFontSize(double size) => _prefs.setDouble(_keyReaderFontSize, size);

  String getReaderThemePreset() => _prefs.getString(_keyReaderThemePreset) ?? 'paper';
  Future<void> setReaderThemePreset(String preset) => _prefs.setString(_keyReaderThemePreset, preset);

  Future<void> clearAll() async {
    await _prefs.clear();
  }
}
