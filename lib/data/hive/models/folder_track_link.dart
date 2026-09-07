import 'package:hive/hive.dart';

part 'folder_track_link.g.dart';

/// Maps a folder to a track by file path. Deliberately holds no metadata —
/// title/artist/cover/duration are always re-read live from on_audio_query,
/// so this stays valid even if the real file is later deleted or moved.
@HiveType(typeId: 1)
class FolderTrackLink extends HiveObject {
  @HiveField(0)
  String folderId;

  @HiveField(1)
  String trackPath;

  @HiveField(2)
  DateTime addedAt;

  @HiveField(3)
  int manualOrder;

  FolderTrackLink({
    required this.folderId,
    required this.trackPath,
    required this.addedAt,
    required this.manualOrder,
  });
}
