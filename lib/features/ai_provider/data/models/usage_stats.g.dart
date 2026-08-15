// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'usage_stats.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class UsageStatsAdapter extends TypeAdapter<UsageStats> {
  @override
  final int typeId = 3;

  @override
  UsageStats read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return UsageStats(
      providerId: fields[0] as String,
      modelId: fields[1] as String,
      totalRequests: fields[2] as int,
      totalPromptTokens: fields[3] as int,
      totalCompletionTokens: fields[4] as int,
      totalTokens: fields[5] as int,
      avgLatencyMs: fields[6] as double,
      firstUsedAt: fields[7] as DateTime,
      lastUsedAt: fields[8] as DateTime,
      dailyHistory: (fields[9] as List).cast<DailyUsageBucket>(),
    );
  }

  @override
  void write(BinaryWriter writer, UsageStats obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.providerId)
      ..writeByte(1)
      ..write(obj.modelId)
      ..writeByte(2)
      ..write(obj.totalRequests)
      ..writeByte(3)
      ..write(obj.totalPromptTokens)
      ..writeByte(4)
      ..write(obj.totalCompletionTokens)
      ..writeByte(5)
      ..write(obj.totalTokens)
      ..writeByte(6)
      ..write(obj.avgLatencyMs)
      ..writeByte(7)
      ..write(obj.firstUsedAt)
      ..writeByte(8)
      ..write(obj.lastUsedAt)
      ..writeByte(9)
      ..write(obj.dailyHistory);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UsageStatsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
