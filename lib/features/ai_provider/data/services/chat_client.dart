import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import '../models/ai_message.dart';
import '../models/rate_limit_snapshot.dart';
import '../repositories/usage_repository.dart';
import 'rate_limit_parser.dart';

class ConnectionTestResult {
  final Duration latency;
  final RateLimitSnapshot? rateLimit;
  final String responseText;

  const ConnectionTestResult({
    required this.latency,
    this.rateLimit,
    this.responseText = '',
  });
}

/// The streaming chat HTTP client. Intercepts every response to capture
/// rate-limit headers and token usage, persisting them via [UsageRepository].
/// A single instance is shared by chat, highlight-explanation and the
/// connection test; `configure()` points it at the active provider.
class ChatClient {
  ChatClient(this._usageRepository);

  final UsageRepository _usageRepository;
  final _rateLimitCtrl = StreamController<RateLimitSnapshot>.broadcast();
  final _usageChangedCtrl = StreamController<String>.broadcast();

  late Dio _dio = _buildDio();

  Stream<RateLimitSnapshot> get rateLimitStream => _rateLimitCtrl.stream;
  Stream<String> get usageChangedStream => _usageChangedCtrl.stream;

  void notifyUsageChanged() => _usageChangedCtrl.add('');

  String _baseUrl = '';
  String _apiKey = '';
  String _providerId = 'custom';

  Dio _buildDio() {
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 120),
        sendTimeout: const Duration(seconds: 60),
      ),
    );
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          options.headers['Authorization'] = 'Bearer $_apiKey';
          options.headers['Accept'] = 'application/json';
          options.extra['providerId'] = _providerId;
          handler.next(options);
        },
        onResponse: (response, handler) async {
          _handleResponse(response);
          handler.next(response);
        },
        onError: (error, handler) async {
          final response = error.response;
          if (response != null) _handleResponse(response);
          handler.next(error);
        },
      ),
    );
    return dio;
  }

  void configure({required String baseUrl, required String apiKey, required String providerId}) {
    _baseUrl = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    _apiKey = apiKey.trim();
    _providerId = providerId;
    _dio = _buildDio();
  }

  String get providerId => _providerId;
  String get baseUrl => _baseUrl;

  void _handleResponse(Response<dynamic> response) {
    final headers = _flattenHeaders(response.headers);
    final snapshot = RateLimitHeaderParser.parseHeaders(
      providerId: _providerId,
      modelId: response.requestOptions.extra['modelId'] as String? ?? '',
      headers: headers,
    );
    if (!snapshot.isEmpty) _rateLimitCtrl.add(snapshot);

    final modelId = response.requestOptions.extra['modelId'] as String?;
    final providerId = response.requestOptions.extra['providerId'] as String?;
    if (modelId == null || providerId == null) return;

    final usage = parseUsageFromResponse(response.data);
    if (usage == null) return;
    final prompt = usage['prompt_tokens'] ?? 0;
    final completion = usage['completion_tokens'] ?? 0;
    if (prompt == 0 && completion == 0) return;

    unawaited(_recordUsage(providerId, modelId, prompt, completion));
  }

  Future<void> _recordUsage(String providerId, String modelId, int prompt, int completion) async {
    final stats = await _usageRepository.getOrCreate(providerId, modelId);
    final updated = stats.recordCall(
      promptTokens: prompt,
      completionTokens: completion,
      latencyMs: 0,
      now: DateTime.now().toUtc(),
    );
    await _usageRepository.saveUsage(updated);
    _usageChangedCtrl.add('$providerId|$modelId');
  }

  Map<String, dynamic> _flattenHeaders(Headers headers) {
    final result = <String, dynamic>{};
    headers.forEach((name, values) {
      result[name.toLowerCase()] = values.length == 1 ? values.first : values;
    });
    return result;
  }

  Map<String, int>? parseUsageFromResponse(dynamic body) {
    if (body is String) {
      try {
        body = jsonDecode(body);
      } catch (_) {
        return null;
      }
    }
    if (body is! Map<String, dynamic>) return null;
    final usage = body['usage'];
    if (usage is! Map<String, dynamic>) return null;
    return {
      'prompt_tokens': (usage['prompt_tokens'] as num?)?.toInt() ?? 0,
      'completion_tokens': (usage['completion_tokens'] as num?)?.toInt() ?? 0,
      'total_tokens': (usage['total_tokens'] as num?)?.toInt() ?? 0,
    };
  }

  Future<void> validateApiKey() async {
    final response = await _dio.get<dynamic>('$_baseUrl/models');
    if (response.statusCode == 200) return;
    throw DioException(
      requestOptions: response.requestOptions,
      response: response,
      type: DioExceptionType.badResponse,
    );
  }

  Future<ConnectionTestResult> testConnection({
    required String modelId,
    required String providerId,
    required String baseUrl,
    required String apiKey,
  }) async {
    configure(baseUrl: baseUrl, apiKey: apiKey, providerId: providerId);

    final stopwatch = Stopwatch()..start();
    final response = await _dio.post<dynamic>(
      '$_baseUrl/chat/completions',
      data: {
        'model': modelId,
        'messages': [
          {'role': 'user', 'content': 'ping'},
        ],
        'max_tokens': 5,
      },
      options: Options(extra: {'modelId': modelId, 'providerId': providerId}),
    );
    stopwatch.stop();

    final headers = _flattenHeaders(response.headers);
    final snapshot = RateLimitHeaderParser.parseHeaders(
      providerId: providerId,
      modelId: modelId,
      headers: headers,
    );
    if (!snapshot.isEmpty) _rateLimitCtrl.add(snapshot);

    final usage = parseUsageFromResponse(response.data);
    if (usage != null) {
      final prompt = usage['prompt_tokens'] ?? 0;
      final completion = usage['completion_tokens'] ?? 0;
      if (prompt > 0 || completion > 0) {
        await _recordUsage(providerId, modelId, prompt, completion);
      }
    }

    return ConnectionTestResult(
      latency: stopwatch.elapsed,
      rateLimit: snapshot.isEmpty ? null : snapshot,
      responseText: _extractReplyText(response.data),
    );
  }

  String _extractReplyText(dynamic body) {
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

  Future<String> completeChat({
    required String modelId,
    required String providerId,
    required List<AIMessage> messages,
    double temperature = 0.4,
    int? maxTokens,
  }) async {
    final response = await _dio.post<dynamic>(
      '$_baseUrl/chat/completions',
      data: {
        'model': modelId,
        'messages': [
          for (final m in messages) {'role': m.role, 'content': m.content},
        ],
        'temperature': temperature,
        'max_tokens': ?maxTokens,
      },
      options: Options(extra: {'modelId': modelId, 'providerId': providerId}),
    );
    return _extractReplyText(response.data);
  }

  Future<Stream<String>> streamChat({
    required String modelId,
    required String providerId,
    required List<AIMessage> messages,
    double temperature = 0.7,
    String? systemPrompt,
  }) async {
    final response = await _dio.post<ResponseBody>(
      '$_baseUrl/chat/completions',
      data: {
        'model': modelId,
        'stream': true,
        'temperature': temperature,
        'stream_options': {'include_usage': true},
        'messages': [
          if (systemPrompt != null && systemPrompt.isNotEmpty)
            {'role': 'system', 'content': systemPrompt},
          for (final m in messages) {'role': m.role, 'content': m.content},
        ],
      },
      options: Options(
        responseType: ResponseType.stream,
        extra: {'modelId': modelId, 'providerId': providerId},
      ),
    );

    final lines = response.data!.stream
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter());
    return _parseSseLines(lines, modelId, providerId);
  }

  Stream<String> _parseSseLines(
    Stream<String> lines,
    String modelId,
    String providerId,
  ) async* {
    await for (final raw in lines) {
      final line = raw.trim();
      if (line.isEmpty || !line.startsWith('data:')) continue;
      final payload = line.substring(5).trim();
      if (payload == '[DONE]') break;
      if (!payload.startsWith('{')) continue;

      try {
        final json = jsonDecode(payload) as Map<String, dynamic>;
        final usage = json['usage'];
        if (usage is Map<String, dynamic>) {
          final prompt = (usage['prompt_tokens'] as num?)?.toInt() ?? 0;
          final completion = (usage['completion_tokens'] as num?)?.toInt() ?? 0;
          if (prompt > 0 || completion > 0) {
            unawaited(_recordUsage(providerId, modelId, prompt, completion));
          }
        }
        final choices = json['choices'] as List<dynamic>? ?? [];
        if (choices.isEmpty) continue;
        final choice = choices.first;
        if (choice is! Map<String, dynamic>) continue;
        final delta = choice['delta'];
        if (delta is! Map<String, dynamic>) continue;
        final content = delta['content'];
        if (content is String && content.isNotEmpty) yield content;
      } catch (_) {
        // Ignore malformed SSE chunks.
      }
    }
  }

  void dispose() {
    _rateLimitCtrl.close();
    _usageChangedCtrl.close();
    _dio.close(force: true);
  }
}
