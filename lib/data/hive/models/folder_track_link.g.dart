// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'folder_track_link.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class FolderTrackLinkAdapter extends TypeAdapter<FolderTrackLink> {
  @override
  final int typeId = 1;

  @override
  FolderTrackLink read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FolderTrackLink(
      folderId: fields[0] as String,
      trackPath: fields[1] as String,
      addedAt: fields[2] as DateTime,
      manualOrder: fields[3] as int,
    );
  }

  @override
  void write(BinaryWriter writer, FolderTrackLink obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.folderId)
      ..writeByte(1)
      ..write(obj.trackPath)
      ..writeByte(2)
      ..write(obj.addedAt)
      ..writeByte(3)
      ..write(obj.manualOrder);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FolderTrackLinkAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
