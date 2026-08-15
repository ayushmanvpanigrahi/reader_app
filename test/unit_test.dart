import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader_app/core/constants/app_colors.dart';
import 'package:reader_app/core/theme/neumorphic_decorations.dart';
import 'package:reader_app/features/bookmarks/data/models/bookmark_model.dart';
import 'package:reader_app/features/chat/presentation/markdown_spans.dart';
import 'package:reader_app/features/library/controllers/library_controller.dart';
import 'package:reader_app/features/library/data/models/book_model.dart';
import 'package:reader_app/features/rag/controllers/rag_controller.dart';
import 'package:reader_app/features/rag/data/rag_models.dart';
import 'package:reader_app/features/rag/data/rag_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

TextStyle _styleFor(InlineSpan span) {
  return (span as TextSpan).style ?? const TextStyle();
}

void main() {
  group('MarkdownSpans Tests', () {
    const base = TextStyle(fontSize: 14);

    test('renders bold with **double asterisks**', () {
      final spans = MarkdownSpans.build('This is **bold** text', base: base);
      expect(spans, hasLength(3));
      expect(_styleFor(spans[0]).fontWeight, isNot(FontWeight.w700));
      expect(_styleFor(spans[1]).fontWeight, FontWeight.w700);
      expect(_styleFor(spans[2]).fontWeight, isNot(FontWeight.w700));
    });

    test('renders italic with *single asterisks*', () {
      final spans = MarkdownSpans.build('This is *italic* text', base: base);
      expect(spans, hasLength(3));
      expect(_styleFor(spans[1]).fontStyle, FontStyle.italic);
    });

    test('renders bold italic with ***triple asterisks***', () {
      final spans = MarkdownSpans.build('Some ***bold italic*** words', base: base);
      final mid = _styleFor(spans[1]);
      expect(mid.fontWeight, FontWeight.w700);
      expect(mid.fontStyle, FontStyle.italic);
    });

    test('renders inline code with backticks', () {
      final spans = MarkdownSpans.build('Use `code` here', base: base);
      expect(spans, hasLength(3));
      expect(_styleFor(spans[1]).fontFamily, 'monospace');
    });

    test('renders tappable markdown links', () {
      final spans = MarkdownSpans.build('Visit [OpenAI](https://openai.com) now', base: base);
      expect(spans, hasLength(3));
      final linkSpan = spans[1] as TextSpan;
      expect(linkSpan.text, 'OpenAI');
      expect(linkSpan.style?.decoration, TextDecoration.underline);
      expect(linkSpan.recognizer, isA<TapGestureRecognizer>());
    });

    test('keeps underscores literal', () {
      final spans = MarkdownSpans.build('snake_case stays as is', base: base);
      expect(spans, hasLength(1));
      expect((spans[0] as TextSpan).text, 'snake_case stays as is');
    });

    test('renders headings and bullet lists', () {
      final spans = MarkdownSpans.build('# Title\n- item one', base: base);
      expect(spans.length, greaterThanOrEqualTo(4));
      expect((spans[0] as TextSpan).text, 'Title');
      expect(_styleFor(spans[0]).fontWeight, FontWeight.w800);
    });
  });

  group('RagState Tests', () {
    test('indexFor returns a default for unknown books', () {
      const state = RagState();
      final idx = state.indexFor('nope');
      expect(idx.status, RagBookStatus.notIndexed);
      expect(idx.backendBookId, isNull);
    });

    test('canRagFor requires enabled + connected + indexed', () {
      const off = RagState(
        enabled: false,
        connected: true,
        books: {
          'b1': RagBookIndex(status: RagBookStatus.completed, backendBookId: 'backend_1'),
        },
      );
      expect(off.canRagFor('b1'), isFalse);

      const notConnected = RagState(
        enabled: true,
        connected: false,
        books: {
          'b1': RagBookIndex(status: RagBookStatus.completed, backendBookId: 'backend_1'),
        },
      );
      expect(notConnected.canRagFor('b1'), isFalse);

      const notIndexed = RagState(
        enabled: true,
        connected: true,
        books: {
          'b1': RagBookIndex(status: RagBookStatus.ingesting),
        },
      );
      expect(notIndexed.canRagFor('b1'), isFalse);

      const ready = RagState(
        enabled: true,
        connected: true,
        books: {
          'b1': RagBookIndex(status: RagBookStatus.completed, backendBookId: 'backend_1'),
        },
      );
      expect(ready.canRagFor('b1'), isTrue);
      expect(ready.backendBookIdFor('b1'), 'backend_1');
    });

    test('RagCitation.fromJson parses backend payloads', () {
      final c = RagCitation.fromJson({
        'title': 'Do Epic Shit',
        'chapter': 'Ch. 3',
        'page': 42,
        'score': 0.87,
      });
      expect(c.title, 'Do Epic Shit');
      expect(c.chapter, 'Ch. 3');
      expect(c.page, 42);
      expect(c.score, 0.87);
    });
  });

  group('RagStore Tests', () {
    test('config and book id map round-trip', () async {
      SharedPreferences.setMockInitialValues({});
      final store = await RagStore.init();

      expect(store.getConfig().enabled, isFalse);

      await store.setConfig(const RagConfig(enabled: true, baseUrl: 'http://192.168.1.5:8000'));
      final cfg = store.getConfig();
      expect(cfg.enabled, isTrue);
      expect(cfg.baseUrl, 'http://192.168.1.5:8000');

      await store.setBackendBookId('bookA', 'backend_A');
      await store.setBackendBookId('bookB', 'backend_B');
      expect(store.backendBookIdFor('bookA'), 'backend_A');
      expect(store.backendBookIdFor('bookB'), 'backend_B');
      expect(store.backendBookIdFor('missing'), isNull);
    });
  });

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
