import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai_provider/data/models/ai_message.dart';
import '../../ai_provider/domain/notifiers/active_provider_notifier.dart';
import '../../ai_provider/domain/notifiers/model_switcher_notifier.dart';
import '../../ai_provider/domain/providers.dart';
import '../../rag/controllers/rag_controller.dart';
import '../../rag/data/rag_service.dart';
import '../data/highlight_model.dart';
import '../data/highlight_storage.dart';

final highlightStorageProvider = Provider<HighlightStorage>((ref) {
  return HighlightStorage();
});

class HighlightsState {
  final List<HighlightModel> highlights;
  final bool isExplaining;
  final HighlightExplanation? lastExplanation;
  final String? error;

  const HighlightsState({
    this.highlights = const [],
    this.isExplaining = false,
    this.lastExplanation,
    this.error,
  });

  HighlightsState copyWith({
    List<HighlightModel>? highlights,
    bool? isExplaining,
    HighlightExplanation? lastExplanation,
    String? error,
  }) {
    return HighlightsState(
      highlights: highlights ?? this.highlights,
      isExplaining: isExplaining ?? this.isExplaining,
      lastExplanation: lastExplanation ?? this.lastExplanation,
      error: error ?? this.error,
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

    state = state.copyWith(isExplaining: true, error: null);

    HighlightExplanation? explanation;
    final rag = _ref.read(ragControllerProvider);
    if (rag.enabled && rag.canRagFor(bookId)) {
      await _ref.read(ragControllerProvider.notifier).ensureSession();
      explanation = await _explainWithRag(
        backendBookId: rag.backendBookIdFor(bookId)!,
        pageNumber: pageNumber,
        selectedText: selectedText,
      );
    }

    if (explanation == null) {
      final prompt = _buildPrompt(selectedText);
      try {
        final raw = await _ref.read(chatClientProvider).completeChat(
              modelId: modelId,
              providerId: provider.id,
              messages: [
                AIMessage(role: 'system', content: prompt),
              ],
              maxTokens: 600,
            );
        explanation = _parseExplanation(raw);
      } on DioException catch (e) {
        if (e.response?.statusCode == 429) {
          final switched = await _ref
              .read(modelSwitcherProvider.notifier)
              .handleRateLimit(
                exhaustedModelId: modelId,
                role: ModelRole.chat,
              );
          if (switched != null) {
            final retry = await _retryExplain(provider.id, prompt);
            if (retry != null) {
              explanation = retry;
            } else {
              state = state.copyWith(isExplaining: false, error: 'Rate-limited and no fallback succeeded.');
              return null;
            }
          } else {
            state = state.copyWith(isExplaining: false, error: 'Rate limit exceeded. No fallback model available.');
            return null;
          }
        } else {
          state = state.copyWith(isExplaining: false, error: '$e');
          return null;
        }
      } catch (e) {
        state = state.copyWith(isExplaining: false, error: '$e');
        return null;
      }
      if (explanation == null) {
        state = state.copyWith(
          isExplaining: false,
          error: 'The model returned an unparseable response.',
        );
        return null;
      }
    }

    final highlight = HighlightModel(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      bookId: bookId,
      bookTitle: bookTitle,
      pageNumber: pageNumber,
      selectedText: selectedText.trim(),
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
    } catch (_) {
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
            maxTokens: 600,
          );
      return _parseExplanation(raw);
    } catch (_) {
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

  String _buildPrompt(String selectedText) {
    return 'You are a reading companion that explains a highlighted passage from a book. '
        'Explain the following selected passage in a simple, easy-to-understand way for a learner.\n\n'
        'Selected passage:\n"""\n$selectedText\n"""\n\n'
        'Return your answer using EXACTLY these five labeled sections, one section per line:\n'
        'SIMPLE_MEANING: <one-sentence plain-English meaning>\n'
        'AUTHOR_CONTEXT: <why the author likely wrote this and the tone or intent>\n'
        'REFLECTION_QUESTION: <one open-ended question to help the reader connect it to their own life>\n'
        'ANALOGY: <a vivid everyday analogy that makes the idea click>\n'
        'TAKEAWAY: <one memorable takeaway sentence>';
  }

  HighlightExplanation? _parseExplanation(String raw) {
    final sections = <String, String>{};
    final lines = raw.split('\n');
    for (final line in lines) {
      for (final label in const [
        'SIMPLE_MEANING',
        'AUTHOR_CONTEXT',
        'REFLECTION_QUESTION',
        'ANALOGY',
        'TAKEAWAY',
      ]) {
        if (line.trim().startsWith('$label:')) {
          sections[label] = line.trim().substring(label.length + 1).trim();
        }
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
