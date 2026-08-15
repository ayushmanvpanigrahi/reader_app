import 'package:hive/hive.dart';

import '../models/ai_model_info.dart';

/// Caches fetched model catalogs in the Hive `model_cache` box with a 1-hour
/// TTL so the catalog is not re-fetched on every screen open.
class ModelRepository {
  static const _cacheBox = 'model_cache';
  static const _ttl = Duration(hours: 1);

  late final Box<dynamic> _cache;

  Future<void> init() async {
    _cache = await Hive.openBox(_cacheBox);
  }

  List<AIModelInfo>? cached(String providerId) {
    final raw = _cache.get('${providerId}_models');
    if (raw is! List) return null;
    return raw.cast<AIModelInfo>().toList();
  }

  bool isFresh(String providerId) {
    final at = _cache.get('${providerId}_cached_at') as int?;
    if (at == null) return false;
    return DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(at)) < _ttl;
  }

  Future<void> cache(String providerId, List<AIModelInfo> models) async {
    await _cache.put('${providerId}_models', models);
    await _cache.put('${providerId}_cached_at', DateTime.now().millisecondsSinceEpoch);
  }

  Future<void> clear(String providerId) async {
    await _cache.delete('${providerId}_models');
    await _cache.delete('${providerId}_cached_at');
  }
}
