import 'package:hive/hive.dart';

part 'ai_model_info.g.dart';

enum ModelModality { text, embeddings, vision, image }

enum ModelFamily { meta, mistral, qwen, deepseek, openai, anthropic, google, nvidia, custom }

enum PricingTier { free, paid }

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
