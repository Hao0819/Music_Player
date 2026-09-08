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

  /// Set once the user has seen this track in the "New audio" list, so it
  /// stops being advertised as new.
  @HiveField(4)
  bool acknowledged;

  /// True when the file was absent from the most recent scan — its folder
  /// links and history entries are now stale and can be cleaned up.
  @HiveField(5)
  bool missing;

  KnownTrackRecord({
    required this.path,
    required this.mediaStoreId,
    required this.firstSeenAt,
    required this.lastSeenAt,
    this.acknowledged = false,
    this.missing = false,
  });
}
