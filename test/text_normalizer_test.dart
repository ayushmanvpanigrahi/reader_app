import 'package:flutter_test/flutter_test.dart';
import 'package:reader_app/features/highlights/data/text_normalizer.dart';

void main() {
  group('TextNormalizer.clean', () {
    test('joins hyphenated line-breaks', () {
      expect(
        TextNormalizer.clean('word-\nbreak'),
        'wordbreak',
      );
    });

    test('joins broken lines within a paragraph', () {
      expect(
        TextNormalizer.clean('This is a sen\nthat spans two lines.'),
        'This is a sen that spans two lines.',
      );
    });

    test('preserves paragraph breaks (double newlines)', () {
      expect(
        TextNormalizer.clean('First paragraph.\n\nSecond paragraph.'),
        'First paragraph.\n\nSecond paragraph.',
      );
    });

    test('collapses multiple spaces into one', () {
      expect(
        TextNormalizer.clean('Too   many    spaces'),
        'Too many spaces',
      );
    });

    test('strips control characters', () {
      expect(
        TextNormalizer.clean('Hello\x00World\x07!'),
        'HelloWorld!',
      );
    });

    test('trims leading and trailing whitespace', () {
      expect(
        TextNormalizer.clean('  trimmed text  '),
        'trimmed text',
      );
    });

    test('handles empty string', () {
      expect(TextNormalizer.clean(''), '');
      expect(TextNormalizer.clean('   '), '');
    });

    test('normalizes tabs to spaces', () {
      expect(
        TextNormalizer.clean('col1\tcol2'),
        'col1 col2',
      );
    });

    test('handles multi-line paragraph with hyphenated break', () {
      expect(
        TextNormalizer.clean(
          'This is a com-\nprehensive sentence.',
        ),
        'This is a comprehensive sentence.',
      );
    });

    test('preserves legitimate stanza breaks', () {
      expect(
        TextNormalizer.clean('Line one.\nLine two.\n\nNew stanza.'),
        'Line one. Line two.\n\nNew stanza.',
      );
    });
  });
}
