import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';
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
  final RagHealth? lastHealth;
  final DateTime? lastCheckedAt;
  final List<Map<String, dynamic>> backendBooks;

  const RagState({
    this.enabled = false,
    this.baseUrl = kBackendBaseUrl,
    this.connected = false,
    this.checking = false,
    this.books = const {},
    this.error,
    this.lastHealth,
    this.lastCheckedAt,
    this.backendBooks = const [],
  });

  int get indexedCount =>
      books.values.where((b) => b.status == RagBookStatus.completed).length;

  RagState copyWith({
    bool? enabled,
    String? baseUrl,
    bool? connected,
    bool? checking,
    Map<String, RagBookIndex>? books,
    String? error,
    RagHealth? lastHealth,
    DateTime? lastCheckedAt,
    List<Map<String, dynamic>>? backendBooks,
    bool clearError = false,
  }) {
    return RagState(
      enabled: enabled ?? this.enabled,
      baseUrl: baseUrl ?? this.baseUrl,
      connected: connected ?? this.connected,
      checking: checking ?? this.checking,
      books: books ?? this.books,
      error: clearError ? null : (error ?? this.error),
      lastHealth: lastHealth ?? this.lastHealth,
      lastCheckedAt: lastCheckedAt ?? this.lastCheckedAt,
      backendBooks: backendBooks ?? this.backendBooks,
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
    state = state.copyWith(
      enabled: next.enabled,
      baseUrl: next.baseUrl,
      error: next.enabled ? state.error : null,
      connected: next.enabled ? state.connected : false,
    );
  }

  /// Enables/disables RAG. Turning it on re-tests the backend connection.
  Future<void> setRagEnabled(bool enabled) async {
    await updateConfig(enabled: enabled);
    if (enabled) {
      await testConnection();
    }
  }

  Future<void> testConnection() async {
    state = state.copyWith(checking: true, clearError: true);
    final health = await _service.healthDetail();
    state = state.copyWith(
      checking: false,
      connected: health.ok,
      lastHealth: health,
      lastCheckedAt: DateTime.now(),
      error: health.ok ? null : health.error,
    );
    if (health.ok) {
      await syncProviders();
      await refreshIndexStatus();
    }
  }

  /// Fetches server-side indexed books and merges them with local tracking so
  /// the UI can always confirm exactly which books have been indexed.
  Future<void> refreshIndexStatus() async {
    if (!state.connected) return;
    try {
      final serverBooks = await _service.listIndexedBooks();
      final merged = Map<String, RagBookIndex>.from(state.books);
      for (final book in serverBooks) {
        final backendId = (book['book_id'] as String?) ?? '';
        if (backendId.isEmpty) continue;
        final existing =
            merged.entries.where((e) => e.value.backendBookId == backendId).toList();
        if (existing.isEmpty) {
          // Indexed on the server but not tracked locally yet.
          merged[backendId] = RagBookIndex(
            status: RagBookStatus.completed,
            backendBookId: backendId,
            progress: 1,
          );
        }
      }
      state = state.copyWith(backendBooks: serverBooks, books: merged);
    } catch (_) {
      // Non-fatal: local book mapping still works.
    }
  }

  /// Re-runs ingestion for a book that previously failed or was never indexed.
  Future<void> retryIngest(BookModel book) async {
    await ensureSession();
    if (!state.connected) {
      state = state.copyWith(error: 'Backend unreachable — cannot re-index.');
      return;
    }
    await ingestBook(book, force: true);
  }

  Future<void> ensureSession() async {
    if (state.connected) {
      return;
    }
    final health = await _service.healthDetail();
    if (!health.ok) {
      state = state.copyWith(
        connected: false,
        lastHealth: health,
        lastCheckedAt: DateTime.now(),
        error: health.error ?? 'RAG backend unreachable. Start it with `runapp`.',
      );
      return;
    }
    try {
      state = state.copyWith(connected: true, lastHealth: health, lastCheckedAt: DateTime.now(), error: null);
      await syncProviders();
    } catch (_) {
      state = state.copyWith(connected: false, error: 'RAG session failed.');
    }
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

  Future<void> ingestBook(BookModel book, {bool force = false}) async {
    if (!state.enabled) return;
    final existing = state.books[book.id];
    if (!force &&
        (existing?.status == RagBookStatus.completed || existing?.status == RagBookStatus.ingesting)) {
      return;
    }
    if (book.filePath.isEmpty || !File(book.filePath).existsSync()) {
      state = state.copyWith(
        books: {
          ...state.books,
          book.id: const RagBookIndex(status: RagBookStatus.failed, error: 'Book file not found on device.'),
        },
      );
      return;
    }

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
    var consecutiveNetworkErrors = 0;
    for (var attempt = 0; attempt < 240; attempt++) {
      // Exponential backoff with a cap: 1s -> 1.4s -> ... -> 8s max.
      final delayMs = min(1000 * pow(1.4, attempt ~/ 4).toInt(), 8000);
      await Future<void>.delayed(Duration(milliseconds: delayMs));
      try {
        final status = await _service.ingestStatus(taskId);
        consecutiveNetworkErrors = 0;
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
      } on DioException catch (e) {
        final isNetwork = e.type == DioExceptionType.connectionError ||
            e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout ||
            e.type == DioExceptionType.sendTimeout;
        consecutiveNetworkErrors = isNetwork ? consecutiveNetworkErrors + 1 : 0;
        if (consecutiveNetworkErrors >= 3) {
          state = state.copyWith(
            books: {
              ...state.books,
              appBookId: const RagBookIndex(
                status: RagBookStatus.failed,
                error: 'Backend unreachable while indexing — check your connection.',
              ),
            },
          );
          return;
        }
        // transient network blip — keep waiting
      } catch (_) {
        // transient polling error — keep waiting
      }
    }
    state = state.copyWith(
      books: {
        ...state.books,
        appBookId: const RagBookIndex(status: RagBookStatus.failed, error: 'Ingest timed out.'),
      },
    );
  }
}
