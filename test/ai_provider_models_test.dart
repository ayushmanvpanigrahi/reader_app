import 'package:flutter_test/flutter_test.dart';
import 'package:reader_app/features/ai_provider/data/models/ai_provider.dart';
import 'package:reader_app/features/ai_provider/data/models/rate_limit_snapshot.dart';
import 'package:reader_app/features/ai_provider/data/models/usage_stats.dart';
import 'package:reader_app/features/ai_provider/data/services/provider_detector.dart';
import 'package:reader_app/features/ai_provider/data/services/rate_limit_parser.dart';

void main() {
  group('ProviderDetector Tests', () {
    test('detects OpenRouter from URL', () {
      final r = ProviderDetector.detect(url: 'https://openrouter.ai/api/v1');
      expect(r.displayName, 'OpenRouter');
      expect(r.defaultBaseUrl, 'https://openrouter.ai/api/v1');
    });

    test('URL evidence beats key prefix', () {
      final r = ProviderDetector.detect(url: 'https://api.groq.com/openai/v1', apiKey: 'sk-or-xyz');
      expect(r.displayName, 'Groq');
    });

    test('detects Groq from API key prefix alone', () {
      final r = ProviderDetector.detect(apiKey: 'gsk_abc123');
      expect(r.displayName, 'Groq');
      expect(r.defaultBaseUrl, 'https://api.groq.com/openai/v1');
    });

    test('detects local Ollama from port 11434', () {
      final r = ProviderDetector.detect(url: 'http://localhost:11434/v1');
      expect(r.displayName, 'Ollama (Local)');
    });

    test('falls back to Custom Provider when nothing matches', () {
      final r = ProviderDetector.detect(url: 'https://example.com/v1', apiKey: 'random-key');
      expect(r.type, ProviderType.custom);
    });
  });

  group('RateLimitHeaderParser Tests', () {
    final now = DateTime.utc(2026, 8, 15, 12, 0, 0);

    test('parses Groq-style headers', () {
      final snap = RateLimitHeaderParser.parseHeaders(
        providerId: 'p1',
        modelId: 'm1',
        now: now,
        headers: {
          'x-ratelimit-limit-requests': '14400',
          'x-ratelimit-remaining-requests': '13970',
          'x-ratelimit-limit-tokens': '90000',
          'x-ratelimit-remaining-tokens': '89910',
          'x-ratelimit-reset-requests': '1h0m0s',
          'x-ratelimit-reset-tokens': '0s',
        },
      );
      expect(snap.limitRequests, 14400);
      expect(snap.remainingTokens, 89910);
      expect(snap.resetRequestsAt, now.add(const Duration(hours: 1)));
      expect(snap.resetTokensAt, isNull);
      expect(snap.requestUsagePercent, closeTo(430 / 14400, 0.0001));
    });

    test('parses epoch-seconds reset fields', () {
      final snap = RateLimitHeaderParser.parseHeaders(
        providerId: 'p1',
        modelId: 'm1',
        now: now,
        headers: {'x-ratelimit-reset-requests': '1723726800'},
      );
      expect(snap.resetRequestsAt, DateTime.fromMillisecondsSinceEpoch(1723726800000, isUtc: true));
    });

    test('parses ISO-8601 reset timestamps', () {
      final snap = RateLimitHeaderParser.parseHeaders(
        providerId: 'p1',
        modelId: 'm1',
        now: now,
        headers: {'x-ratelimit-reset-requests': '2026-08-15T13:00:00Z'},
      );
      expect(snap.resetRequestsAt, DateTime.utc(2026, 8, 15, 13));
    });

    test('handles header values wrapped in lists', () {
      final snap = RateLimitHeaderParser.parseHeaders(
        providerId: 'p1',
        modelId: 'm1',
        now: now,
        headers: {
          'x-ratelimit-limit-requests': ['100'],
          'x-ratelimit-remaining-requests': ['40'],
        },
      );
      expect(snap.limitRequests, 100);
      expect(snap.remainingRequests, 40);
      expect(snap.isEmpty, isFalse);
    });

    test('empty snapshot reports isEmpty and zero percent', () {
      final snap = RateLimitHeaderParser.parseHeaders(
        providerId: 'p1',
        modelId: 'm1',
        now: now,
        headers: {},
      );
      expect(snap.isEmpty, isTrue);
      expect(snap.requestUsagePercent, 0);
      expect(snap.tokenUsagePercent, 0);
    });

    test('countdown is zero once reset has passed', () {
      final snap = RateLimitSnapshot(
        providerId: 'p1',
        modelId: 'm1',
        capturedAt: now,
        resetRequestsAt: DateTime.utc(2026, 8, 15, 11),
      );
      final cd = RateLimitHeaderParser.countdown(
        snap,
        now: now.add(const Duration(minutes: 5)),
      );
      expect(cd, Duration.zero);
      expect(RateLimitHeaderParser.formatCountdown(cd), '0s');
    });

    test('formatCountdown renders minutes and seconds', () {
      expect(RateLimitHeaderParser.formatCountdown(const Duration(minutes: 1, seconds: 5)), '1m 5s');
      expect(RateLimitHeaderParser.formatCountdown(const Duration(seconds: 9)), '9s');
    });
  });

  group('UsageStats.recordCall Tests', () {
    final t0 = DateTime.utc(2026, 8, 1);
    final base = UsageStats(
      providerId: 'p1',
      modelId: 'm1',
      firstUsedAt: t0,
      lastUsedAt: t0,
    );

    test('records first call with latency baseline', () {
      final s = base.recordCall(
        promptTokens: 10,
        completionTokens: 20,
        latencyMs: 500,
        now: t0.add(const Duration(minutes: 1)),
      );
      expect(s.totalRequests, 1);
      expect(s.totalTokens, 30);
      expect(s.avgLatencyMs, 500);
      expect(s.lastUsedAt, t0.add(const Duration(minutes: 1)));
      expect(s.dailyHistory, hasLength(1));
      expect(s.dailyHistory.first.requests, 1);
      expect(s.dailyHistory.first.tokens, 30);
    });

    test('recomputes rolling latency average across calls', () {
      var s = base.recordCall(
        promptTokens: 10,
        completionTokens: 0,
        latencyMs: 100,
        now: t0.add(const Duration(minutes: 1)),
      );
      s = s.recordCall(
        promptTokens: 0,
        completionTokens: 10,
        latencyMs: 300,
        now: t0.add(const Duration(minutes: 2)),
      );
      expect(s.totalRequests, 2);
      expect(s.totalTokens, 20);
      expect(s.avgLatencyMs, 200);
    });

    test('aggregates multiple calls on the same day into one bucket', () {
      var s = base.recordCall(
        promptTokens: 5,
        completionTokens: 5,
        latencyMs: 100,
        now: t0.add(const Duration(hours: 1)),
      );
      s = s.recordCall(
        promptTokens: 5,
        completionTokens: 5,
        latencyMs: 100,
        now: t0.add(const Duration(hours: 2)),
      );
      expect(s.dailyHistory, hasLength(1));
      expect(s.dailyHistory.first.requests, 2);
      expect(s.dailyHistory.first.tokens, 20);
    });

    test('drops buckets older than 30 days', () {
      var s = base.recordCall(
        promptTokens: 1,
        completionTokens: 1,
        latencyMs: 10,
        now: t0,
      );
      final later = t0.add(const Duration(days: 35));
      s = s.recordCall(
        promptTokens: 1,
        completionTokens: 1,
        latencyMs: 10,
        now: later,
      );
      expect(s.dailyHistory, hasLength(1));
      expect(s.dailyHistory.first.day, DateTime(later.year, later.month, later.day));
    });
  });
}
