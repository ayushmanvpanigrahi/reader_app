import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api_config.dart';
import 'rag_models.dart';

/// Persists RAG backend configuration, session credentials and the
/// mapping between app book ids and backend (vector store) book ids.
class RagStore {
  static const _kEnabled = 'rag_enabled_v1';
  static const _kBaseUrl = 'rag_base_url_v1';
  static const _kUserId = 'rag_user_id_v1';
  static const _kToken = 'rag_token_v1';
  static const _kBookIds = 'rag_book_ids_v1';

  final SharedPreferences _prefs;

  RagStore(this._prefs);

  static Future<RagStore> init() async {
    final prefs = await SharedPreferences.getInstance();
    return RagStore(prefs);
  }

  RagConfig getConfig() {
    return RagConfig(
      enabled: _prefs.getBool(_kEnabled) ?? false,
      baseUrl: _prefs.getString(_kBaseUrl) ?? kBackendBaseUrl,
    );
  }

  Future<void> setConfig(RagConfig config) async {
    await _prefs.setBool(_kEnabled, config.enabled);
    await _prefs.setString(_kBaseUrl, config.baseUrl);
  }

  String? getUserId() => _prefs.getString(_kUserId);

  String? getToken() => _prefs.getString(_kToken);

  Future<void> saveSession(String userId, String token) async {
    await _prefs.setString(_kUserId, userId);
    await _prefs.setString(_kToken, token);
  }

  Map<String, String> getBookIds() {
    final raw = _prefs.getString(_kBookIds);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, v as String));
    } catch (e, stack) {
      debugPrint('[RagStore] Failed to decode book ID map: $e\n$stack');
      return {};
    }
  }

  String? backendBookIdFor(String appBookId) => getBookIds()[appBookId];

  Future<void> setBackendBookId(String appBookId, String backendBookId) async {
    final map = Map<String, String>.from(getBookIds());
    map[appBookId] = backendBookId;
    await _prefs.setString(_kBookIds, jsonEncode(map));
  }
}
