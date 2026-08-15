import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/rate_limit_snapshot.dart';
import '../data/models/usage_stats.dart';
import '../data/repositories/model_repository.dart';
import '../data/repositories/provider_repository.dart';
import '../data/repositories/usage_repository.dart';
import '../data/services/chat_client.dart';

/// All three repositories are opened once in `main()` and injected here.
final providerRepositoryProvider = Provider<ProviderRepository>(
  (ref) => throw UnimplementedError('Override providerRepositoryProvider in main'),
);

final modelRepositoryProvider = Provider<ModelRepository>(
  (ref) => throw UnimplementedError('Override modelRepositoryProvider in main'),
);

final usageRepositoryProvider = Provider<UsageRepository>(
  (ref) => throw UnimplementedError('Override usageRepositoryProvider in main'),
);

/// Single shared streaming client. The [ActiveProviderNotifier] calls
/// `configure()` whenever the active provider changes.
final chatClientProvider = Provider<ChatClient>((ref) {
  final client = ChatClient(ref.watch(usageRepositoryProvider));
  ref.onDispose(client.dispose);
  return client;
});

/// Latest rate-limit snapshot broadcast by the client during any API call.
final currentRateLimitProvider = StreamProvider<RateLimitSnapshot?>((ref) {
  return ref.watch(chatClientProvider).rateLimitStream;
});

/// Live per-(provider, model) usage, updated whenever a call completes.
final usageStatsProvider = StreamProvider.family<UsageStats?, ({String providerId, String modelId})>(
  (ref, key) async* {
    final repo = ref.watch(usageRepositoryProvider);
    yield repo.usage(key.providerId, key.modelId);
    await for (final changedKey in ref.watch(chatClientProvider).usageChangedStream) {
      if (changedKey == '${key.providerId}|${key.modelId}') {
        yield repo.usage(key.providerId, key.modelId);
      }
    }
  },
);

final allUsageStatsProvider = StreamProvider<List<UsageStats>>((ref) async* {
  final repo = ref.watch(usageRepositoryProvider);
  yield repo.loadAll();
  await for (final _ in ref.watch(chatClientProvider).usageChangedStream) {
    yield repo.loadAll();
  }
});

/// Injected signal consumed by the app shell to render the non-blocking
/// auto-switch overlay snackbar.
final autoSwitchMessageProvider = StateProvider<String?>((ref) => null);
