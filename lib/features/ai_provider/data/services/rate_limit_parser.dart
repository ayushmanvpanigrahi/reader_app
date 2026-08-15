import 'dart:math';

import '../models/rate_limit_snapshot.dart';

/// Parses provider-specific rate-limit headers into a [RateLimitSnapshot].
/// Supports the formats used by Groq, OpenRouter, NVIDIA, OpenAI, Anthropic
/// and generic OpenAI-compatible endpoints (duration strings, ISO-8601
/// timestamps and epoch seconds).
class RateLimitHeaderParser {
  const RateLimitHeaderParser._();

  static const _resetRequestsKey = 'x-ratelimit-reset-requests';
  static const _resetTokensKey = 'x-ratelimit-reset-tokens';

  static RateLimitSnapshot parseHeaders({
    required String providerId,
    required String modelId,
    required Map<String, dynamic> headers,
    DateTime? now,
  }) {
    final capturedAt = now ?? DateTime.now().toUtc();

    int? toInt(dynamic value) {
      if (value == null) return null;
      return int.tryParse(value.toString().trim());
    }

    int? parseIntSafe(Map<String, dynamic> h, String key) {
      final v = h[key];
      if (v == null) return null;
      if (v is List) return toInt(v.isNotEmpty ? v.first : null);
      return toInt(v);
    }

    String? raw(Map<String, dynamic> h, String key) {
      final v = h[key];
      if (v == null) return null;
      if (v is List) return v.isNotEmpty ? v.first.toString() : null;
      return v.toString();
    }

    return RateLimitSnapshot(
      providerId: providerId,
      modelId: modelId,
      limitRequests: parseIntSafe(headers, 'x-ratelimit-limit-requests'),
      limitTokens: parseIntSafe(headers, 'x-ratelimit-limit-tokens'),
      remainingRequests: parseIntSafe(headers, 'x-ratelimit-remaining-requests'),
      remainingTokens: parseIntSafe(headers, 'x-ratelimit-remaining-tokens'),
      resetRequestsAt: parseResetField(raw(headers, _resetRequestsKey), now: capturedAt),
      resetTokensAt: parseResetField(raw(headers, _resetTokensKey), now: capturedAt),
      usedRequests: parseIntSafe(headers, 'x-ratelimit-used-requests'),
      capturedAt: capturedAt,
    );
  }

  static DateTime? parseResetField(String? value, {DateTime? now}) {
    if (value == null || value.trim().isEmpty) return null;
    final v = value.trim();
    final base = now ?? DateTime.now().toUtc();

    final epochSeconds = int.tryParse(v);
    if (epochSeconds != null) {
      if (epochSeconds > 1000000000000) {
        return DateTime.fromMillisecondsSinceEpoch(epochSeconds, isUtc: true);
      }
      return DateTime.fromMillisecondsSinceEpoch(epochSeconds * 1000, isUtc: true);
    }

    final parsedIso = DateTime.tryParse(v);
    if (parsedIso != null) return parsedIso.toUtc();

    final duration = _parseDurationString(v);
    if (duration != null) return base.add(duration);

    return null;
  }

  static Duration? _parseDurationString(String value) {
    final match = RegExp(r'^\s*(?:(\d+)d)?\s*(?:(\d+)h)?\s*(?:(\d+)m)?\s*(?:(\d+)s)?\s*$')
        .firstMatch(value);
    if (match == null) return null;
    final days = int.tryParse(match.group(1) ?? '') ?? 0;
    final hours = int.tryParse(match.group(2) ?? '') ?? 0;
    final minutes = int.tryParse(match.group(3) ?? '') ?? 0;
    final seconds = int.tryParse(match.group(4) ?? '') ?? 0;
    if (days == 0 && hours == 0 && minutes == 0 && seconds == 0) return null;
    return Duration(days: days, hours: hours, minutes: minutes, seconds: seconds);
  }

  static Duration countdown(RateLimitSnapshot snapshot, {DateTime? now}) {
    final current = now ?? DateTime.now().toUtc();
    final reset = snapshot.resetRequestsAt ?? snapshot.resetTokensAt;
    if (reset == null) return Duration.zero;
    final diff = reset.difference(current);
    return diff.isNegative ? Duration.zero : diff;
  }

  static String formatCountdown(Duration d) {
    final totalSeconds = max(0, d.inSeconds);
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    if (minutes > 0) return '${minutes}m ${seconds}s';
    return '${seconds}s';
  }

  static String formatCountdownFromSnapshot(RateLimitSnapshot snapshot, {DateTime? now}) {
    return formatCountdown(countdown(snapshot, now: now));
  }
}
