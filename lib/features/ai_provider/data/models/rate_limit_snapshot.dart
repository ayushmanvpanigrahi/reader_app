import 'package:hive/hive.dart';

part 'rate_limit_snapshot.g.dart';

@HiveType(typeId: 2)
class RateLimitSnapshot {
  @HiveField(0)
  final String providerId;

  @HiveField(1)
  final String modelId;

  @HiveField(2)
  final int? limitRequests;

  @HiveField(3)
  final int? limitTokens;

  @HiveField(4)
  final int? remainingRequests;

  @HiveField(5)
  final int? remainingTokens;

  @HiveField(6)
  final DateTime? resetRequestsAt;

  @HiveField(7)
  final DateTime? resetTokensAt;

  @HiveField(8)
  final int? usedRequests;

  @HiveField(9)
  final DateTime capturedAt;

  const RateLimitSnapshot({
    required this.providerId,
    required this.modelId,
    this.limitRequests,
    this.limitTokens,
    this.remainingRequests,
    this.remainingTokens,
    this.resetRequestsAt,
    this.resetTokensAt,
    this.usedRequests,
    required this.capturedAt,
  });

  double get requestUsagePercent {
    if (limitRequests == null || limitRequests == 0) return 0;
    final used = (usedRequests ?? (limitRequests! - (remainingRequests ?? limitRequests!)))
        .clamp(0, limitRequests!);
    return used / limitRequests!;
  }

  double get tokenUsagePercent {
    if (limitTokens == null || limitTokens == 0) return 0;
    final used = limitTokens! - (remainingTokens ?? limitTokens!);
    return (used.clamp(0, limitTokens!)) / limitTokens!;
  }

  bool get isEmpty =>
      limitRequests == null &&
      limitTokens == null &&
      remainingRequests == null &&
      remainingTokens == null;

  RateLimitSnapshot copyWith({
    int? limitRequests,
    int? limitTokens,
    int? remainingRequests,
    int? remainingTokens,
    DateTime? resetRequestsAt,
    DateTime? resetTokensAt,
    int? usedRequests,
    DateTime? capturedAt,
  }) {
    return RateLimitSnapshot(
      providerId: providerId,
      modelId: modelId,
      limitRequests: limitRequests ?? this.limitRequests,
      limitTokens: limitTokens ?? this.limitTokens,
      remainingRequests: remainingRequests ?? this.remainingRequests,
      remainingTokens: remainingTokens ?? this.remainingTokens,
      resetRequestsAt: resetRequestsAt ?? this.resetRequestsAt,
      resetTokensAt: resetTokensAt ?? this.resetTokensAt,
      usedRequests: usedRequests ?? this.usedRequests,
      capturedAt: capturedAt ?? this.capturedAt,
    );
  }
}
