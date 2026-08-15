import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/ai_model_info.dart';
import '../../data/models/ai_provider.dart';
import '../../data/models/rate_limit_snapshot.dart';
import '../providers.dart';
import 'active_provider_notifier.dart';
import 'model_switcher_notifier.dart';
import 'provider_list_notifier.dart';

enum EmbeddingModelStatus { available, exhausted, permanentlyFull, untested }

class EmbeddingPoolEntry {
  final AIProvider provider;
  final AIModelInfo model;
  final EmbeddingModelStatus status;
  final DateTime? resetsAt;

  const EmbeddingPoolEntry({
    required this.provider,
    required this.model,
    required this.status,
    this.resetsAt,
  });

  bool get isExhausted =>
      status == EmbeddingModelStatus.exhausted ||
      status == EmbeddingModelStatus.permanentlyFull;
}

class EmbeddingPoolOrderNotifier extends Notifier<List<String>> {
  @override
  List<String> build() {
    return ref.watch(providerRepositoryProvider).embeddingPoolOrder();
  }

  Future<void> reorder(List<String> ids) async {
    state = ids;
    await ref.read(providerRepositoryProvider).setEmbeddingPoolOrder(ids);
  }
}

final embeddingPoolOrderProvider =
    NotifierProvider<EmbeddingPoolOrderNotifier, List<String>>(
  EmbeddingPoolOrderNotifier.new,
);

/// Unified cross-provider embedding pool. Derives every embedding model cached
/// across all configured providers, computes its live [EmbeddingModelStatus]
/// from the latest rate-limit snapshot + the auto-switcher's exhaustion map,
/// and sorts by the user-arranged priority (models not in the order trail the
/// ordered ones, stable by provider name then model id).
final embeddingPoolProvider = Provider<List<EmbeddingPoolEntry>>((ref) {
  final providers =
      ref.watch(providerListProvider).valueOrNull ?? const <AIProvider>[];
  final order = ref.watch(embeddingPoolOrderProvider);
  final active = ref.watch(activeProviderProvider).value;
  final switcher = ref.watch(modelSwitcherProvider).value;
  final modelRepo = ref.watch(modelRepositoryProvider);

  ref.watch(allUsageStatsProvider);
  ref.watch(currentRateLimitProvider);

  final exhausted = switcher?.exhaustedModels ?? const <String, DateTime>{};
  final activeEmbeddingId = active?.embeddingModelId;

  final entries = <EmbeddingPoolEntry>[];
  for (final provider in providers) {
    final cached = modelRepo.cached(provider.id) ?? const <AIModelInfo>[];
    for (final model in cached) {
      if (model.category != ModelCategory.embedding) continue;
      entries.add(_buildEntry(
        ref: ref,
        provider: provider,
        model: model,
        exhausted: exhausted,
        activeEmbeddingId: activeEmbeddingId,
      ));
    }
  }

  final priority = {for (var i = 0; i < order.length; i++) order[i]: i};
  entries.sort((a, b) {
    final pa = priority[a.model.id] ?? order.length;
    final pb = priority[b.model.id] ?? order.length;
    if (pa != pb) return pa.compareTo(pb);
    final fa = a.provider.displayName.toLowerCase();
    final fb = b.provider.displayName.toLowerCase();
    if (fa != fb) return fa.compareTo(fb);
    return a.model.id.compareTo(b.model.id);
  });
  return entries;
});

(EmbeddingModelStatus, DateTime?) _deriveStatus({
  required RateLimitSnapshot? rateLimit,
  required DateTime? switcherExhaustedAt,
  required bool hasUsage,
  required bool isActive,
  required bool inFallback,
  required bool inOrder,
}) {
  final now = DateTime.now();
  if (rateLimit != null && rateLimit.remainingRequests == 0) {
    final reset = rateLimit.resetRequestsAt;
    if (reset != null && reset.isAfter(now)) {
      return (EmbeddingModelStatus.exhausted, reset);
    }
    return (EmbeddingModelStatus.permanentlyFull, null);
  }
  if (switcherExhaustedAt != null && switcherExhaustedAt.isAfter(now)) {
    return (EmbeddingModelStatus.exhausted, switcherExhaustedAt);
  }
  if (hasUsage || isActive || inFallback || inOrder) {
    return (EmbeddingModelStatus.available, null);
  }
  return (EmbeddingModelStatus.untested, null);
}

EmbeddingPoolEntry _buildEntry({
  required Ref ref,
  required AIProvider provider,
  required AIModelInfo model,
  required Map<String, DateTime> exhausted,
  required String? activeEmbeddingId,
}) {
  final usageRepo = ref.read(usageRepositoryProvider);
  final switcher = ref.read(modelSwitcherProvider).value;

  final (status, resetsAt) = _deriveStatus(
    rateLimit: usageRepo.latestRateLimit(provider.id, model.id),
    switcherExhaustedAt: exhausted[model.id],
    hasUsage: usageRepo.usage(provider.id, model.id) != null,
    isActive: activeEmbeddingId == model.id,
    inFallback: switcher?.embeddingFallbackPool.contains(model.id) ?? false,
    inOrder: ref.read(embeddingPoolOrderProvider).contains(model.id),
  );
  return EmbeddingPoolEntry(
    provider: provider,
    model: model,
    status: status,
    resetsAt: resetsAt,
  );
}
