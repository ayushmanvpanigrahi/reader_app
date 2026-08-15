import 'package:hive/hive.dart';

import '../models/rate_limit_snapshot.dart';
import '../models/usage_stats.dart';

/// Persists the latest [RateLimitSnapshot] per (provider, model) and the
/// per-model [UsageStats] into two Hive boxes.
class UsageRepository {
  static const _rateLimitBox = 'rate_limits';
  static const _usageBox = 'usage_stats';

  late final Box<RateLimitSnapshot> _rateLimits;
  late final Box<UsageStats> _usage;

  Future<void> init() async {
    _rateLimits = await Hive.openBox<RateLimitSnapshot>(_rateLimitBox);
    _usage = await Hive.openBox<UsageStats>(_usageBox);
  }

  String _key(String providerId, String modelId) => '$providerId|$modelId';

  // ---- Rate limits ----

  RateLimitSnapshot? latestRateLimit(String providerId, String modelId) {
    return _rateLimits.get(_key(providerId, modelId));
  }

  Future<void> saveRateLimit(RateLimitSnapshot snapshot) async {
    final existing = _rateLimits.get(_key(snapshot.providerId, snapshot.modelId));
    if (existing != null &&
        existing.capturedAt.isAfter(snapshot.capturedAt) &&
        !snapshot.isEmpty) {
      return;
    }
    await _rateLimits.put(_key(snapshot.providerId, snapshot.modelId), snapshot);
  }

  // ---- Usage ----

  UsageStats? usage(String providerId, String modelId) {
    return _usage.get(_key(providerId, modelId));
  }

  Future<UsageStats> getOrCreate(String providerId, String modelId) async {
    final existing = _usage.get(_key(providerId, modelId));
    if (existing != null) return existing;
    final now = DateTime.now().toUtc();
    final created = UsageStats(
      providerId: providerId,
      modelId: modelId,
      firstUsedAt: now,
      lastUsedAt: now,
    );
    await _usage.put(_key(providerId, modelId), created);
    return created;
  }

  Future<void> saveUsage(UsageStats stats) =>
      _usage.put(_key(stats.providerId, stats.modelId), stats);

  List<UsageStats> loadAllForProvider(String providerId) {
    final result = <UsageStats>[];
    for (final stats in _usage.values) {
      if (stats.providerId == providerId) result.add(stats);
    }
    result.sort((a, b) => b.lastUsedAt.compareTo(a.lastUsedAt));
    return result;
  }

  List<UsageStats> loadAll() {
    final result = _usage.values.toList()
      ..sort((a, b) => b.lastUsedAt.compareTo(a.lastUsedAt));
    return result;
  }

  Future<void> resetProvider(String providerId) async {
    final keysToDelete = <String>[
      for (final entry in _usage.toMap().entries)
        if (entry.value.providerId == providerId) entry.key,
      for (final entry in _rateLimits.toMap().entries)
        if (entry.value.providerId == providerId) entry.key,
    ];
    for (final key in keysToDelete) {
      await _usage.delete(key);
      await _rateLimits.delete(key);
    }
  }

  Future<void> dispose() async {
    await _rateLimits.close();
    await _usage.close();
  }
}
