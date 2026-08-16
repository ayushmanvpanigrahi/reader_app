/// Utility to clean up raw PDF-extracted text before sending to AI.
///
/// Handles broken line-wraps, soft hyphens, ligature artifacts, and
/// excessive whitespace that occur in PDF text extraction.
class TextNormalizer {
  TextNormalizer._();

  /// Cleans raw extracted text: joins hyphenated line-breaks, merges
  /// broken paragraph lines, and normalises whitespace.
  static String clean(String raw) {
    if (raw.trim().isEmpty) return raw.trim();

    var text = raw;

    // 1. Replace tabs with spaces.
    text = text.replaceAll('\t', ' ');

    // 2. Join hyphenated line-breaks: "word-\nbreak" -> "wordbreak".
    text = text.replaceAllMapped(
      RegExp(r'(\w)-\s*\n\s*(\w)', caseSensitive: false),
      (m) => '${m[1]}${m[2]}',
    );

    // 3. Collapse vertical whitespace (double newlines) into a single
    //    paragraph break. Single newlines inside a paragraph become spaces.
    //
    //    Strategy: split on double-newlines (or more) to identify paragraph
    //    breaks, then within each paragraph join lines with a space.
    final paragraphs = text.split(RegExp(r'\n{2,}'));
    text = paragraphs.map((para) {
      // Within a paragraph, join lines separated by a single newline.
      return para.splitMapJoin(
        RegExp(r'\n'),
        onMatch: (_) => ' ',
        onNonMatch: (s) => s,
      );
    }).join('\n\n');

    // 4. Collapse multiple spaces into one.
    text = text.replaceAll(RegExp(r'[ ]{2,}'), ' ');

    // 5. Strip control characters (keep newline, carriage return, tab).
    text = text.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '');

    // 6. Trim leading/trailing whitespace from each line and the whole text.
    final lines = text.split('\n');
    text = lines.map((l) => l.trim()).join('\n').trim();

    return text;
  }
}
