import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/ai_provider.dart';
import '../../data/repositories/provider_repository.dart';
import 'active_provider_notifier.dart';
import 'provider_list_notifier.dart';
import '../providers.dart';

enum ModelRole { chat, embedding }

class ActiveModelState {
  /// Ordered fallback pools (modelId list, index = priority).
  final List<String> chatFallbackPool;
  final List<String> embeddingFallbackPool;

  /// modelId -> reactivation time for models currently rate-exhausted.
  final Map<String, DateTime> exhaustedModels;

  const ActiveModelState({
    this.chatFallbackPool = const [],
    this.embeddingFallbackPool = const [],
    this.exhaustedModels = const {},
  });

  ActiveModelState copyWith({
    List<String>? chatFallbackPool,
    List<String>? embeddingFallbackPool,
    Map<String, DateTime>? exhaustedModels,
  }) {
    return ActiveModelState(
      chatFallbackPool: chatFallbackPool ?? this.chatFallbackPool,
      embeddingFallbackPool: embeddingFallbackPool ?? this.embeddingFallbackPool,
      exhaustedModels: exhaustedModels ?? this.exhaustedModels,
    );
  }
}

final modelSwitcherProvider =
    AsyncNotifierProvider<ModelSwitcherNotifier, ActiveModelState>(
  ModelSwitcherNotifier.new,
);

/// Auto-switch engine. When a model reports rate-exhaustion (HTTP 429 /
/// quota exceeded) this picks the next available model from the configured
/// fallback pool — potentially from a different provider — marks the exhausted
/// model for delayed reactivation, and notifies the UI with a non-blocking
/// overlay snackbar.
class ModelSwitcherNotifier extends AsyncNotifier<ActiveModelState> {
  ProviderRepository get _repo => ref.read(providerRepositoryProvider);

  @override
  Future<ActiveModelState> build() async {
    return ActiveModelState(
      chatFallbackPool: _repo.chatFallbackPool(),
      embeddingFallbackPool: _repo.embeddingFallbackPool(),
    );
  }

  Future<void> setChatFallbackPool(List<String> ids) async {
    await _repo.setChatFallbackPool(ids);
    state = AsyncData(state.value!.copyWith(chatFallbackPool: ids));
  }

  Future<void> setEmbeddingFallbackPool(List<String> ids) async {
    await _repo.setEmbeddingFallbackPool(ids);
    state = AsyncData(state.value!.copyWith(embeddingFallbackPool: ids));
  }

  /// Called by controllers when an API call returns 429/quota exceeded.
  /// Returns the newly activated model id, or null if no fallback was
  /// available (callers should surface the error).
  Future<String?> handleRateLimit({
    required String exhaustedModelId,
    required ModelRole role,
    DateTime? resetAt,
  }) async {
    final pool = role == ModelRole.chat
        ? state.value!.chatFallbackPool
        : state.value!.embeddingFallbackPool;

    final exhaustMap = Map<String, DateTime>.from(state.value!.exhaustedModels);
    exhaustMap[exhaustedModelId] = resetAt ?? DateTime.now().add(const Duration(minutes: 2));
    state = AsyncData(state.value!.copyWith(exhaustedModels: exhaustMap));

    if (resetAt != null) {
      await scheduleModelReactivation(exhaustedModelId, resetAt);
    }

    final providers = ref.read(providerListProvider).value ?? const <AIProvider>[];
    final replacement = _pickNextAvailable(
      pool: pool,
      exhaustedModelId: exhaustedModelId,
      exhausted: state.value!.exhaustedModels,
      providers: providers,
    );
    if (replacement == null) return null;

    final replacementProvider = _providerForModel(providers, replacement);
    if (replacementProvider == null) return null;

    await _activate(
      role: role,
      modelId: replacement,
      providerId: replacementProvider.id,
      previousModelId: exhaustedModelId,
    );
    return replacement;
  }

  /// Cross-provider pool walk: skip the exhausted model, skip other models
  /// that are themselves exhausted, prefer models from the current active
  /// provider, then fall back to any configured provider.
  String? _pickNextAvailable({
    required List<String> pool,
    required String exhaustedModelId,
    required Map<String, DateTime> exhausted,
    required List<AIProvider> providers,
  }) {
    final now = DateTime.now();
    final activeProviderId = ref.read(providerRepositoryProvider).activeProviderId();
    for (final modelId in pool) {
      if (modelId == exhaustedModelId) continue;
      final reset = exhausted[modelId];
      if (reset != null && reset.isAfter(now)) continue;
      final provider = _providerForModel(providers, modelId);
      if (provider == null) continue;
      if (provider.id == activeProviderId) return modelId;
    }
    for (final modelId in pool) {
      if (modelId == exhaustedModelId) continue;
      final reset = exhausted[modelId];
      if (reset != null && reset.isAfter(now)) continue;
      if (_providerForModel(providers, modelId) != null) return modelId;
    }
    return null;
  }

  AIProvider? _providerForModel(List<AIProvider> providers, String modelId) {
    for (final p in providers) {
      if (p.cachedModelIds.contains(modelId)) return p;
    }
    return null;
  }

  Future<void> _activate({
    required ModelRole role,
    required String modelId,
    required String providerId,
    required String previousModelId,
  }) async {
    final current = ref.read(activeProviderProvider).value;
    if (current?.provider?.id != providerId) {
      await ref.read(activeProviderProvider.notifier).setActiveProvider(providerId);
    }
    if (role == ModelRole.chat) {
      await ref.read(activeProviderProvider.notifier).selectChatModel(modelId);
    } else {
      await ref.read(activeProviderProvider.notifier).selectEmbeddingModel(modelId);
    }
    final roleLabel = role == ModelRole.chat ? 'Chat' : 'Embedding';
    ref.read(autoSwitchMessageProvider.notifier).state =
        '$roleLabel rate limit on "$previousModelId" → switched to "$modelId"';
  }

  /// Re-activates an exhausted model after its rate-limit window elapses.
  Future<void> scheduleModelReactivation(String modelId, DateTime resetAt) async {
    final delay = resetAt.difference(DateTime.now());
    if (delay.isNegative) return;
    Future<void>.delayed(delay, () {
      final current = state.value;
      if (current == null) return;
      final map = Map<String, DateTime>.from(current.exhaustedModels)..remove(modelId);
      state = AsyncData(current.copyWith(exhaustedModels: map));
    });
  }
}
