import 'package:hive/hive.dart';

import 'daily_usage_bucket.dart';

part 'usage_stats.g.dart';

@HiveType(typeId: 3)
class UsageStats {
  @HiveField(0)
  final String providerId;

  @HiveField(1)
  final String modelId;

  @HiveField(2)
  final int totalRequests;

  @HiveField(3)
  final int totalPromptTokens;

  @HiveField(4)
  final int totalCompletionTokens;

  @HiveField(5)
  final int totalTokens;

  @HiveField(6)
  final double avgLatencyMs;

  @HiveField(7)
  final DateTime firstUsedAt;

  @HiveField(8)
  final DateTime lastUsedAt;

  @HiveField(9)
  final List<DailyUsageBucket> dailyHistory;

  const UsageStats({
    required this.providerId,
    required this.modelId,
    this.totalRequests = 0,
    this.totalPromptTokens = 0,
    this.totalCompletionTokens = 0,
    this.totalTokens = 0,
    this.avgLatencyMs = 0,
    required this.firstUsedAt,
    required this.lastUsedAt,
    this.dailyHistory = const [],
  });

  /// Returns a new [UsageStats] with one call recorded and a live-recomputed
  /// rolling average. Pure, immutable — callers persist the result.
  UsageStats recordCall({
    required int promptTokens,
    required int completionTokens,
    required double latencyMs,
    required DateTime now,
  }) {
    final req = totalRequests + 1;
    final newAvg = req == 1
        ? latencyMs
        : (avgLatencyMs * totalRequests + latencyMs) / req;
    final today = DateTime(now.year, now.month, now.day);

    final buckets = List<DailyUsageBucket>.from(dailyHistory);
    final todayIdx = buckets.indexWhere((b) =>
        b.day.year == today.year && b.day.month == today.month && b.day.day == today.day);
    if (todayIdx >= 0) {
      final b = buckets[todayIdx];
      buckets[todayIdx] = b.copyWith(
        requests: b.requests + 1,
        tokens: b.tokens + promptTokens + completionTokens,
      );
    } else {
      buckets.add(DailyUsageBucket(day: today, requests: 1, tokens: promptTokens + completionTokens));
    }
    buckets.sort((a, b) => a.day.compareTo(b.day));
    final cutoff = today.subtract(const Duration(days: 30));
    buckets.removeWhere((b) => b.day.isBefore(cutoff));

    return UsageStats(
      providerId: providerId,
      modelId: modelId,
      totalRequests: req,
      totalPromptTokens: totalPromptTokens + promptTokens,
      totalCompletionTokens: totalCompletionTokens + completionTokens,
      totalTokens: totalTokens + promptTokens + completionTokens,
      avgLatencyMs: newAvg,
      firstUsedAt: firstUsedAt,
      lastUsedAt: now,
      dailyHistory: buckets,
    );
  }
}
