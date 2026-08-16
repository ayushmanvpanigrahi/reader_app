/// Utility to clean up raw PDF-extracted text before sending to AI.
///
/// Handles broken line-wraps, soft hyphens, ligature artifacts, and
/// excessive whitespace that occur in PDF text extraction.
class TextNormalizer {
  TextNormalizer._();

  // Pre-compiled RegExp objects to avoid per-call allocation.
  static final _hyphenBreak = RegExp(r'(\w)-\s*\n\s*(\w)', caseSensitive: false);
  static final _doubleNewline = RegExp(r'\n{2,}');
  static final _singleNewline = RegExp(r'\n');
  static final _multiSpace = RegExp(r'[ ]{2,}');
  static final _controlChars = RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]');

  /// Cleans raw extracted text: joins hyphenated line-breaks, merges
  /// broken paragraph lines, and normalises whitespace.
  static String clean(String raw) {
    if (raw.trim().isEmpty) return raw.trim();

    var text = raw;

    // 1. Replace tabs with spaces.
    text = text.replaceAll('\t', ' ');

    // 2. Join hyphenated line-breaks: "word-\nbreak" -> "wordbreak".
    text = text.replaceAllMapped(_hyphenBreak, (m) => '${m[1]}${m[2]}');

    // 3. Collapse vertical whitespace (double newlines) into a single
    //    paragraph break. Single newlines inside a paragraph become spaces.
    final paragraphs = text.split(_doubleNewline);
    text = paragraphs.map((para) {
      return para.splitMapJoin(
        _singleNewline,
        onMatch: (_) => ' ',
        onNonMatch: (s) => s,
      );
    }).join('\n\n');

    // 4. Collapse multiple spaces into one.
    text = text.replaceAll(_multiSpace, ' ');

    // 5. Strip control characters (keep newline, carriage return, tab).
    text = text.replaceAll(_controlChars, '');

    // 6. Trim leading/trailing whitespace from each line and the whole text.
    final lines = text.split('\n');
    text = lines.map((l) => l.trim()).join('\n').trim();

    return text;
  }
}
