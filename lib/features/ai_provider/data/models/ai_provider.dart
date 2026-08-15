import 'package:hive/hive.dart';

part 'ai_provider.g.dart';

/// Provider categories the app understands. `custom` covers any
/// OpenAI-compatible endpoint that is not one of the known brands.
enum ProviderType { groq, openrouter, nvidia, anthropic, openai, custom }

enum ConnectionStatus { connected, error, untested, rateExhausted }

@HiveType(typeId: 0)
class AIProvider extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String displayName;

  @HiveField(2)
  final String baseUrl;

  /// Reference (key name) into FlutterSecureStorage where the real key lives.
  @HiveField(3)
  final String apiKeyRef;

  @HiveField(4)
  final String typeName;

  @HiveField(5)
  final String? iconAsset;

  @HiveField(6)
  final bool isActive;

  @HiveField(7)
  final DateTime addedAt;

  @HiveField(8)
  final DateTime? lastTestedAt;

  @HiveField(9)
  final String lastStatusName;

  @HiveField(10)
  final List<String> cachedModelIds;

  @HiveField(11)
  final String? activeChatModelId;

  @HiveField(12)
  final String? activeEmbeddingModelId;

  /// modelId -> priority (lower = higher priority). Used for auto-switch.
  @HiveField(13)
  final Map<String, int> fallbackOrder;

  AIProvider({
    required this.id,
    required this.displayName,
    required this.baseUrl,
    required this.apiKeyRef,
    this.typeName = 'custom',
    this.iconAsset,
    this.isActive = false,
    required this.addedAt,
    this.lastTestedAt,
    this.lastStatusName = 'untested',
    this.cachedModelIds = const [],
    this.activeChatModelId,
    this.activeEmbeddingModelId,
    this.fallbackOrder = const {},
  });

  ProviderType get type =>
      ProviderType.values.firstWhere((t) => t.name == typeName, orElse: () => ProviderType.custom);

  ConnectionStatus get lastStatus => ConnectionStatus.values.firstWhere(
        (s) => s.name == lastStatusName,
        orElse: () => ConnectionStatus.untested,
      );

  bool get isConfigured =>
      activeChatModelId != null && activeChatModelId!.isNotEmpty && baseUrl.isNotEmpty;

  AIProvider copyWith({
    String? displayName,
    String? baseUrl,
    String? apiKeyRef,
    String? typeName,
    String? iconAsset,
    bool? isActive,
    DateTime? lastTestedAt,
    String? lastStatusName,
    List<String>? cachedModelIds,
    String? activeChatModelId,
    String? activeEmbeddingModelId,
    Map<String, int>? fallbackOrder,
    bool clearChatModel = false,
    bool clearEmbeddingModel = false,
  }) {
    return AIProvider(
      id: id,
      displayName: displayName ?? this.displayName,
      baseUrl: baseUrl ?? this.baseUrl,
      apiKeyRef: apiKeyRef ?? this.apiKeyRef,
      typeName: typeName ?? this.typeName,
      iconAsset: iconAsset ?? this.iconAsset,
      isActive: isActive ?? this.isActive,
      addedAt: addedAt,
      lastTestedAt: lastTestedAt ?? this.lastTestedAt,
      lastStatusName: lastStatusName ?? this.lastStatusName,
      cachedModelIds: cachedModelIds ?? this.cachedModelIds,
      activeChatModelId:
          clearChatModel ? null : (activeChatModelId ?? this.activeChatModelId),
      activeEmbeddingModelId: clearEmbeddingModel
          ? null
          : (activeEmbeddingModelId ?? this.activeEmbeddingModelId),
      fallbackOrder: fallbackOrder ?? this.fallbackOrder,
    );
  }
}
