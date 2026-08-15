// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rate_limit_snapshot.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class RateLimitSnapshotAdapter extends TypeAdapter<RateLimitSnapshot> {
  @override
  final int typeId = 2;

  @override
  RateLimitSnapshot read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return RateLimitSnapshot(
      providerId: fields[0] as String,
      modelId: fields[1] as String,
      limitRequests: fields[2] as int?,
      limitTokens: fields[3] as int?,
      remainingRequests: fields[4] as int?,
      remainingTokens: fields[5] as int?,
      resetRequestsAt: fields[6] as DateTime?,
      resetTokensAt: fields[7] as DateTime?,
      usedRequests: fields[8] as int?,
      capturedAt: fields[9] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, RateLimitSnapshot obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.providerId)
      ..writeByte(1)
      ..write(obj.modelId)
      ..writeByte(2)
      ..write(obj.limitRequests)
      ..writeByte(3)
      ..write(obj.limitTokens)
      ..writeByte(4)
      ..write(obj.remainingRequests)
      ..writeByte(5)
      ..write(obj.remainingTokens)
      ..writeByte(6)
      ..write(obj.resetRequestsAt)
      ..writeByte(7)
      ..write(obj.resetTokensAt)
      ..writeByte(8)
      ..write(obj.usedRequests)
      ..writeByte(9)
      ..write(obj.capturedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RateLimitSnapshotAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
