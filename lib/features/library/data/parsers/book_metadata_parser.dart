import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import '../models/book_model.dart';
import 'epub_zip_reader.dart';

class ParsedMetadataResult {
  final String title;
  final String? author;
  final bool isConfident;

  const ParsedMetadataResult({
    required this.title,
    this.author,
    this.isConfident = false,
  });
}

class BookMetadataParser {
  static const List<String> _ignoredPdfAuthors = [
    'adobe',
    'microsoft',
    'word',
    'latex',
    'acrobat',
    'distiller',
    'canva',
    'calibre',
    'unknown',
    'imported document',
    'untitled',
    'pdf generator',
    'pdfforge',
    'foxit',
    'quartz',
    'coregraphics',
  ];

  static const List<String> _artifactPatterns = [
    r'\(z-lib(?:\.org)?\)',
    r'\[z-lib(?:\.org)?\]',
    r'\(oceanofpdf(?:\.com)?\)',
    r'\[oceanofpdf(?:\.com)?\]',
    r'_oceanofpdf\.com_',
    r'\(libgen(?:\.is|\.rs|\.li)?\)',
    r'\[libgen(?:\.is|\.rs|\.li)?\]',
    r'\[1080p\]',
    r'\[720p\]',
    r'\(v\d+(?:\.\d+)*\)',
    r'_v\d+',
  ];

  /// Parses file metadata (Native -> Filename pattern).
  static Future<ParsedMetadataResult> parseFile(String filePath, BookFormat format) async {
    final file = File(filePath);
    if (!await file.exists()) {
      return parseFromFilename(filePath);
    }

    try {
      if (format == BookFormat.epub) {
        final epubResult = await _parseEpubMetadata(file);
        if (epubResult.isConfident && epubResult.author != null) {
          return epubResult;
        }
      } else if (format == BookFormat.pdf) {
        final pdfResult = await _parsePdfMetadata(file);
        if (pdfResult.isConfident && pdfResult.author != null) {
          return pdfResult;
        }
      }
    } catch (_) {
      // Fall through to filename parsing on metadata read failure.
    }

    return parseFromFilename(filePath);
  }

  /// Tier 1.5: Smart Filename Pattern Parsing
  static ParsedMetadataResult parseFromFilename(String filePath) {
    var rawName = p.basenameWithoutExtension(filePath);

    // Strip common pirated/web artifacts
    for (final pattern in _artifactPatterns) {
      rawName = rawName.replaceAll(RegExp(pattern, caseSensitive: false), '');
    }

    rawName = rawName.replaceAll('_', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

    // Pattern 1: "[Author] Title" or "(Author) Title"
    final bracketMatch = RegExp(r'^[\[\(]([^\]\)]+)[\]\)]\s*(.+)$').firstMatch(rawName);
    if (bracketMatch != null) {
      final potentialAuthor = _cleanAuthor(bracketMatch.group(1)!);
      final potentialTitle = _cleanTitle(bracketMatch.group(2)!);
      if (_isValidAuthor(potentialAuthor) && potentialTitle.isNotEmpty) {
        return ParsedMetadataResult(
          title: potentialTitle,
          author: potentialAuthor,
          isConfident: true,
        );
      }
    }

    // Pattern 2: "Author - Title" (or "Author – Title")
    final dashMatch = RegExp(r'^(.+?)\s*[-–—]\s*(.+)$').firstMatch(rawName);
    if (dashMatch != null) {
      final part1 = dashMatch.group(1)!.trim();
      final part2 = dashMatch.group(2)!.trim();

      // Check if part 1 looks like an author name (e.g. 1 to 4 words, no numbers)
      if (_isValidAuthor(part1)) {
        return ParsedMetadataResult(
          title: _cleanTitle(part2),
          author: _cleanAuthor(part1),
          isConfident: true,
        );
      } else if (_isValidAuthor(part2)) {
        // "Title - Author" format
        return ParsedMetadataResult(
          title: _cleanTitle(part1),
          author: _cleanAuthor(part2),
          isConfident: true,
        );
      }
    }

    // Pattern 3: "Title by Author"
    final byMatch = RegExp(r'^(.+?)\s+by\s+(.+)$', caseSensitive: false).firstMatch(rawName);
    if (byMatch != null) {
      final title = byMatch.group(1)!.trim();
      final author = byMatch.group(2)!.trim();
      if (_isValidAuthor(author) && title.isNotEmpty) {
        return ParsedMetadataResult(
          title: _cleanTitle(title),
          author: _cleanAuthor(author),
          isConfident: true,
        );
      }
    }

    // Default clean filename fallback
    return ParsedMetadataResult(
      title: _cleanTitle(rawName),
      author: null,
      isConfident: false,
    );
  }

  /// Extracts metadata from EPUB ZIP archive OPF descriptor.
  ///
  /// Only the central directory, `META-INF/container.xml` and the OPF file are
  /// read, so large EPUBs are never loaded into memory whole.
  static Future<ParsedMetadataResult> _parseEpubMetadata(File file) async {
    final raf = await file.open(mode: FileMode.read);
    try {
      final entries = await EpubZipReader.readCentralDirectory(raf);
      if (entries == null) return parseFromFilename(file.path);

      // 1. Find rootfile from container.xml
      String? opfPath;
      final containerEntry = _findEntry(
        entries,
        (name) => name.toLowerCase() == 'meta-inf/container.xml',
      );
      if (containerEntry != null) {
        final containerXml = await EpubZipReader.readEntryText(raf, containerEntry);
        if (containerXml != null) {
          final match = RegExp(
            r'full-path=["\x27]([^"\x27]+)["\x27]',
            caseSensitive: false,
          ).firstMatch(containerXml);
          if (match != null) opfPath = match.group(1);
        }
      }

      final opfEntry = opfPath != null
          ? _findEntry(entries, (name) => name == opfPath)
          : _findEntry(entries, (name) => name.toLowerCase().endsWith('.opf'));
      if (opfEntry == null) return parseFromFilename(file.path);

      final opfContent = await EpubZipReader.readEntryText(raf, opfEntry);
      if (opfContent == null) return parseFromFilename(file.path);

      String? title;
      final titleMatch = RegExp(
        r'<dc:title[^>]*>([^<]+)</dc:title>',
        caseSensitive: false,
      ).firstMatch(opfContent);
      if (titleMatch != null) {
        title = _cleanTitle(titleMatch.group(1)!.trim());
      }

      String? author;
      final creatorMatch = RegExp(
        r'<dc:creator[^>]*>([^<]+)</dc:creator>',
        caseSensitive: false,
      ).firstMatch(opfContent);
      if (creatorMatch != null) {
        final rawCreator = creatorMatch.group(1)!.trim();
        if (_isValidAuthor(rawCreator)) {
          author = _cleanAuthor(rawCreator);
        }
      }

      if (author != null && author.isNotEmpty) {
        return ParsedMetadataResult(
          title: (title != null && title.isNotEmpty)
              ? title
              : _cleanTitle(p.basenameWithoutExtension(file.path)),
          author: author,
          isConfident: true,
        );
      }

      return parseFromFilename(file.path);
    } finally {
      await raf.close();
    }
  }

  static EpubZipEntry? _findEntry(
    List<EpubZipEntry> entries,
    bool Function(String name) test,
  ) {
    for (final entry in entries) {
      if (test(entry.name)) return entry;
    }
    return null;
  }

  /// Extracts embedded PDF /Author and /Title dictionary tags.
  static Future<ParsedMetadataResult> _parsePdfMetadata(File file) async {
    // Read the first 64KB and last 64KB where PDF info dictionaries live
    final length = await file.length();
    if (length == 0) return parseFromFilename(file.path);

    final readSize = length < 65536 ? length : 65536;
    final raf = await file.open(mode: FileMode.read);
    final headerBytes = await raf.read(readSize);
    List<int> trailerBytes = [];
    if (length > readSize) {
      await raf.setPosition(length - readSize);
      trailerBytes = await raf.read(readSize);
    }
    await raf.close();

    final fullChunk = latin1.decode(headerBytes) + latin1.decode(trailerBytes);

    String? author;
    final authorMatch = RegExp(r'/Author\s*\(([^)\\]*(?:\\.[^)\\]*)*)\)').firstMatch(fullChunk);
    if (authorMatch != null) {
      final raw = _unescapePdfString(authorMatch.group(1)!);
      if (_isValidAuthor(raw)) {
        author = _cleanAuthor(raw);
      }
    }

    String? title;
    final titleMatch = RegExp(r'/Title\s*\(([^)\\]*(?:\\.[^)\\]*)*)\)').firstMatch(fullChunk);
    if (titleMatch != null) {
      final raw = _unescapePdfString(titleMatch.group(1)!);
      if (raw.trim().isNotEmpty && !_isGenericTitle(raw)) {
        title = _cleanTitle(raw);
      }
    }

    if (author != null && author.isNotEmpty) {
      return ParsedMetadataResult(
        title: (title != null && title.isNotEmpty) ? title : _cleanTitle(p.basenameWithoutExtension(file.path)),
        author: author,
        isConfident: true,
      );
    }

    return parseFromFilename(file.path);
  }

  static String _unescapePdfString(String str) {
    return str
        .replaceAll(r'\(', '(')
        .replaceAll(r'\)', ')')
        .replaceAll(r'\\', r'\')
        .replaceAll(r'\r', ' ')
        .replaceAll(r'\n', ' ')
        .trim();
  }

  static bool _isValidAuthor(String author) {
    final lower = author.toLowerCase().trim();
    if (lower.isEmpty || lower.length < 2 || lower.length > 70) return false;
    for (final ignored in _ignoredPdfAuthors) {
      if (lower.contains(ignored)) return false;
    }
    // Shouldn't be purely numbers or file extension
    if (RegExp(r'^\d+$').hasMatch(lower)) return false;
    if (lower.endsWith('.pdf') || lower.endsWith('.epub')) return false;
    return true;
  }

  static bool _isGenericTitle(String title) {
    final lower = title.toLowerCase().trim();
    return lower.contains('untitled') ||
        lower == 'document' ||
        lower.endsWith('.docx') ||
        lower.endsWith('.pdf');
  }

  static String _cleanAuthor(String raw) {
    // If format is "Lastname, Firstname" -> "Firstname Lastname"
    if (raw.contains(',') && !raw.contains('&') && !raw.contains('and')) {
      final parts = raw.split(',');
      if (parts.length == 2) {
        return '${parts[1].trim()} ${parts[0].trim()}';
      }
    }
    return raw.trim();
  }

  static String _cleanTitle(String raw) {
    final cleaned = raw.replaceAll('_', ' ').replaceAll('-', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    if (cleaned.isEmpty) return 'Untitled Document';
    return cleaned.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1);
    }).join(' ');
  }
}
