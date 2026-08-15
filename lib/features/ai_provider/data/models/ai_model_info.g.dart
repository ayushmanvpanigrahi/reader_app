// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ai_model_info.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AIModelInfoAdapter extends TypeAdapter<AIModelInfo> {
  @override
  final int typeId = 1;

  @override
  AIModelInfo read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AIModelInfo(
      id: fields[0] as String,
      ownedBy: fields[1] as String,
      contextWindow: fields[2] as int,
      modalityName: fields[3] as String,
      familyName: fields[4] as String,
      pricingTierName: fields[5] as String,
      isChat: fields[6] as bool,
      isEmbedding: fields[7] as bool,
      isVision: fields[8] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, AIModelInfo obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.ownedBy)
      ..writeByte(2)
      ..write(obj.contextWindow)
      ..writeByte(3)
      ..write(obj.modalityName)
      ..writeByte(4)
      ..write(obj.familyName)
      ..writeByte(5)
      ..write(obj.pricingTierName)
      ..writeByte(6)
      ..write(obj.isChat)
      ..writeByte(7)
      ..write(obj.isEmbedding)
      ..writeByte(8)
      ..write(obj.isVision);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AIModelInfoAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
