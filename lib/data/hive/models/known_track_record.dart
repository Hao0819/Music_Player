import 'package:hive/hive.dart';

part 'known_track_record.g.dart';

/// Bookkeeping used to diff a fresh scan against what the app has already
/// seen, so new files can be surfaced for classification and files that
/// vanished from disk can be flagged for manual cleanup in Settings.
@HiveType(typeId: 2)
class KnownTrackRecord extends HiveObject {
  @HiveField(0)
  String path;

  @HiveField(1)
  int mediaStoreId;

  @HiveField(2)
  DateTime firstSeenAt;

  @HiveField(3)
  DateTime lastSeenAt;

  KnownTrackRecord({
    required this.path,
    required this.mediaStoreId,
    required this.firstSeenAt,
    required this.lastSeenAt,
  });
}
