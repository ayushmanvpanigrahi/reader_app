import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../../ai_provider/data/models/ai_message.dart';
import '../../../ai_provider/domain/notifiers/active_provider_notifier.dart';
import '../../../ai_provider/domain/providers.dart';
import '../local_storage_service.dart';
import '../models/book_model.dart';
import '../parsers/epub_zip_reader.dart';
import '../../controllers/library_controller.dart';

final bookEnrichmentServiceProvider = Provider<BookEnrichmentService>((ref) {
  return BookEnrichmentService(ref);
});

class BookEnrichmentService {
  final Ref _ref;
  final List<BookModel> _queue = [];
  final Map<String, int> _retryCounts = {};
  String? _currentlyProcessingId;
  bool _isWorkerRunning = false;

  BookEnrichmentService(this._ref);

  LocalStorageService get _storage => _ref.read(localStorageServiceProvider);

  /// Enqueues a book for background metadata enrichment.
  /// Skips if already enriching, completed, failed, or already queued.
  void enqueue(BookModel book) {
    if (book.enrichmentStatus != EnrichmentStatus.pending) {
      return;
    }
    if (_currentlyProcessingId == book.id || _queue.any((b) => b.id == book.id)) {
      return;
    }

    _queue.add(book);
    _processNext();
  }

  Future<void> _processNext() async {
    if (_isWorkerRunning || _queue.isEmpty) {
      return;
    }

    _isWorkerRunning = true;
    final book = _queue.removeAt(0);
    _currentlyProcessingId = book.id;

    try {
      await _enrichBook(book);
    } catch (e, stack) {
      debugPrint('[BookEnrichment] Enrichment error for ${book.title}: $e\n$stack');
      await _handleFailure(book);
    } finally {
      _currentlyProcessingId = null;
      _isWorkerRunning = false;
      if (_queue.isNotEmpty) {
        // Small cooldown between sequential items to prevent burst load
        Future.delayed(const Duration(milliseconds: 500), _processNext);
      }
    }
  }

  Future<void> _enrichBook(BookModel book) async {
    final active = _ref.read(activeProviderProvider).value;
    final provider = active?.provider;
    final modelId = active?.chatModelId;

    if (provider == null || !active!.isConfigured || modelId == null || modelId.isEmpty) {
      // AI provider not configured yet. Leave pending so it can be enriched later.
      return;
    }

    if (book.filePath.isEmpty || !File(book.filePath).existsSync()) {
      await _markStatus(book, EnrichmentStatus.failed);
      return;
    }

    // Mark as currently enriching
    await _markStatus(book, EnrichmentStatus.enriching);

    // 1. Extract introductory text from the first 1-2 pages
    final introText = await _extractIntroductoryText(book);
    if (introText.trim().isEmpty) {
      await _markStatus(book, EnrichmentStatus.completed);
      return;
    }

    // 2. Query AI with structured prompt
    final prompt = _buildPrompt(introText, book.title);
    final response = await _ref.read(chatClientProvider).completeChat(
          modelId: modelId,
          providerId: provider.id,
          messages: [
            AIMessage(role: 'system', content: prompt),
          ],
          maxTokens: 180,
        );

    final parsed = _parseAiResponse(response);
    if (parsed != null && parsed.author.isNotEmpty && parsed.author != 'Unknown Author') {
      final updatedBook = book.copyWith(
        title: parsed.title.isNotEmpty ? parsed.title : book.title,
        author: parsed.author,
        enrichmentStatus: EnrichmentStatus.completed,
      );
      await _storage.saveBook(updatedBook);
      _ref.read(libraryControllerProvider.notifier).updateBookInState(updatedBook);
      _retryCounts.remove(book.id);
    } else {
      await _markStatus(book, EnrichmentStatus.completed);
    }
  }

  Future<void> _handleFailure(BookModel book) async {
    final currentRetries = _retryCounts[book.id] ?? 0;
    if (currentRetries < 2) {
      _retryCounts[book.id] = currentRetries + 1;
      // Mark back to pending and schedule retry after 30 seconds
      await _markStatus(book, EnrichmentStatus.pending);
      Timer(const Duration(seconds: 30), () {
        enqueue(book);
      });
    } else {
      _retryCounts.remove(book.id);
      await _markStatus(book, EnrichmentStatus.failed);
    }
  }

  Future<void> _markStatus(BookModel book, EnrichmentStatus status) async {
    final updated = book.copyWith(enrichmentStatus: status);
    await _storage.saveBook(updated);
    _ref.read(libraryControllerProvider.notifier).updateBookInState(updated);
  }

  Future<String> _extractIntroductoryText(BookModel book) async {
    try {
      if (book.isPdf) {
        final doc = await PdfDocument.openFile(book.filePath);
        try {
          final pageCount = doc.pages.length;
          final buffer = StringBuffer();
          final maxPages = min(2, pageCount);
          for (var i = 1; i <= maxPages; i++) {
            final page = doc.pages[i - 1];
            final text = await page.loadText();
            if (text != null && text.fullText.isNotEmpty) {
              buffer.writeln(text.fullText);
            }
          }
          final full = buffer.toString().trim();
          return full.length > 2000 ? full.substring(0, 2000) : full;
        } finally {
          await doc.dispose();
        }
      } else {
        // EPUB: Read only the HTML/XHTML entries via the central directory,
        // without loading the whole archive into memory.
        final raf = await File(book.filePath).open(mode: FileMode.read);
        try {
          final entries = await EpubZipReader.readCentralDirectory(raf);
          if (entries == null) return '';
          final buffer = StringBuffer();
          for (final entry in entries) {
            final lower = entry.name.toLowerCase();
            if (!lower.endsWith('.html') &&
                !lower.endsWith('.xhtml') &&
                !lower.endsWith('.htm')) {
              continue;
            }
            final content = await EpubZipReader.readEntryText(raf, entry);
            if (content == null) continue;
            // Simple HTML tag strip
            final clean = content
                .replaceAll(RegExp(r'<[^>]*>'), ' ')
                .replaceAll(RegExp(r'\s+'), ' ')
                .trim();
            if (clean.isEmpty) continue;
            buffer.writeln(clean);
            if (buffer.length > 1500) break;
          }
          final full = buffer.toString().trim();
          return full.length > 2000 ? full.substring(0, 2000) : full;
        } finally {
          await raf.close();
        }
      }
    } catch (e) {
      debugPrint('[BookEnrichment] Text extraction failed: $e');
      return '';
    }
  }

  String _buildPrompt(String sampleText, String currentTitle) {
    return 'You are an expert document cataloging engine.\n'
        'Analyze the following text extracted from the title/introductory pages of a document.\n'
        'Identify the actual Book Title and the Author Name.\n\n'
        'Fallback Title Hint: "$currentTitle"\n\n'
        'Document Text:\n"""\n$sampleText\n"""\n\n'
        'Respond STRICTLY in valid JSON format only, with no other words or markdown wrappers:\n'
        '{"title": "Accurate Book Title", "author": "Author Name"}\n'
        'If the author name cannot be determined, set "author" to "Unknown Author".';
  }

  ({String title, String author})? _parseAiResponse(String raw) {
    try {
      var clean = raw.trim();
      if (clean.startsWith('```json')) {
        clean = clean.substring(7);
      }
      if (clean.startsWith('```')) {
        clean = clean.substring(3);
      }
      if (clean.endsWith('```')) {
        clean = clean.substring(0, clean.length - 3);
      }
      clean = clean.trim();

      final decoded = json.decode(clean) as Map<String, dynamic>;
      final title = (decoded['title'] as String?)?.trim() ?? '';
      final author = (decoded['author'] as String?)?.trim() ?? '';
      return (title: title, author: author);
    } catch (_) {
      return null;
    }
  }
}
