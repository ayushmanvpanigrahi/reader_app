import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive/hive.dart';

import '../models/ai_provider.dart';

/// Persistence for providers (Hive `ai_providers` box), API keys
/// (FlutterSecureStorage — keys never touch Hive), the active provider/model
/// selections (Hive `ai_active` box) and the cross-provider fallback pools
/// (Hive `ai_fallback` box).
class ProviderRepository {
  static const _providersBox = 'ai_providers';
  static const _activeBox = 'ai_active';
  static const _fallbackBox = 'ai_fallback';

  late final Box<AIProvider> _providers;
  late final Box<String> _active;
  late final Box<List<String>> _fallback;

  final FlutterSecureStorage _secure = const FlutterSecureStorage();

  Future<void> init() async {
    _providers = await Hive.openBox<AIProvider>(_providersBox);
    _active = await Hive.openBox<String>(_activeBox);
    _fallback = await Hive.openBox<List<String>>(_fallbackBox);
  }

  // ---- Providers ----

  List<AIProvider> all() {
    final list = _providers.values.toList();
    list.sort((a, b) {
      if (a.isActive != b.isActive) return a.isActive ? -1 : 1;
      return a.addedAt.compareTo(b.addedAt);
    });
    return list;
  }

  AIProvider? byId(String id) => _providers.get(id);

  AIProvider? activeProvider() {
    final activeId = activeProviderId();
    if (activeId == null) return null;
    final provider = _providers.get(activeId);
    return provider?.isActive == true ? provider : null;
  }

  Future<void> save(AIProvider provider) => _providers.put(provider.id, provider);

  Future<void> delete(String id) async {
    await _providers.delete(id);
    await _secure.delete(key: _keyRef(id));
    if (activeProviderId() == id) {
      await _active.delete('active_provider_id');
    }
  }

  // ---- API keys (secure storage) ----

  String _keyRef(String providerId) => 'ai_provider_key_$providerId';

  String apiKeyRefFor(String providerId) => _keyRef(providerId);

  Future<String?> apiKey(String providerId) => _secure.read(key: _keyRef(providerId));

  Future<void> setApiKey(String providerId, String key) =>
      _secure.write(key: _keyRef(providerId), value: key);

  // ---- Active provider & model selections ----

  String? activeProviderId() => _active.get('active_provider_id');

  Future<void> setActiveProviderId(String? id) async {
    await _active.put('active_provider_id', id ?? '');
  }

  String? chatModelId() => _active.get('chat_model_id');

  Future<void> setChatModelId(String? id) async {
    await _active.put('chat_model_id', id ?? '');
  }

  String? embeddingModelId() => _active.get('embedding_model_id');

  Future<void> setEmbeddingModelId(String? id) async {
    await _active.put('embedding_model_id', id ?? '');
  }

  // ---- Fallback pools (ordered model ids, any provider) ----

  List<String> chatFallbackPool() => _fallback.get('chat_pool') ?? const [];

  List<String> embeddingFallbackPool() => _fallback.get('embed_pool') ?? const [];

  Future<void> setChatFallbackPool(List<String> ids) => _fallback.put('chat_pool', ids);

  Future<void> setEmbeddingFallbackPool(List<String> ids) => _fallback.put('embed_pool', ids);

  // User-arranged display priority for the cross-provider embedding pool.
  // Kept separate from the fallback pool because the auto-switcher mutates
  // `embed_pool` when models get exhausted.
  List<String> embeddingPoolOrder() => _fallback.get('embed_pool_order') ?? const [];

  Future<void> setEmbeddingPoolOrder(List<String> ids) => _fallback.put('embed_pool_order', ids);

  Future<void> dispose() async {
    await _providers.close();
    await _active.close();
    await _fallback.close();
  }
}
