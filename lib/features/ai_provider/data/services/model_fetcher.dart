import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../models/ai_model_info.dart';

class ModelFetchResult {
  final List<AIModelInfo> models;
  final int latencyMs;

  const ModelFetchResult({required this.models, required this.latencyMs});
}

/// Fetches and normalizes the provider model catalog (GET /models).
/// Large catalogs (>50 entries) are parsed on a background isolate via
/// [compute] so the UI thread never blocks.
class ModelFetcher {
  const ModelFetcher._();

  static Future<ModelFetchResult> fetch({
    required String baseUrl,
    required String apiKey,
  }) async {
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 60),
        sendTimeout: const Duration(seconds: 30),
      ),
    );
    final stopwatch = Stopwatch()..start();
    final response = await dio.get<dynamic>(
      '/models',
      options: Options(
        headers: {'Authorization': 'Bearer $apiKey', 'Accept': 'application/json'},
      ),
    );
    stopwatch.stop();

    final data = response.data;
    final List<dynamic> rawList;
    if (data is Map<String, dynamic>) {
      rawList = data['data'] as List<dynamic>? ?? [];
    } else if (data is List) {
      rawList = data;
    } else {
      rawList = [];
    }

    final encoded = jsonEncode(rawList);
    final List<AIModelInfo> models;
    if (rawList.length > 50) {
      models = await compute(_parseModels, encoded);
    } else {
      models = _parseModels(encoded);
    }
    models.sort((a, b) => a.id.compareTo(b.id));
    return ModelFetchResult(models: models, latencyMs: stopwatch.elapsedMilliseconds);
  }

  static List<AIModelInfo> _parseModels(String encoded) {
    final list = jsonDecode(encoded) as List<dynamic>;
    return [
      for (final raw in list)
        if (raw is Map<String, dynamic>) _parseModel(raw),
    ];
  }

  static AIModelInfo _parseModel(Map<String, dynamic> json) {
    final id = (json['id'] as String? ?? '').toString();
    final ownedBy = (json['owned_by']?.toString() ?? '').toLowerCase();
    final idLower = id.toLowerCase();

    final isEmbedding = idLower.contains('embedding') ||
        idLower.contains('-embed') ||
        idLower.contains('embedqa') ||
        idLower.contains('nv-embed') ||
        idLower.contains('nemoretriever') ||
        idLower.contains('bge') ||
        idLower.contains('e5-');

    ModelModality modality;
    if (isEmbedding) {
      modality = ModelModality.embeddings;
    } else if (idLower.contains('vision') ||
        idLower.contains('omni') ||
        idLower.contains('multimodal') ||
        (json['input_modalities'] is List &&
            (json['input_modalities'] as List).contains('image'))) {
      modality = ModelModality.vision;
    } else {
      modality = ModelModality.text;
    }

    return AIModelInfo(
      id: id,
      ownedBy: ownedBy,
      contextWindow: (json['context_length'] as num?)?.toInt() ??
          (json['max_context_length'] as num?)?.toInt() ??
          0,
      modalityName: modality.name,
      familyName: _classifyFamily(idLower, ownedBy).name,
      pricingTierName: (json['pricing_tier'] as String? ?? '').toLowerCase() == 'paid'
          ? 'paid'
          : 'free',
      isChat: !isEmbedding,
      isEmbedding: isEmbedding,
      isVision: modality == ModelModality.vision,
    );
  }

  static ModelFamily _classifyFamily(String id, String ownedBy) {
    if (ownedBy.isNotEmpty) {
      if (ownedBy.contains('nvidia')) return ModelFamily.nvidia;
      if (ownedBy.contains('meta')) return ModelFamily.meta;
      if (ownedBy.contains('mistral')) return ModelFamily.mistral;
      if (ownedBy.contains('qwen') || ownedBy.contains('alibaba')) return ModelFamily.qwen;
      if (ownedBy.contains('deepseek')) return ModelFamily.deepseek;
      if (ownedBy.contains('openai')) return ModelFamily.openai;
      if (ownedBy.contains('anthropic')) return ModelFamily.anthropic;
      if (ownedBy.contains('google')) return ModelFamily.google;
    }
    if (id.startsWith('nvidia/') || id.contains('nemotron')) return ModelFamily.nvidia;
    if (id.contains('llama')) return ModelFamily.meta;
    if (id.contains('mistral') || id.contains('mixtral')) return ModelFamily.mistral;
    if (id.contains('qwen')) return ModelFamily.qwen;
    if (id.contains('deepseek')) return ModelFamily.deepseek;
    if (id.contains('gpt') || id.contains('o1') || id.contains('o3') || id.contains('o4')) {
      return ModelFamily.openai;
    }
    if (id.contains('claude')) return ModelFamily.anthropic;
    if (id.contains('gemini')) return ModelFamily.google;
    return ModelFamily.custom;
  }
}
