import 'package:dio/dio.dart';

import '../models/rate_limit_snapshot.dart';
import 'rate_limit_parser.dart';

class ConnectionTestResult {
  final Duration latency;
  final RateLimitSnapshot? rateLimit;
  final String responseText;
  final bool isSuccessful;

  const ConnectionTestResult({
    required this.latency,
    this.rateLimit,
    this.responseText = '',
    this.isSuccessful = true,
  });

  bool get hasRateLimit => rateLimit != null && !rateLimit!.isEmpty;
}

/// Runs a real `POST /chat/completions` ping against the endpoint and returns
/// measured latency plus any rate-limit headers the provider sends back.
/// This doubles as the "connection test" and as the source of live
/// rate-limit snapshots during setup.
class ConnectionTester {
  const ConnectionTester._();

  static Future<ConnectionTestResult> test({
    required String modelId,
    required String providerId,
    required String baseUrl,
    required String apiKey,
  }) async {
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 120),
        sendTimeout: const Duration(seconds: 60),
      ),
    );

    final stopwatch = Stopwatch()..start();
    try {
      final response = await dio.post<dynamic>(
        '/chat/completions',
        data: {
          'model': modelId,
          'messages': [
            {'role': 'user', 'content': 'ping'},
          ],
          'max_tokens': 5,
        },
        options: Options(
          headers: {'Authorization': 'Bearer $apiKey', 'Accept': 'application/json'},
        ),
      );
      stopwatch.stop();
      return ConnectionTestResult(
        latency: stopwatch.elapsed,
        rateLimit: _parseRateLimit(baseUrl, providerId, modelId, response),
        responseText: _extractReplyText(response.data),
      );
    } on DioException catch (e) {
      stopwatch.stop();
      final rateLimit = e.response != null
          ? _parseRateLimit(baseUrl, providerId, modelId, e.response!)
          : null;
      return ConnectionTestResult(
        latency: stopwatch.elapsed,
        rateLimit: rateLimit,
        responseText: e.message ?? '',
        isSuccessful: false,
      );
    }
  }

  static RateLimitSnapshot? _parseRateLimit(
    String baseUrl,
    String providerId,
    String modelId,
    Response<dynamic> response,
  ) {
    final headers = _flattenHeaders(response.headers);
    final snapshot = RateLimitHeaderParser.parseHeaders(
      providerId: providerId,
      modelId: modelId,
      headers: headers,
    );
    return snapshot.isEmpty ? null : snapshot;
  }

  static Map<String, dynamic> _flattenHeaders(Headers headers) {
    final result = <String, dynamic>{};
    headers.forEach((name, values) {
      result[name.toLowerCase()] = values.length == 1 ? values.first : values;
    });
    return result;
  }

  static String _extractReplyText(dynamic body) {
    if (body is! Map<String, dynamic>) return '';
    final choices = body['choices'] as List<dynamic>? ?? [];
    if (choices.isEmpty) return '';
    final message = choices.first;
    if (message is! Map<String, dynamic>) return '';
    final content = message['message'];
    if (content is Map<String, dynamic>) {
      return (content['content'] as String? ?? '').toString();
    }
    if (message['text'] != null) return message['text'].toString();
    return '';
  }
}
