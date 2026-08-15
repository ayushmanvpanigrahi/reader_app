// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ai_provider.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AIProviderAdapter extends TypeAdapter<AIProvider> {
  @override
  final int typeId = 0;

  @override
  AIProvider read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AIProvider(
      id: fields[0] as String,
      displayName: fields[1] as String,
      baseUrl: fields[2] as String,
      apiKeyRef: fields[3] as String,
      typeName: fields[4] as String,
      iconAsset: fields[5] as String?,
      isActive: fields[6] as bool,
      addedAt: fields[7] as DateTime,
      lastTestedAt: fields[8] as DateTime?,
      lastStatusName: fields[9] as String,
      cachedModelIds: (fields[10] as List).cast<String>(),
      activeChatModelId: fields[11] as String?,
      activeEmbeddingModelId: fields[12] as String?,
      fallbackOrder: (fields[13] as Map).cast<String, int>(),
    );
  }

  @override
  void write(BinaryWriter writer, AIProvider obj) {
    writer
      ..writeByte(14)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.displayName)
      ..writeByte(2)
      ..write(obj.baseUrl)
      ..writeByte(3)
      ..write(obj.apiKeyRef)
      ..writeByte(4)
      ..write(obj.typeName)
      ..writeByte(5)
      ..write(obj.iconAsset)
      ..writeByte(6)
      ..write(obj.isActive)
      ..writeByte(7)
      ..write(obj.addedAt)
      ..writeByte(8)
      ..write(obj.lastTestedAt)
      ..writeByte(9)
      ..write(obj.lastStatusName)
      ..writeByte(10)
      ..write(obj.cachedModelIds)
      ..writeByte(11)
      ..write(obj.activeChatModelId)
      ..writeByte(12)
      ..write(obj.activeEmbeddingModelId)
      ..writeByte(13)
      ..write(obj.fallbackOrder);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AIProviderAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
