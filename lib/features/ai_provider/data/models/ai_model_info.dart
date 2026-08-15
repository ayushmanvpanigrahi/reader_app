import 'package:hive/hive.dart';

part 'ai_model_info.g.dart';

enum ModelModality { text, embeddings, vision, image }

enum ModelFamily { meta, mistral, qwen, deepseek, openai, anthropic, google, nvidia, custom }

enum PricingTier { free, paid }

enum ModelCategory { textGeneration, embedding, vision, imageGeneration, audio, unknown }

/// Runtime embedding spec for a model. Derived on the fly from the cached
/// [AIModelInfo] — nothing is persisted, so dimensions fall back to known
/// values for common embedding models when the provider does not expose them.
class EmbeddingSpec {
  final int? dimensions;
  final int? maxInputTokens;
  final String? similarity;

  const EmbeddingSpec({this.dimensions, this.maxInputTokens, this.similarity});
}

int? knownEmbeddingDimensions(String id) {
  final i = id.toLowerCase();
  if (i.contains('text-embedding-3-small')) return 1536;
  if (i.contains('text-embedding-3-large')) return 3072;
  if (i.contains('text-embedding-ada') || i.contains('text-embedding-004')) return 768;
  if (i.contains('nomic-embed')) return 768;
  if (i.contains('nemotron-3-embed')) return 2048;
  if (i.contains('nv-embedqa')) return 1024;
  if (i.contains('nv-embed-v1')) return 2048;
  if (i.contains('e5-base')) return 768;
  if (i.contains('e5-large')) return 1024;
  if (i.contains('bge-small')) return 384;
  if (i.contains('bge-base')) return 768;
  if (i.contains('bge-large')) return 1024;
  if (i.contains('gte-base')) return 768;
  if (i.contains('gte-large')) return 1024;
  return null;
}

@HiveType(typeId: 1)
class AIModelInfo extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String ownedBy;

  @HiveField(2)
  final int contextWindow;

  @HiveField(3)
  final String modalityName;

  @HiveField(4)
  final String familyName;

  @HiveField(5)
  final String pricingTierName;

  @HiveField(6)
  final bool isChat;

  @HiveField(7)
  final bool isEmbedding;

  @HiveField(8)
  final bool isVision;

  AIModelInfo({
    required this.id,
    this.ownedBy = '',
    this.contextWindow = 0,
    this.modalityName = 'text',
    this.familyName = 'custom',
    this.pricingTierName = 'free',
    this.isChat = true,
    this.isEmbedding = false,
    this.isVision = false,
  });

  ModelModality get modality => ModelModality.values.firstWhere(
        (m) => m.name == modalityName,
        orElse: () => ModelModality.text,
      );

  ModelFamily get family => ModelFamily.values.firstWhere(
        (f) => f.name == familyName,
        orElse: () => ModelFamily.custom,
      );

  PricingTier get pricingTier => PricingTier.values.firstWhere(
        (t) => t.name == pricingTierName,
        orElse: () => PricingTier.free,
      );

  bool get isFree => pricingTier == PricingTier.free;

  ModelCategory get category => switch (modality) {
        ModelModality.embeddings => ModelCategory.embedding,
        ModelModality.vision => ModelCategory.vision,
        ModelModality.image => ModelCategory.imageGeneration,
        ModelModality.text => ModelCategory.textGeneration,
      };

  EmbeddingSpec? get embeddingSpec => category == ModelCategory.embedding
      ? EmbeddingSpec(
          dimensions: knownEmbeddingDimensions(id),
          maxInputTokens: contextWindow > 0 ? contextWindow : null,
        )
      : null;

  AIModelInfo copyWith({
    String? id,
    String? ownedBy,
    int? contextWindow,
    String? modalityName,
    String? familyName,
    String? pricingTierName,
    bool? isChat,
    bool? isEmbedding,
    bool? isVision,
  }) {
    return AIModelInfo(
      id: id ?? this.id,
      ownedBy: ownedBy ?? this.ownedBy,
      contextWindow: contextWindow ?? this.contextWindow,
      modalityName: modalityName ?? this.modalityName,
      familyName: familyName ?? this.familyName,
      pricingTierName: pricingTierName ?? this.pricingTierName,
      isChat: isChat ?? this.isChat,
      isEmbedding: isEmbedding ?? this.isEmbedding,
      isVision: isVision ?? this.isVision,
    );
  }
}
