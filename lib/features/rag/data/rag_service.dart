import 'dart:convert';

import 'package:dio/dio.dart';

import 'rag_models.dart';
import 'rag_store.dart';

class RagService {
  RagService(this._store);

  final RagStore _store;

  Dio _dio() {
    final config = _store.getConfig();
    return Dio(
      BaseOptions(
        baseUrl: config.baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 120),
      ),
    );
  }

  Future<String> _userId() async {
    final existing = _store.getUserId();
    if (existing != null && existing.isNotEmpty) return existing;
    final generated = 'device_${DateTime.now().millisecondsSinceEpoch.toRadixString(16)}';
    await _store.saveSession(generated, '');
    return generated;
  }

  Future<String> _token() async {
    final existing = _store.getToken();
    if (existing != null && existing.isNotEmpty) return existing;
    final uid = await _userId();
    final resp = await _dio().post(
      '/api/v1/auth/token',
      data: {'user_id': uid},
      options: Options(contentType: Headers.jsonContentType),
    );
    final token = (resp.data as Map<String, dynamic>)['access_token'] as String;
    await _store.saveSession(uid, token);
    return token;
  }

  Future<bool> health() async {
    try {
      final resp = await _dio().get('/health');
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>> ingestFile({
    required String filePath,
    required String filename,
    required String title,
    required String author,
  }) async {
    final token = await _token();
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath, filename: filename),
      'title': title,
      'author': author,
    });
    final resp = await _dio().post(
      '/api/v1/ingest',
      data: form,
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> ingestStatus(String taskId) async {
    final token = await _token();
    final resp = await _dio().get(
      '/api/v1/ingest/status/$taskId',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return resp.data as Map<String, dynamic>;
  }

  Stream<RagEvent> streamChat({
    required String query,
    List<String> bookIds = const [],
    String sessionId = 'default',
    String mode = 'single',
  }) {
    return _sse(
      '/api/v1/chat/stream',
      {
        'query': query,
        'mode': mode,
        'book_ids': bookIds,
        'session_id': sessionId,
        'user_id': 'x',
      },
    );
  }

  Stream<RagEvent> streamExplainHighlight({
    required String selectedText,
    required String bookId,
    String chapter = '',
    String surroundingContext = '',
    String sessionId = 'highlight-default',
  }) {
    return _sse(
      '/api/v1/reader/explain-highlight',
      {
        'selected_text': selectedText,
        'book_id': bookId,
        'chapter': chapter,
        'surrounding_context': surroundingContext,
        'user_id': 'x',
        'session_id': sessionId,
      },
    );
  }

  Stream<RagEvent> _sse(String path, Map<String, dynamic> body) async* {
    final token = await _token();
    final resp = await _dio().post(
      path,
      data: body,
      options: Options(
        responseType: ResponseType.stream,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'text/event-stream',
          'Cache-Control': 'no-cache',
        },
      ),
    );

    final stream = (resp.data as ResponseBody).stream;
    final lines = const Utf8Decoder().bind(stream).transform(const LineSplitter());
    await for (final line in lines) {
      if (!line.startsWith('data:')) continue;
      final payload = line.substring(5).trim();
      if (payload.isEmpty) continue;
      try {
        final decoded = jsonDecode(payload) as Map<String, dynamic>;
        yield RagEvent(decoded['type'] as String, decoded['data']);
      } catch (_) {
        // Ignore malformed SSE frames.
      }
    }
  }
}
