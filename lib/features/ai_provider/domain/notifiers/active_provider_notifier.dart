import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/ai_provider.dart';
import '../../data/repositories/provider_repository.dart';
import '../../data/services/chat_client.dart';
import '../providers.dart';
import 'provider_list_notifier.dart';

class ActiveProviderState {
  final AIProvider? provider;
  final String? chatModelId;
  final String? embeddingModelId;

  const ActiveProviderState({this.provider, this.chatModelId, this.embeddingModelId});

  bool get isConfigured =>
      provider != null &&
      chatModelId != null &&
      chatModelId!.isNotEmpty &&
      provider!.baseUrl.isNotEmpty;
}

final activeProviderProvider =
    AsyncNotifierProvider<ActiveProviderNotifier, ActiveProviderState>(
  ActiveProviderNotifier.new,
);

/// Loads the active provider from the repository, resolves its API key from
/// secure storage, points the shared [ChatClient] at it, and exposes the
/// current chat/embedding model selections. Every chat or highlight call reads
/// state from here — switching providers mid-session just invalidates this.
class ActiveProviderNotifier extends AsyncNotifier<ActiveProviderState> {
  ProviderRepository get _repo => ref.read(providerRepositoryProvider);
  ChatClient get _client => ref.read(chatClientProvider);

  @override
  Future<ActiveProviderState> build() async {
    final provider = _repo.activeProvider();
    if (provider == null) return const ActiveProviderState();

    final apiKey = await _repo.apiKey(provider.id);
    _client.configure(
      baseUrl: provider.baseUrl,
      apiKey: apiKey ?? '',
      providerId: provider.id,
    );

    return ActiveProviderState(
      provider: provider,
      chatModelId: _repo.chatModelId() ?? provider.activeChatModelId,
      embeddingModelId: _repo.embeddingModelId() ?? provider.activeEmbeddingModelId,
    );
  }

  Future<void> setActiveProvider(String providerId) async {
    final repo = _repo;
    for (final provider in repo.all()) {
      if (provider.isActive != (provider.id == providerId)) {
        await repo.save(provider.copyWith(isActive: provider.id == providerId));
      }
    }
    await repo.setActiveProviderId(providerId);
    ref.invalidate(providerListProvider);
    ref.invalidateSelf();
  }

  Future<void> selectChatModel(String? modelId) async {
    final provider = state.value?.provider;
    if (provider == null) return;
    await _repo.save(provider.copyWith(activeChatModelId: modelId));
    await _repo.setChatModelId(modelId);
    ref.invalidateSelf();
  }

  Future<void> selectEmbeddingModel(String? modelId) async {
    final provider = state.value?.provider;
    if (provider == null) return;
    await _repo.save(provider.copyWith(activeEmbeddingModelId: modelId));
    await _repo.setEmbeddingModelId(modelId);
    ref.invalidateSelf();
  }
}
