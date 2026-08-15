import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader_app/core/constants/app_colors.dart';
import 'package:reader_app/core/theme/neumorphic_decorations.dart';
import 'package:reader_app/features/bookmarks/data/models/bookmark_model.dart';
import 'package:reader_app/features/library/controllers/library_controller.dart';
import 'package:reader_app/features/library/data/models/book_model.dart';

void main() {
  group('AppColors Tests', () {
    test('Strict AppColors constants have correct values', () {
      expect(AppColors.primary, const Color(0xFFC2703D));
      expect(AppColors.lightStage, const Color(0xFFF0EEEB));
      expect(AppColors.darkStage, const Color(0xFF1F1B18));
      expect(AppColors.lightPaper, const Color(0xFFFDFAF4));
      expect(AppColors.darkPaper, const Color(0xFF2B2723));
      expect(AppColors.darkCard, const Color(0xFF322D28));
      expect(AppColors.lightPrimary, const Color(0xFFE57C20));
      expect(AppColors.darkPrimary, const Color(0xFFEE9C21));
    });
  });

  group('BookModel & BookmarkModel Serialization Tests', () {
    test('BookModel serializes to JSON and deserializes correctly', () {
      final now = DateTime.now();
      final book = BookModel(
        id: 'book-123',
        title: 'Deep Work & Digital Minimalism',
        author: 'Cal Newport',
        filePath: '/storage/books/deep_work.pdf',
        format: BookFormat.pdf,
        fileSizeBytes: 3450000,
        totalPages: 240,
        currentPage: 60,
        progress: 0.25,
        coverColorIndex: 2,
        isFavorite: true,
        addedAt: now,
        lastReadAt: now,
      );

      final jsonStr = book.toJson();
      final deserialized = BookModel.fromJson(jsonStr);

      expect(deserialized.id, book.id);
      expect(deserialized.title, book.title);
      expect(deserialized.author, book.author);
      expect(deserialized.format, BookFormat.pdf);
      expect(deserialized.isPdf, isTrue);
      expect(deserialized.isEpub, isFalse);
      expect(deserialized.progressPercentage, 25.0);
      expect(deserialized.isFavorite, isTrue);
    });

    test('BookmarkModel serializes and deserializes accurately', () {
      final bookmark = BookmarkModel(
        id: 'bm-99',
        bookId: 'book-123',
        bookTitle: 'Deep Work',
        format: BookFormat.epub,
        pageNumber: 42,
        chapterTitle: 'Chapter 2: Deep Habits',
        note: 'Crucial quote on cognitive residue',
        createdAt: DateTime(2026, 8, 15),
      );

      final jsonStr = bookmark.toJson();
      final fromJson = BookmarkModel.fromJson(jsonStr);

      expect(fromJson.id, 'bm-99');
      expect(fromJson.bookTitle, 'Deep Work');
      expect(fromJson.chapterTitle, 'Chapter 2: Deep Habits');
      expect(fromJson.format, BookFormat.epub);
      expect(fromJson.pageNumber, 42);
    });
  });

  group('NeumorphicDecorations Tests', () {
    test('Calculates dual shadows in Light Mode', () {
      final shadows = NeumorphicDecorations.embossedShadows(
        isDark: false,
        depth: 4.0,
      );

      expect(shadows.length, 2);
      expect(shadows[0].offset, const Offset(-4.0, -4.0)); // Top-left highlight
      expect(shadows[1].offset, const Offset(4.0, 4.0));   // Bottom-right shadow
    });

    test('Calculates dual shadows in Dark Mode', () {
      final shadows = NeumorphicDecorations.embossedShadows(
        isDark: true,
        depth: 5.0,
      );

      expect(shadows.length, 2);
      expect(shadows[0].offset, const Offset(-5.0, -5.0)); // Top-left dark highlight
      expect(shadows[1].offset, const Offset(5.0, 5.0));   // Bottom-right deep ambient shadow
    });
  });

  group('LibraryState Filtering Tests', () {
    test('Filters books correctly by format and search query', () {
      final books = [
        BookModel(
          id: '1',
          title: 'Flutter in Action',
          author: 'Eric Windmill',
          filePath: 'path/1.pdf',
          format: BookFormat.pdf,
          progress: 0.5,
          addedAt: DateTime.now(),
        ),
        BookModel(
          id: '2',
          title: 'Clean Architecture in Dart',
          author: 'Uncle Bob',
          filePath: 'path/2.epub',
          format: BookFormat.epub,
          progress: 1.0,
          addedAt: DateTime.now(),
        ),
      ];

      final statePdf = LibraryState(books: books, filter: LibraryFilter.pdf);
      expect(statePdf.filteredBooks.length, 1);
      expect(statePdf.filteredBooks.first.title, 'Flutter in Action');

      final stateSearch = LibraryState(books: books, searchQuery: 'Clean');
      expect(stateSearch.filteredBooks.length, 1);
      expect(stateSearch.filteredBooks.first.title, 'Clean Architecture in Dart');

      final stateFinished = LibraryState(books: books, filter: LibraryFilter.finished);
      expect(stateFinished.filteredBooks.length, 1);
      expect(stateFinished.filteredBooks.first.title, 'Clean Architecture in Dart');
    });
  });
}
