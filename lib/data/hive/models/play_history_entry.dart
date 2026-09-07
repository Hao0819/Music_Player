import 'package:hive/hive.dart';

part 'play_history_entry.g.dart';

/// Append-only play log. "Most played" is derived by grouping this by
/// [trackPath] rather than maintaining a separate counter.
@HiveType(typeId: 3)
class PlayHistoryEntry extends HiveObject {
  @HiveField(0)
  String trackPath;

  @HiveField(1)
  DateTime playedAt;

  PlayHistoryEntry({required this.trackPath, required this.playedAt});
}
