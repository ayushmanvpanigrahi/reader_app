import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/ai_provider.dart';
import '../providers.dart';

final providerListProvider =
    AsyncNotifierProvider<ProviderListNotifier, List<AIProvider>>(ProviderListNotifier.new);

class ProviderListNotifier extends AsyncNotifier<List<AIProvider>> {
  @override
  Future<List<AIProvider>> build() async {
    return ref.watch(providerRepositoryProvider).all();
  }

  Future<void> refresh() async {
    state = AsyncData(ref.read(providerRepositoryProvider).all());
  }

  Future<void> save(AIProvider provider) async {
    await ref.read(providerRepositoryProvider).save(provider);
    await refresh();
  }

  Future<void> remove(String id) async {
    await ref.read(providerRepositoryProvider).delete(id);
    await refresh();
  }
}
