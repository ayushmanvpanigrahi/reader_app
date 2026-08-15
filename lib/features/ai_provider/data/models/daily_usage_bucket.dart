import 'package:hive/hive.dart';

part 'daily_usage_bucket.g.dart';

@HiveType(typeId: 4)
class DailyUsageBucket {
  @HiveField(0)
  final DateTime day;

  @HiveField(1)
  final int requests;

  @HiveField(2)
  final int tokens;

  const DailyUsageBucket({
    required this.day,
    this.requests = 0,
    this.tokens = 0,
  });

  DailyUsageBucket copyWith({int? requests, int? tokens}) {
    return DailyUsageBucket(
      day: day,
      requests: requests ?? this.requests,
      tokens: tokens ?? this.tokens,
    );
  }
}
