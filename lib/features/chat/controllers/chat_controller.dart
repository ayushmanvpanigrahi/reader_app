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

  /// Transient message shown once as a snackbar (auto-cleared afterwards).
  final String? notice;

  /// App book id selected for RAG context (null = generic chat).
  final String? ragBookId;
  final String? ragBookTitle;
  final RagChatMeta? ragMeta;

  const ChatState({
    this.messages = const [],
    this.isStreaming = false,
    this.error,
    this.notice,
    this.ragBookId,
    this.ragBookTitle,
    this.ragMeta,
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isStreaming,
    String? error,
    String? notice,
    String? ragBookId,
    String? ragBookTitle,
    RagChatMeta? ragMeta,
    bool clearRagMeta = false,
    bool clearNotice = false,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isStreaming: isStreaming ?? this.isStreaming,
      error: error ?? this.error,
      notice: clearNotice ? null : (notice ?? this.notice),
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

  /// Clears the transient snackbar notice once it has been shown.
  void clearNotice() {
    if (state.notice != null) {
      state = state.copyWith(clearNotice: true);
    }
  }

  Future<void> selectRagBook(String? bookId, String? bookTitle) async {
    state = state.copyWith(
      ragBookId: bookId,
      ragBookTitle: bookTitle,
      clearRagMeta: true,
    );
  }

  bool _sending = false;

  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    // _sending is set synchronously before the first await so a fast
    // double-tap cannot slip two messages through the async isStreaming guard.
    if (trimmed.isEmpty || _sending || state.isStreaming) return;
    _sending = true;
    try {
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
        state = state.copyWith(
          notice:
              '“${state.ragBookTitle ?? 'Selected book'}” is not indexed yet — '
              'answering without book context. Select it in the RAG bar to index it.',
        );
      }

      await _sendDirect(trimmed, provider.id);
    } finally {
      _sending = false;
    }
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
      final friendly = _friendlyDioError(e);
      final finalContent = buffer.isEmpty ? '⚠️ Failed: $friendly' : buffer;
      state = ChatState(
        messages: [
          for (final m in state.messages)
            if (m.id == assistantId) m.copyWith(content: finalContent, isStreaming: false) else m,
        ],
        error: buffer.isEmpty ? friendly : null,
        ragBookId: state.ragBookId,
        ragBookTitle: state.ragBookTitle,
      );
    } catch (e) {
      final friendly = e is DioException ? _friendlyDioError(e) : '$e';
      final finalContent = buffer.isEmpty ? '⚠️ Failed: $friendly' : buffer;
      state = ChatState(
        messages: [
          for (final m in state.messages)
            if (m.id == assistantId) m.copyWith(content: finalContent, isStreaming: false) else m,
        ],
        error: buffer.isEmpty ? friendly : null,
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
      final friendly = e is DioException ? _friendlyDioError(e) : '$e';
      final finalContent = buffer.isEmpty ? '⚠️ Failed: $friendly' : buffer;
      state = ChatState(
        messages: [
          for (final m in state.messages)
            if (m.id == assistantId) m.copyWith(content: finalContent, isStreaming: false) else m,
        ],
        error: buffer.isEmpty ? friendly : null,
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
    String? ragError;

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
          case 'error':
            final d = event.data;
            final msg = d is Map<String, dynamic>
                ? (d['detail']?.toString() ??
                    d['message']?.toString() ??
                    'RAG request failed')
                : d.toString();
            ragError = msg;
            statuses.add('Error: $msg');
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

      final finalContent =
          (buffer.isEmpty && ragError != null) ? '⚠️ $ragError' : buffer;
      state = ChatState(
        messages: [
          for (final m in state.messages)
            if (m.id == assistantId)
              m.copyWith(content: finalContent, isStreaming: false)
            else
              m,
        ],
        error: ragError,
        notice: ragError != null
            ? 'RAG failed: $ragError'
            : state.notice,
        ragBookId: state.ragBookId,
        ragBookTitle: state.ragBookTitle,
        ragMeta: meta,
      );
    } catch (e) {
      final friendly = e is DioException ? _friendlyDioError(e) : '$e';
      final finalContent = buffer.isEmpty ? '⚠️ RAG failed: $friendly' : buffer;
      state = ChatState(
        messages: [
          for (final m in state.messages)
            if (m.id == assistantId) m.copyWith(content: finalContent, isStreaming: false) else m,
        ],
        error: buffer.isEmpty ? friendly : null,
        notice: 'RAG failed: $friendly',
        ragBookId: state.ragBookId,
        ragBookTitle: state.ragBookTitle,
        ragMeta: meta.copyWith(statuses: [...statuses, friendly]),
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

  /// Turns a provider/gateway error into something the user can act on,
  /// extracting the provider's own message (e.g. an invalid model name).
  String _friendlyDioError(DioException e) {
    final resp = e.response;
    if (resp != null) {
      final status = resp.statusCode;
      String? detail;
      final data = resp.data;
      if (data is Map) {
        final error = data['error'];
        if (error is Map) detail = error['message']?.toString();
        detail ??= data['message']?.toString() ?? data['detail']?.toString();
      } else if (data is String && data.trim().isNotEmpty) {
        detail = data.trim();
      }
      if (status == 401) {
        return detail != null
            ? 'API key rejected (HTTP 401): $detail'
            : 'API key rejected (HTTP 401)';
      }
      return detail != null ? 'HTTP $status: $detail' : 'HTTP $status';
    }
    return 'Network error: ${e.message ?? e.type.name}';
  }
}
