import 'package:flutter_test/flutter_test.dart';
import 'package:reader_app/features/library/data/parsers/book_metadata_parser.dart';

void main() {
  group('BookMetadataParser Filename Tests', () {
    test('parses "Author - Title" format accurately', () {
      final res = BookMetadataParser.parseFromFilename('/storage/emulated/0/Books/George Orwell - 1984.pdf');
      expect(res.title, '1984');
      expect(res.author, 'George Orwell');
      expect(res.isConfident, isTrue);
    });

    test('parses "Title by Author" format accurately', () {
      final res = BookMetadataParser.parseFromFilename('Atomic Habits by James Clear.epub');
      expect(res.title, 'Atomic Habits');
      expect(res.author, 'James Clear');
      expect(res.isConfident, isTrue);
    });

    test('parses "[Author] Title" format accurately', () {
      final res = BookMetadataParser.parseFromFilename('[Robert C. Martin] Clean Code.pdf');
      expect(res.title, 'Clean Code');
      expect(res.author, 'Robert C. Martin');
      expect(res.isConfident, isTrue);
    });

    test('strips web artifacts like (z-lib.org) and underscores', () {
      final res = BookMetadataParser.parseFromFilename('Cal Newport - Deep Work (z-lib.org).pdf');
      expect(res.title, 'Deep Work');
      expect(res.author, 'Cal Newport');
      expect(res.isConfident, isTrue);
    });

    test('handles inverted "Lastname, Firstname" format in filename', () {
      final res = BookMetadataParser.parseFromFilename('Orwell, George - Animal Farm.epub');
      expect(res.title, 'Animal Farm');
      expect(res.author, 'George Orwell');
      expect(res.isConfident, isTrue);
    });

    test('falls back gracefully on generic document names', () {
      final res = BookMetadataParser.parseFromFilename('lecture_notes_march_2026.pdf');
      expect(res.title, 'Lecture Notes March 2026');
      expect(res.author, isNull);
      expect(res.isConfident, isFalse);
    });
  });
}
