import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai_provider/data/models/ai_message.dart';
import '../../ai_provider/data/services/chat_client.dart';
import '../../ai_provider/domain/notifiers/active_provider_notifier.dart';
import '../../ai_provider/domain/notifiers/model_switcher_notifier.dart';
import '../../ai_provider/domain/providers.dart';
import '../../rag/controllers/rag_controller.dart';
import '../../rag/data/rag_models.dart';
import '../../rag/data/rag_service.dart';
import '../data/chat_message.dart';

class ChatState {
  final List<ChatMessage> messages;
  final bool isStreaming;
  final String? error;

  /// App book id selected for RAG context (null = generic chat).
  final String? ragBookId;
  final String? ragBookTitle;
  final RagChatMeta? ragMeta;

  const ChatState({
    this.messages = const [],
    this.isStreaming = false,
    this.error,
    this.ragBookId,
    this.ragBookTitle,
    this.ragMeta,
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isStreaming,
    String? error,
    String? ragBookId,
    String? ragBookTitle,
    RagChatMeta? ragMeta,
    bool clearRagMeta = false,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isStreaming: isStreaming ?? this.isStreaming,
      error: error ?? this.error,
      ragBookId: ragBookId ?? this.ragBookId,
      ragBookTitle: ragBookTitle ?? this.ragBookTitle,
      ragMeta: clearRagMeta ? null : (ragMeta ?? this.ragMeta),
    );
  }
}

final chatControllerProvider =
    StateNotifierProvider<ChatController, ChatState>((ref) {
  return ChatController(ref);
});

class ChatController extends StateNotifier<ChatState> {
  ChatController(this._ref) : super(const ChatState());

  final Ref _ref;

  ChatClient get _client => _ref.read(chatClientProvider);
  RagService get _ragService => _ref.read(ragServiceProvider);

  String get _configuredModelId {
    final active = _ref.read(activeProviderProvider).value;
    return active?.chatModelId ?? '';
  }

  void clear() {
    state = const ChatState();
  }

  Future<void> selectRagBook(String? bookId, String? bookTitle) async {
    state = state.copyWith(
      ragBookId: bookId,
      ragBookTitle: bookTitle,
      clearRagMeta: true,
    );
  }

  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.isStreaming) return;

    final active = _ref.read(activeProviderProvider).value;
    final provider = active?.provider;
    if (provider == null || !active!.isConfigured || _configuredModelId.isEmpty) {
      state = state.copyWith(error: 'Configure an AI provider in Settings to chat.');
      return;
    }

    final ragBookId = state.ragBookId;
    if (ragBookId != null) {
      final ragController = _ref.read(ragControllerProvider.notifier);
      await ragController.ensureSession();
      final canRag = _ref.read(ragControllerProvider).canRagFor(ragBookId);
      if (canRag) {
        final backendId = _ref.read(ragControllerProvider).backendBookIdFor(ragBookId)!;
        await _sendWithRag(text, backendId, ragBookId, state.ragBookTitle ?? '');
        return;
      }
    }

    await _sendDirect(trimmed, provider.id);
  }

  Future<void> _sendDirect(String trimmed, String providerId) async {
    final userMsg = ChatMessage(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      role: ChatRole.user,
      content: trimmed,
      timestamp: DateTime.now(),
    );
    final history = [...state.messages, userMsg];
    state = state.copyWith(messages: history, error: null, isStreaming: true, clearRagMeta: true);

    final assistantId = DateTime.now().microsecondsSinceEpoch.toString();
    final assistantMsg = ChatMessage(
      id: assistantId,
      role: ChatRole.assistant,
      content: '',
      timestamp: DateTime.now(),
      isStreaming: true,
    );
    state = state.copyWith(messages: [...history, assistantMsg], isStreaming: true);

    final apiMessages = [
      for (final m in history)
        AIMessage(
          role: m.role == ChatRole.user ? 'user' : 'assistant',
          content: m.content,
        ),
    ];

    var buffer = '';
    try {
      final stream = await _client.streamChat(
        modelId: _configuredModelId,
        providerId: providerId,
        messages: apiMessages,
      );
      await for (final chunk in stream) {
        buffer += chunk;
        state = _patchMessage(assistantId, buffer, isStreaming: true);
      }
      state = _patchMessage(assistantId, buffer, isStreaming: false);
    } on DioException catch (e) {
      if (e.response?.statusCode == 429) {
        final switched = await _handleRateLimitError(assistantId, providerId, buffer);
        if (switched) return;
      }
      final finalContent = buffer.isEmpty ? '⚠️ Failed: $e' : buffer;
      state = ChatState(
        messages: [
          for (final m in state.messages)
            if (m.id == assistantId) m.copyWith(content: finalContent, isStreaming: false) else m,
        ],
        error: buffer.isEmpty ? '$e' : null,
        ragBookId: state.ragBookId,
        ragBookTitle: state.ragBookTitle,
      );
    } catch (e) {
      final finalContent = buffer.isEmpty ? '⚠️ Failed: $e' : buffer;
      state = ChatState(
        messages: [
          for (final m in state.messages)
            if (m.id == assistantId) m.copyWith(content: finalContent, isStreaming: false) else m,
        ],
        error: buffer.isEmpty ? '$e' : null,
        ragBookId: state.ragBookId,
        ragBookTitle: state.ragBookTitle,
      );
    }
  }

  /// Auto-switch path: on 429 the model switcher picks the next available
  /// model from the fallback pool and retries the user message with it.
  Future<bool> _handleRateLimitError(
    String assistantId,
    String providerId,
    String buffer,
  ) async {
    final exhaustedModelId = _configuredModelId;
    final switchedModel = await _ref
        .read(modelSwitcherProvider.notifier)
        .handleRateLimit(
          exhaustedModelId: exhaustedModelId,
          role: ModelRole.chat,
        );
    if (switchedModel == null) return false;

    final userMessages = [
      for (final m in state.messages)
        if (m.role == ChatRole.user)
          AIMessage(role: 'user', content: m.content),
    ];
    try {
      final stream = await _client.streamChat(
        modelId: switchedModel,
        providerId: _ref.read(activeProviderProvider).value?.provider?.id ?? providerId,
        messages: userMessages,
      );
      var retryBuffer = '';
      await for (final chunk in stream) {
        retryBuffer += chunk;
        state = _patchMessage(assistantId, retryBuffer, isStreaming: true);
      }
      state = _patchMessage(assistantId, retryBuffer, isStreaming: false);
      return true;
    } catch (e) {
      final finalContent = buffer.isEmpty ? '⚠️ Failed: $e' : buffer;
      state = ChatState(
        messages: [
          for (final m in state.messages)
            if (m.id == assistantId) m.copyWith(content: finalContent, isStreaming: false) else m,
        ],
        error: buffer.isEmpty ? '$e' : null,
        ragBookId: state.ragBookId,
        ragBookTitle: state.ragBookTitle,
      );
      return true;
    }
  }

  Future<void> _sendWithRag(
    String text,
    String backendBookId,
    String appBookId,
    String bookTitle,
  ) async {
    final userMsg = ChatMessage(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      role: ChatRole.user,
      content: text,
      timestamp: DateTime.now(),
    );
    final history = [...state.messages, userMsg];
    state = state.copyWith(messages: history, error: null, isStreaming: true);

    final assistantId = DateTime.now().microsecondsSinceEpoch.toString();
    final assistantMsg = ChatMessage(
      id: assistantId,
      role: ChatRole.assistant,
      content: '',
      timestamp: DateTime.now(),
      isStreaming: true,
    );
    state = state.copyWith(messages: [...history, assistantMsg], isStreaming: true);

    var buffer = '';
    var meta = RagChatMeta(usedRag: true, bookTitle: bookTitle);
    final statuses = <String>[];
    final citations = <RagCitation>[];
    var retrieved = 0;
    var grounded = true;

    try {
      final providerId = _ref.read(activeProviderProvider).value?.provider?.id;
      final stream = _ragService.streamChat(
        query: text,
        bookIds: [backendBookId],
        sessionId: 'book_$appBookId',
        providerId: providerId,
      );
      await for (final event in stream) {
        switch (event.type) {
          case 'token':
            buffer += event.data as String;
          case 'retrieved':
            retrieved = (event.data as num?)?.toInt() ?? 0;
          case 'status':
            statuses.add(event.data as String);
          case 'provider_used':
            final d = event.data as Map<String, dynamic>;
            final p = d['provider'] as String? ?? '';
            final m = d['model'] as String? ?? '';
            if (p.isNotEmpty) statuses.add('AI: $p · $m');
          case 'done':
            final data = event.data as Map<String, dynamic>;
            grounded = data['grounded'] as bool? ?? true;
            citations
              ..clear()
              ..addAll([
                for (final c in (data['citations'] as List? ?? []))
                  if (c is Map<String, dynamic>) RagCitation.fromJson(c),
              ]);
        }
        state = _patchMessage(assistantId, buffer, isStreaming: true);
      }
      meta = meta.copyWith(retrieved: retrieved, grounded: grounded, statuses: statuses, citations: citations);
      state = ChatState(
        messages: [
          for (final m in state.messages)
            if (m.id == assistantId) m.copyWith(content: buffer, isStreaming: false) else m,
        ],
        ragBookId: state.ragBookId,
        ragBookTitle: state.ragBookTitle,
        ragMeta: meta,
      );
    } catch (e) {
      final finalContent = buffer.isEmpty ? '⚠️ RAG failed: $e' : buffer;
      state = ChatState(
        messages: [
          for (final m in state.messages)
            if (m.id == assistantId) m.copyWith(content: finalContent, isStreaming: false) else m,
        ],
        error: buffer.isEmpty ? '$e' : null,
        ragBookId: state.ragBookId,
        ragBookTitle: state.ragBookTitle,
        ragMeta: meta.copyWith(statuses: [...statuses, '$e']),
      );
    }
  }

  ChatState _patchMessage(String id, String content, {required bool isStreaming}) {
    return state.copyWith(
      messages: [
        for (final m in state.messages)
          if (m.id == id) m.copyWith(content: content, isStreaming: isStreaming) else m,
      ],
      isStreaming: isStreaming,
    );
  }
}
