// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'daily_usage_bucket.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DailyUsageBucketAdapter extends TypeAdapter<DailyUsageBucket> {
  @override
  final int typeId = 4;

  @override
  DailyUsageBucket read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DailyUsageBucket(
      day: fields[0] as DateTime,
      requests: fields[1] as int,
      tokens: fields[2] as int,
    );
  }

  @override
  void write(BinaryWriter writer, DailyUsageBucket obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.day)
      ..writeByte(1)
      ..write(obj.requests)
      ..writeByte(2)
      ..write(obj.tokens);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DailyUsageBucketAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
