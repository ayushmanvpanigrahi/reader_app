import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models/book_model.dart';
import '../../bookmarks/data/models/bookmark_model.dart';

class LocalStorageService {
  // Pref keys kept for the one-time migration out of SharedPreferences.
  static const String _keyBooks = 'reader_app_books_v1';
  static const String _keyBookmarks = 'reader_app_bookmarks_v1';
  static const String _keyThemeMode = 'reader_app_theme_mode_v1';
  static const String _keyReaderFontSize = 'reader_app_font_size_v1';
  static const String _keyReaderThemePreset = 'reader_app_preset_v1';
  static const String _keyInitialized = 'reader_app_seeded_v1';

  // Per-item Hive boxes: key = book/bookmark id, value = JSON string.
  static const String _boxBooks = 'reader_app_books';
  static const String _boxBookmarks = 'reader_app_bookmarks';

  final SharedPreferences _prefs;
  late Box<String> _booksBox;
  late Box<String> _bookmarksBox;

  LocalStorageService(this._prefs);

  static Future<LocalStorageService> init() async {
    final prefs = await SharedPreferences.getInstance();
    final service = LocalStorageService(prefs);
    await service._openBoxes();
    await service._migrateFromPrefs();
    await service._seedInitialDataIfNeeded();
    return service;
  }

  Future<void> _openBoxes() async {
    _booksBox = await Hive.openBox<String>(_boxBooks);
    _bookmarksBox = await Hive.openBox<String>(_boxBookmarks);
  }

  /// One-time migration: books/bookmarks used to live as full JSON lists in
  /// SharedPreferences; move them into per-item Hive boxes on first launch.
  Future<void> _migrateFromPrefs() async {
    if (_booksBox.isEmpty) {
      final rawBooks = _prefs.getStringList(_keyBooks);
      if (rawBooks != null && rawBooks.isNotEmpty) {
        final map = <String, String>{};
        for (final raw in rawBooks) {
          final book = _decodeBook(raw);
          if (book != null) map[book.id] = raw;
        }
        if (map.isNotEmpty) await _booksBox.putAll(map);
      }
    }
    if (_bookmarksBox.isEmpty) {
      final rawBookmarks = _prefs.getStringList(_keyBookmarks);
      if (rawBookmarks != null && rawBookmarks.isNotEmpty) {
        final map = <String, String>{};
        for (final raw in rawBookmarks) {
          final bookmark = _decodeBookmark(raw);
          if (bookmark != null) map[bookmark.id] = raw;
        }
        if (map.isNotEmpty) await _bookmarksBox.putAll(map);
      }
    }
    // Drop the old list keys so we never double-migrate or keep stale data.
    if (_prefs.containsKey(_keyBooks)) await _prefs.remove(_keyBooks);
    if (_prefs.containsKey(_keyBookmarks)) await _prefs.remove(_keyBookmarks);
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
    final books = <BookModel>[];
    for (final raw in _booksBox.values) {
      final book = _decodeBook(raw);
      if (book != null) books.add(book);
    }
    books.sort((a, b) => b.addedAt.compareTo(a.addedAt));
    return books;
  }

  Future<void> saveBooks(List<BookModel> books) async {
    await _booksBox.putAll({for (final b in books) b.id: b.toJson()});
    final ids = books.map((b) => b.id).toSet();
    for (final key in _booksBox.keys.toList()) {
      if (!ids.contains(key)) await _booksBox.delete(key);
    }
  }

  Future<void> saveBook(BookModel book) async {
    await _booksBox.put(book.id, book.toJson());
  }

  Future<void> deleteBook(String id) async {
    await _booksBox.delete(id);
    // Also remove associated bookmarks.
    final toDelete = _bookmarksBox.keys.where((bmKey) {
      return _decodeBookmark(_bookmarksBox.get(bmKey))?.bookId == id;
    }).toList();
    for (final key in toDelete) {
      await _bookmarksBox.delete(key);
    }
  }

  // --- Bookmarks Persistence ---

  List<BookmarkModel> getBookmarks() {
    final bookmarks = <BookmarkModel>[];
    for (final raw in _bookmarksBox.values) {
      final bookmark = _decodeBookmark(raw);
      if (bookmark != null) bookmarks.add(bookmark);
    }
    bookmarks.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return bookmarks;
  }

  Future<void> saveBookmarks(List<BookmarkModel> bookmarks) async {
    await _bookmarksBox.putAll({for (final bm in bookmarks) bm.id: bm.toJson()});
    final ids = bookmarks.map((b) => b.id).toSet();
    for (final key in _bookmarksBox.keys.toList()) {
      if (!ids.contains(key)) await _bookmarksBox.delete(key);
    }
  }

  Future<void> addBookmark(BookmarkModel bookmark) async {
    await _bookmarksBox.put(bookmark.id, bookmark.toJson());
  }

  Future<void> deleteBookmark(String id) async {
    await _bookmarksBox.delete(id);
  }

  // --- Settings Persistence (still in SharedPreferences) ---

  String getThemeMode() => _prefs.getString(_keyThemeMode) ?? 'system';
  Future<void> setThemeMode(String mode) => _prefs.setString(_keyThemeMode, mode);

  double getReaderFontSize() => _prefs.getDouble(_keyReaderFontSize) ?? 18.0;
  Future<void> setReaderFontSize(double size) => _prefs.setDouble(_keyReaderFontSize, size);

  String getReaderThemePreset() => _prefs.getString(_keyReaderThemePreset) ?? 'paper';
  Future<void> setReaderThemePreset(String preset) => _prefs.setString(_keyReaderThemePreset, preset);

  Future<void> clearAll() async {
    await _booksBox.clear();
    await _bookmarksBox.clear();
    await _prefs.clear();
  }

  BookModel? _decodeBook(String? raw) {
    if (raw == null) return null;
    try {
      return BookModel.fromJson(raw);
    } catch (e, stack) {
      debugPrint('[LocalStorage] Failed to decode BookModel: $e\n$stack');
      return null;
    }
  }

  BookmarkModel? _decodeBookmark(String? raw) {
    if (raw == null) return null;
    try {
      return BookmarkModel.fromJson(raw);
    } catch (e, stack) {
      debugPrint('[LocalStorage] Failed to decode BookmarkModel: $e\n$stack');
      return null;
    }
  }
}
