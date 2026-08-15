import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_config.dart';
import '../../ai_provider/domain/providers.dart';
import '../../library/data/models/book_model.dart';
import '../data/rag_models.dart';
import '../data/rag_service.dart';
import '../data/rag_store.dart';

final ragStoreProvider = Provider<RagStore>(
  (ref) => throw UnimplementedError('Override ragStoreProvider in main'),
);

final ragServiceProvider = Provider<RagService>((ref) {
  return RagService(ref.watch(ragStoreProvider));
});

class RagState {
  final bool enabled;
  final String baseUrl;
  final bool connected;
  final bool checking;
  final Map<String, RagBookIndex> books;
  final String? error;

  const RagState({
    this.enabled = false,
    this.baseUrl = kBackendBaseUrl,
    this.connected = false,
    this.checking = false,
    this.books = const {},
    this.error,
  });

  RagState copyWith({
    bool? enabled,
    String? baseUrl,
    bool? connected,
    bool? checking,
    Map<String, RagBookIndex>? books,
    String? error,
  }) {
    return RagState(
      enabled: enabled ?? this.enabled,
      baseUrl: baseUrl ?? this.baseUrl,
      connected: connected ?? this.connected,
      checking: checking ?? this.checking,
      books: books ?? this.books,
      error: error ?? this.error,
    );
  }

  RagBookIndex indexFor(String appBookId) {
    return books[appBookId] ?? const RagBookIndex();
  }

  String? backendBookIdFor(String appBookId) {
    final idx = indexFor(appBookId);
    return idx.status == RagBookStatus.completed ? idx.backendBookId : null;
  }

  bool canRagFor(String appBookId) {
    return enabled && connected && backendBookIdFor(appBookId) != null;
  }
}

final ragControllerProvider =
    StateNotifierProvider<RagController, RagState>((ref) {
  return RagController(ref);
});

class RagController extends StateNotifier<RagState> {
  RagController(this._ref) : super(const RagState()) {
    _init();
  }

  final Ref _ref;

  RagStore get _store => _ref.read(ragStoreProvider);
  RagService get _service => _ref.read(ragServiceProvider);

  void _init() {
    final config = _store.getConfig();
    final indexed = _store.getBookIds();
    state = state.copyWith(
      enabled: config.enabled,
      baseUrl: config.baseUrl,
      books: {
        for (final entry in indexed.entries)
          entry.key: RagBookIndex(
            status: RagBookStatus.completed,
            backendBookId: entry.value,
          ),
      },
    );
  }

  Future<void> updateConfig({bool? enabled, String? baseUrl}) async {
    final next = state.copyWith(
      enabled: enabled ?? state.enabled,
      baseUrl: baseUrl ?? state.baseUrl,
    );
    await _store.setConfig(RagConfig(enabled: next.enabled, baseUrl: next.baseUrl));
    state = state.copyWith(enabled: next.enabled, baseUrl: next.baseUrl);
  }

  Future<void> testConnection() async {
    state = state.copyWith(checking: true, error: null);
    final ok = await _service.health();
    state = state.copyWith(
      checking: false,
      connected: ok,
      error: ok ? null : 'Cannot reach backend at ${state.baseUrl}',
    );
    if (ok) await syncProviders();
  }

  /// Push every provider configured in the app (base URL + key + selected
  /// chat/embedding model) to the backend so server-side RAG uses the same
  /// providers and can auto-switch when a free plan is exhausted.
  Future<void> syncProviders() async {
    if (!state.connected) return;
    final repo = _ref.read(providerRepositoryProvider);
    final providers = <RagProvider>[];
    for (final p in repo.all()) {
      final key = await repo.apiKey(p.id);
      providers.add(
        RagProvider(
          id: p.id,
          name: p.displayName,
          baseUrl: p.baseUrl,
          apiKey: key ?? '',
          chatModel: p.activeChatModelId,
          embeddingModel: p.activeEmbeddingModelId,
          priority: p.isActive ? 0 : 1,
        ),
      );
    }
    try {
      await _service.syncProviders(providers);
    } catch (_) {
      // Non-fatal: backend falls back to its server-side provider settings.
    }
  }

  Future<void> ensureSession() async {
    if (state.connected) {
      return;
    }
    final ok = await _service.health();
    if (!ok) {
      state = state.copyWith(connected: false, error: 'RAG backend unreachable. Start it with `runapp`.');
      return;
    }
    try {
      await _service.health();
      state = state.copyWith(connected: true, error: null);
      await syncProviders();
    } catch (_) {
      state = state.copyWith(connected: false, error: 'RAG session failed.');
    }
  }

  RagBookIndex indexFor(String appBookId) {
    return state.books[appBookId] ?? const RagBookIndex();
  }

  String? backendBookIdFor(String appBookId) {
    final idx = state.books[appBookId];
    if (idx?.status != RagBookStatus.completed) return null;
    return idx?.backendBookId ?? _store.backendBookIdFor(appBookId);
  }

  bool canRagFor(String appBookId) {
    return state.enabled && state.connected && backendBookIdFor(appBookId) != null;
  }

  Future<void> ingestBook(BookModel book) async {
    if (!state.enabled) return;
    final existing = state.books[book.id];
    if (existing?.status == RagBookStatus.completed || existing?.status == RagBookStatus.ingesting) {
      return;
    }
    if (book.filePath.isEmpty || !File(book.filePath).existsSync()) return;

    await ensureSession();
    if (!state.connected) return;

    state = state.copyWith(
      books: {
        ...state.books,
        book.id: const RagBookIndex(status: RagBookStatus.ingesting, progress: 0.05),
      },
    );

    try {
      final filename = book.filePath.split(RegExp(r'[\\/]')).last;
      final activeProviderId = _ref
          .read(providerRepositoryProvider)
          .activeProviderId();
      final result = await _service.ingestFile(
        filePath: book.filePath,
        filename: filename,
        title: book.title,
        author: book.author,
        providerId: activeProviderId,
      );
      final taskId = result['task_id'] as String;
      await _pollIngest(book.id, taskId);
    } catch (e) {
      state = state.copyWith(
        books: {
          ...state.books,
          book.id: RagBookIndex(status: RagBookStatus.failed, error: '$e'),
        },
      );
    }
  }

  Future<void> _pollIngest(String appBookId, String taskId) async {
    for (var attempt = 0; attempt < 240; attempt++) {
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      try {
        final status = await _service.ingestStatus(taskId);
        final taskStatus = status['status'] as String? ?? 'queued';
        final progress = (status['progress'] as num?)?.toDouble() ?? 0;
        final backendId = status['book_id'] as String?;

        if (taskStatus == 'completed' && backendId != null) {
          await _store.setBackendBookId(appBookId, backendId);
          state = state.copyWith(
            books: {
              ...state.books,
              appBookId: RagBookIndex(
                status: RagBookStatus.completed,
                backendBookId: backendId,
                progress: 1,
              ),
            },
          );
          return;
        }
        if (taskStatus == 'failed') {
          state = state.copyWith(
            books: {
              ...state.books,
              appBookId: RagBookIndex(
                status: RagBookStatus.failed,
                error: status['error'] as String?,
              ),
            },
          );
          return;
        }
        state = state.copyWith(
          books: {
            ...state.books,
            appBookId: RagBookIndex(
              status: RagBookStatus.ingesting,
              progress: progress,
            ),
          },
        );
      } catch (_) {
        // transient polling error — keep waiting
      }
    }
    state = state.copyWith(
      books: {
        ...state.books,
        appBookId: RagBookIndex(status: RagBookStatus.failed, error: 'Ingest timed out.'),
      },
    );
  }
}
