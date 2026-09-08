// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'known_track_record.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class KnownTrackRecordAdapter extends TypeAdapter<KnownTrackRecord> {
  @override
  final int typeId = 2;

  @override
  KnownTrackRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return KnownTrackRecord(
      path: fields[0] as String,
      mediaStoreId: fields[1] as int,
      firstSeenAt: fields[2] as DateTime,
      lastSeenAt: fields[3] as DateTime,
      acknowledged: fields[4] as bool,
      missing: fields[5] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, KnownTrackRecord obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.path)
      ..writeByte(1)
      ..write(obj.mediaStoreId)
      ..writeByte(2)
      ..write(obj.firstSeenAt)
      ..writeByte(3)
      ..write(obj.lastSeenAt)
      ..writeByte(4)
      ..write(obj.acknowledged)
      ..writeByte(5)
      ..write(obj.missing);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KnownTrackRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
