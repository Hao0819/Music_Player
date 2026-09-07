// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'play_history_entry.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PlayHistoryEntryAdapter extends TypeAdapter<PlayHistoryEntry> {
  @override
  final int typeId = 3;

  @override
  PlayHistoryEntry read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PlayHistoryEntry(
      trackPath: fields[0] as String,
      playedAt: fields[1] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, PlayHistoryEntry obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.trackPath)
      ..writeByte(1)
      ..write(obj.playedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlayHistoryEntryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
