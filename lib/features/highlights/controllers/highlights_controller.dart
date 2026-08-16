import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai_provider/data/models/ai_message.dart';
import '../../ai_provider/domain/notifiers/active_provider_notifier.dart';
import '../../ai_provider/domain/notifiers/model_switcher_notifier.dart';
import '../../ai_provider/domain/providers.dart';
import '../../rag/controllers/rag_controller.dart';
import '../../rag/data/rag_service.dart';
import '../data/highlight_model.dart';
import '../data/highlight_storage.dart';
import '../data/text_normalizer.dart';

final highlightStorageProvider = Provider<HighlightStorage>((ref) {
  return HighlightStorage();
});

/// A single message in a follow-up conversation thread.
class ChatMessage {
  final String role; // 'user' or 'assistant'
  final String content;

  const ChatMessage({required this.role, required this.content});

  AIMessage toAiMessage() => AIMessage(role: role, content: content);
}

class HighlightsState {
  final List<HighlightModel> highlights;
  final bool isExplaining;
  final HighlightExplanation? lastExplanation;
  final String? error;

  /// Partial text accumulated while streaming the explanation from the AI.
  /// Non-null only while a streaming response is in flight.
  final String? streamingText;

  /// Full multi-turn conversation thread for the active follow-up session.
  final List<ChatMessage> conversationHistory;

  /// Whether a follow-up request is in flight.
  final bool isFollowingUp;

  const HighlightsState({
    this.highlights = const [],
    this.isExplaining = false,
    this.lastExplanation,
    this.error,
    this.streamingText,
    this.conversationHistory = const [],
    this.isFollowingUp = false,
  });

  HighlightsState copyWith({
    List<HighlightModel>? highlights,
    bool? isExplaining,
    HighlightExplanation? lastExplanation,
    String? error,
    String? streamingText,
    bool clearStreamingText = false,
    List<ChatMessage>? conversationHistory,
    bool? isFollowingUp,
  }) {
    return HighlightsState(
      highlights: highlights ?? this.highlights,
      isExplaining: isExplaining ?? this.isExplaining,
      lastExplanation: lastExplanation ?? this.lastExplanation,
      error: error ?? this.error,
      streamingText: clearStreamingText ? null : (streamingText ?? this.streamingText),
      conversationHistory: conversationHistory ?? this.conversationHistory,
      isFollowingUp: isFollowingUp ?? this.isFollowingUp,
    );
  }
}

final highlightsControllerProvider =
    StateNotifierProvider<HighlightsController, HighlightsState>((ref) {
  return HighlightsController(ref);
});

class HighlightsController extends StateNotifier<HighlightsState> {
  HighlightsController(this._ref) : super(const HighlightsState()) {
    _load();
  }

  final Ref _ref;

  HighlightStorage get _storage => _ref.read(highlightStorageProvider);

  Future<void> _load() async {
    final highlights = await _storage.loadAll();
    state = state.copyWith(highlights: highlights);
  }

  String get _configuredModelId {
    final active = _ref.read(activeProviderProvider).value;
    return active?.chatModelId ?? '';
  }

  /// Kicks off the initial 5-section explanation for a highlight.
  Future<HighlightExplanation?> explain({
    required String bookId,
    required String bookTitle,
    required int pageNumber,
    required String selectedText,
  }) async {
    if (state.isExplaining) return null;

    final active = _ref.read(activeProviderProvider).value;
    final provider = active?.provider;
    final modelId = _configuredModelId;
    if (provider == null || !active!.isConfigured || modelId.isEmpty) {
      state = state.copyWith(error: 'Configure an AI provider in Settings to explain highlights.');
      return null;
    }

    state = state.copyWith(
      isExplaining: true,
      error: null,
      conversationHistory: [],
      streamingText: '',
    );

    final cleanedText = TextNormalizer.clean(selectedText);

    HighlightExplanation? explanation;
    final rag = _ref.read(ragControllerProvider);
    if (rag.enabled && rag.canRagFor(bookId)) {
      await _ref.read(ragControllerProvider.notifier).ensureSession();
      explanation = await _explainWithRag(
        backendBookId: rag.backendBookIdFor(bookId)!,
        pageNumber: pageNumber,
        selectedText: cleanedText,
      );
    }

    if (explanation == null) {
      final prompt = _buildPrompt(cleanedText);
      try {
        final stream = await _ref.read(chatClientProvider).streamChat(
              modelId: modelId,
              providerId: provider.id,
              messages: [
                AIMessage(role: 'system', content: prompt),
              ],
              maxTokens: 800,
            );
        final raw = await _collectStream(stream);
        explanation = parseExplanation(raw);
      } on DioException catch (e) {
        if (e.response?.statusCode == 429) {
          final switched = await _ref
              .read(modelSwitcherProvider.notifier)
              .handleRateLimit(
                exhaustedModelId: modelId,
                role: ModelRole.chat,
              );
          if (switched != null) {
            final currentProviderId =
                _ref.read(activeProviderProvider).value?.provider?.id ?? provider.id;
            final retry = await _retryExplain(currentProviderId, prompt);
            if (retry != null) {
              explanation = retry;
            } else {
              state = state.copyWith(isExplaining: false, error: 'Rate-limited and no fallback succeeded.', clearStreamingText: true);
              return null;
            }
          } else {
            state = state.copyWith(isExplaining: false, error: 'Rate limit exceeded. No fallback model available.', clearStreamingText: true);
            return null;
          }
        } else {
          state = state.copyWith(isExplaining: false, error: '$e', clearStreamingText: true);
          return null;
        }
      } catch (e) {
        state = state.copyWith(isExplaining: false, error: '$e', clearStreamingText: true);
        return null;
      }
      if (explanation == null) {
        state = state.copyWith(
          isExplaining: false,
          error: 'The model returned an unparseable response.',
          clearStreamingText: true,
        );
        return null;
      }
    }

    // Seed the conversation history with the system context and assistant reply.
    final assistantContent = _formatExplanationAsText(explanation);
    state = state.copyWith(
      conversationHistory: [
        ChatMessage(role: 'system', content: _buildFollowUpSystemContext(cleanedText, explanation)),
        ChatMessage(role: 'assistant', content: assistantContent),
      ],
      clearStreamingText: true,
    );

    final highlight = HighlightModel(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      bookId: bookId,
      bookTitle: bookTitle,
      pageNumber: pageNumber,
      selectedText: cleanedText,
      explanation: explanation,
      createdAt: DateTime.now(),
    );
    await _storage.save(highlight);

    final highlights = await _storage.loadAll();
    state = state.copyWith(
      highlights: highlights,
      isExplaining: false,
      lastExplanation: explanation,
    );
    return explanation;
  }

  /// Re-explain with edited/updated text, preserving conversation context.
  Future<void> reExplain({
    required String bookId,
    required String bookTitle,
    required int pageNumber,
    required String selectedText,
  }) async {
    if (state.isExplaining) return;

    final active = _ref.read(activeProviderProvider).value;
    final provider = active?.provider;
    final modelId = _configuredModelId;
    if (provider == null || !active!.isConfigured || modelId.isEmpty) {
      state = state.copyWith(error: 'Configure an AI provider in Settings.');
      return;
    }

    state = state.copyWith(isExplaining: true, error: null, streamingText: '');

    final cleanedText = TextNormalizer.clean(selectedText);
    final prompt = _buildPrompt(cleanedText);

    try {
      final stream = await _ref.read(chatClientProvider).streamChat(
            modelId: modelId,
            providerId: provider.id,
            messages: [AIMessage(role: 'system', content: prompt)],
            maxTokens: 800,
          );
      final raw = await _collectStream(stream);
      final explanation = parseExplanation(raw);
      if (explanation == null) {
        state = state.copyWith(
          isExplaining: false,
          error: 'The model returned an unparseable response.',
          clearStreamingText: true,
        );
        return;
      }

      final assistantContent = _formatExplanationAsText(explanation);
      state = state.copyWith(
        conversationHistory: [
          ChatMessage(role: 'system', content: _buildFollowUpSystemContext(cleanedText, explanation)),
          ChatMessage(role: 'assistant', content: assistantContent),
        ],
        isExplaining: false,
        lastExplanation: explanation,
        clearStreamingText: true,
      );
    } catch (e) {
      state = state.copyWith(isExplaining: false, error: '$e', clearStreamingText: true);
    }
  }

  /// Sends a follow-up question, maintaining full conversation history.
  Future<void> askFollowUp(String question) async {
    if (state.isFollowingUp || question.trim().isEmpty) return;

    final active = _ref.read(activeProviderProvider).value;
    final provider = active?.provider;
    final modelId = _configuredModelId;
    if (provider == null || !active!.isConfigured || modelId.isEmpty) {
      state = state.copyWith(error: 'Configure an AI provider in Settings.');
      return;
    }

    final userMessage = ChatMessage(role: 'user', content: question.trim());
    final updatedHistory = [...state.conversationHistory, userMessage];
    state = state.copyWith(
      conversationHistory: updatedHistory,
      isFollowingUp: true,
      error: null,
      streamingText: '',
    );

    try {
      final stream = await _ref.read(chatClientProvider).streamChat(
            modelId: modelId,
            providerId: provider.id,
            messages: [for (final m in updatedHistory) m.toAiMessage()],
            maxTokens: 800,
          );
      final raw = await _collectStream(stream);

      final aiMessage = ChatMessage(role: 'assistant', content: raw.trim());
      state = state.copyWith(
        conversationHistory: [...updatedHistory, aiMessage],
        isFollowingUp: false,
        clearStreamingText: true,
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 429) {
        final switched = await _ref
            .read(modelSwitcherProvider.notifier)
            .handleRateLimit(
              exhaustedModelId: modelId,
              role: ModelRole.chat,
            );
        if (switched != null) {
          final currentProviderId =
              _ref.read(activeProviderProvider).value?.provider?.id ?? provider.id;
          final retryRaw = await _retryFollowUp(currentProviderId, updatedHistory);
          if (retryRaw != null) {
            final aiMessage = ChatMessage(role: 'assistant', content: retryRaw.trim());
            state = state.copyWith(
              conversationHistory: [...state.conversationHistory, aiMessage],
              isFollowingUp: false,
              clearStreamingText: true,
            );
            return;
          }
        }
        state = state.copyWith(
          isFollowingUp: false,
          error: 'Rate-limited. Try again shortly.',
          clearStreamingText: true,
        );
      } else {
        state = state.copyWith(isFollowingUp: false, error: '$e', clearStreamingText: true);
      }
    } catch (e) {
      state = state.copyWith(isFollowingUp: false, error: '$e', clearStreamingText: true);
    }
  }

  Future<String?> _retryFollowUp(String providerId, List<ChatMessage> history) async {
    try {
      final modelId = _configuredModelId;
      if (modelId.isEmpty) return null;
      return await _ref.read(chatClientProvider).completeChat(
            modelId: modelId,
            providerId: providerId,
            messages: [for (final m in history) m.toAiMessage()],
            maxTokens: 800,
          );
    } catch (e, stack) {
      debugPrint('[HighlightsController] _retryFollowUp failed: $e\n$stack');
      return null;
    }
  }

  Future<void> remove(String id) async {
    await _storage.remove(id);
    final highlights = await _storage.loadAll();
    state = state.copyWith(highlights: highlights);
  }

  Future<void> clearBook(String bookId) async {
    await _storage.clearBook(bookId);
    final highlights = await _storage.loadAll();
    state = state.copyWith(highlights: highlights);
  }

  /// Clears the active conversation thread.
  void clearConversation() {
    state = state.copyWith(conversationHistory: []);
  }

  /// Collects a streaming response into a single string, updating
  /// `streamingText` in state so the UI can render tokens progressively.
  Future<String> _collectStream(Stream<String> stream) async {
    final buffer = StringBuffer();
    await for (final token in stream) {
      buffer.write(token);
      state = state.copyWith(streamingText: buffer.toString());
    }
    return buffer.toString();
  }

  // ─── Prompt & Parser ──────────────────────────────────────────────

  /// Detects if text appears to be raw 8-bit glyph codes or legacy font encoding
  /// (e.g. KrutiDev, Chanakya, Walkman, or custom Devanagari fonts).
  @visibleForTesting
  static bool isLikelyGarbled(String text) {
    if (text.trim().isEmpty) return false;
    var specialCount = 0;
    final len = text.length;
    for (var i = 0; i < len; i++) {
      final c = text.codeUnitAt(i);
      if (c > 127 ||
          c == 0x3C || c == 0x3E || // < >
          c == 0x2A || c == 0x26 || // * &
          c == 0x40 || c == 0x23 || // @ #
          c == 0x5E || c == 0x7E || // ^ ~
          c == 0x28 || c == 0x29 || // ( )
          c == 0x5B || c == 0x5D || // [ ]
          c == 0x7B || c == 0x7D || // { }
          c == 0x7C || c == 0x5C || // | \
          c == 0x60 ||              // `
          c == 0x22) {             // "
        specialCount++;
      }
    }
    return (specialCount / len) > 0.10;
  }

  String _buildPrompt(String selectedText) {
    final garbled = isLikelyGarbled(selectedText);
    final buffer = StringBuffer();
    buffer.writeln('You are an expert reading companion that explains a highlighted passage from a book.');

    if (garbled) {
      buffer.writeln(
        '\n[NOTE ON TEXT ENCODING]:\n'
        'The selected text below was extracted from a PDF that uses legacy 8-bit font encoding '
        '(such as Sanskrit / Hindi / Devanagari KrutiDev, Chanakya, Walkman, or DV-Surekh font). '
        'The characters appear as garbled ASCII (e.g. "TaÀ Sa&SMa*TYa" for "tach cha saṁsmṛtya"). '
        'Using your knowledge of Indian scriptures and literature (like Bhagavad Gita, Upanishads, etc.), '
        'verse markers, numbers (e.g. 77 -> Gita 18.77), and phonetic patterns, identify what this '
        'passage/verse actually is, restore its authentic text, and provide the 5-part explanation '
        'based on the deciphered passage.\n',
      );
    }

    buffer.writeln(
      'Explain the following selected passage in a simple, easy-to-understand way for a learner.\n\n'
      'Selected passage:\n"""\n$selectedText\n"""\n\n'
      'Return your answer using EXACTLY these five labeled sections, one section per line:\n'
      'SIMPLE_MEANING: <one-sentence plain-English meaning>\n'
      'AUTHOR_CONTEXT: <why the author likely wrote this and the tone or intent>\n'
      'REFLECTION_QUESTION: <one open-ended question to help the reader connect it to their own life>\n'
      'ANALOGY: <a vivid everyday analogy that makes the idea click>\n'
      'TAKEAWAY: <one memorable takeaway sentence>',
    );
    return buffer.toString();
  }

  /// Builds a system context message that seeds the follow-up conversation
  /// with full knowledge of the passage and the 5-part explanation.
  String _buildFollowUpSystemContext(String passage, HighlightExplanation explanation) {
    return 'You are a reading companion. The user selected this passage:\n'
        '"""\n$passage\n"""\n\n'
        'You explained it with these 5 sections:\n'
        '- Simple Meaning: ${explanation.simpleMeaning}\n'
        '- Author\'s Context: ${explanation.authorContext}\n'
        '- Reflection Question: ${explanation.reflectionQuestion}\n'
        '- Analogy: ${explanation.analogy}\n'
        '- Key Takeaway: ${explanation.takeaway}\n\n'
        'Now the user is asking follow-up questions. Answer helpfully, '
        'maintaining full context of the original passage and your explanation. '
        'Keep answers concise unless the user asks for detail.';
  }

  /// Formats the 5-part explanation into a readable string for the
  /// conversation history.
  String _formatExplanationAsText(HighlightExplanation e) {
    return 'Simple Meaning: ${e.simpleMeaning}\n'
        'Author\'s Context: ${e.authorContext}\n'
        'Reflection: ${e.reflectionQuestion}\n'
        'Analogy: ${e.analogy}\n'
        'Takeaway: ${e.takeaway}';
  }

  Future<HighlightExplanation?> _explainWithRag({
    required String backendBookId,
    required int pageNumber,
    required String selectedText,
  }) async {
    try {
      final providerId = _ref.read(activeProviderProvider).value?.provider?.id;
      final stream = _ragService.streamExplainHighlight(
        selectedText: selectedText,
        bookId: backendBookId,
        chapter: 'Page $pageNumber',
        providerId: providerId,
      );
      HighlightExplanation? parsed;
      await for (final event in stream) {
        switch (event.type) {
          case 'token':
            break;
          case 'done':
            final data = event.data as Map<String, dynamic>;
            final h = data['highlight'] as Map<String, dynamic>? ?? const {};
            final anchor = h['memory_anchor'] as Map<String, dynamic>? ?? const {};
            parsed = HighlightExplanation(
              simpleMeaning: h['simple_meaning'] as String? ?? '',
              authorContext: h['author_context'] as String? ?? '',
              reflectionQuestion: anchor['reflection_question'] as String? ?? '',
              analogy: anchor['analogy'] as String? ?? '',
              takeaway: anchor['takeaway'] as String? ?? '',
            );
          case 'error':
            throw Exception(event.data);
        }
      }
      if (parsed != null && parsed.simpleMeaning.isNotEmpty) return parsed;
      return null;
    } catch (e, stack) {
      debugPrint('[HighlightsController] _parseExplain failed: $e\n$stack');
      return null;
    }
  }

  RagService get _ragService => _ref.read(ragServiceProvider);

  Future<HighlightExplanation?> _retryExplain(String providerId, String prompt) async {
    try {
      final modelId = _configuredModelId;
      if (modelId.isEmpty) return null;
      final raw = await _ref.read(chatClientProvider).completeChat(
            modelId: modelId,
            providerId: providerId,
            messages: [
              AIMessage(role: 'system', content: prompt),
            ],
            maxTokens: 800,
          );
      return parseExplanation(raw);
    } catch (e, stack) {
      debugPrint('[HighlightsController] _retryExplain failed: $e\n$stack');
      return null;
    }
  }

  /// Robust multi-line parser that handles markdown prefixes (**LABEL:**),
  /// heading-style labels (### LABEL), multi-line paragraph bodies, and
  /// conversational fallbacks.
  ///
  /// Returns null only when fewer than 3 of the 5 sections are found.
  @visibleForTesting
  static HighlightExplanation? parseExplanation(String raw) {
    final sections = <String, String>{};

    // Normalize: strip common markdown bold/italic wrappers around labels.
    var text = raw.replaceAll(RegExp(r'\*{1,3}'), '');

    // Match patterns like:
    //   SIMPLE_MEANING: text
    //   SIMPLE_MEANING: text (continues on next line until next label)
    //   ### SIMPLE_MEANING: text
    final labelPattern = RegExp(
      r'^(?:###?\s*)?(SIMPLE_MEANING|AUTHOR_CONTEXT|REFLECTION_QUESTION|ANALOGY|TAKEAWAY)\s*:\s*',
      caseSensitive: false,
      multiLine: true,
    );

    final matches = labelPattern.allMatches(text).toList();

    for (var i = 0; i < matches.length; i++) {
      final match = matches[i];
      final label = match.group(1)!.toUpperCase();
      final startIdx = match.end;

      // The body extends from after this label to the start of the next label
      // (or end of string).
      final endIdx = i + 1 < matches.length ? matches[i + 1].start : text.length;
      final body = text.substring(startIdx, endIdx).trim();

      // Clean up: remove trailing "---" or "===" separators.
      final cleaned = body
          .replaceAll(RegExp(r'\n[-=]{3,}\s*$'), '')
          .replaceAll(RegExp(r'\n{3,}'), '\n\n')
          .trim();

      if (cleaned.isNotEmpty) {
        sections[label] = cleaned;
      }
    }

    // Fallback: if no labels matched at all, try to split the response
    // into rough paragraphs and assign them in order.
    if (sections.isEmpty) {
      final labels = [
        'SIMPLE_MEANING',
        'AUTHOR_CONTEXT',
        'REFLECTION_QUESTION',
        'ANALOGY',
        'TAKEAWAY',
      ];
      final paragraphs = text
          .split(RegExp(r'\n{2,}'))
          .map((p) => p.trim())
          .where((p) => p.isNotEmpty)
          .toList();

      for (var i = 0; i < paragraphs.length && i < labels.length; i++) {
        sections[labels[i]] = paragraphs[i];
      }
    }

    if (sections.length < 3) return null;

    return HighlightExplanation(
      simpleMeaning: sections['SIMPLE_MEANING'] ?? '',
      authorContext: sections['AUTHOR_CONTEXT'] ?? '',
      reflectionQuestion: sections['REFLECTION_QUESTION'] ?? '',
      analogy: sections['ANALOGY'] ?? '',
      takeaway: sections['TAKEAWAY'] ?? '',
    );
  }
}
