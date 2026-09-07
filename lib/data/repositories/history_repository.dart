import 'package:hive/hive.dart';

import '../hive/hive_setup.dart';
import '../hive/models/play_history_entry.dart';

/// Append-only play log. "Recently played" and "most played" are both derived
/// by reading this back, so there's no separate counter to keep in sync.
class HistoryRepository {
  static const _maxEntries = 500;

  Box<PlayHistoryEntry> get _box => Hive.box<PlayHistoryEntry>(HiveBoxes.playHistory);

  Future<void> recordPlay(String trackPath) async {
    await _box.add(PlayHistoryEntry(trackPath: trackPath, playedAt: DateTime.now()));
    if (_box.length > _maxEntries) {
      await _box.deleteAll(_box.keys.take(_box.length - _maxEntries).toList());
    }
  }

  Set<String> recentlyPlayedPaths({required Duration within}) {
    final cutoff = DateTime.now().subtract(within);
    return _box.values.where((entry) => entry.playedAt.isAfter(cutoff)).map((entry) => entry.trackPath).toSet();
  }

  /// Distinct track paths, most recently played first.
  List<String> recentPaths({int limit = 50}) {
    final entries = _box.values.toList()..sort((a, b) => b.playedAt.compareTo(a.playedAt));
    final seen = <String>{};
    for (final entry in entries) {
      seen.add(entry.trackPath);
      if (seen.length >= limit) break;
    }
    return seen.toList();
  }

  List<String> mostPlayedPaths({int limit = 50}) {
    final counts = <String, int>{};
    for (final entry in _box.values) {
      counts[entry.trackPath] = (counts[entry.trackPath] ?? 0) + 1;
    }
    final sorted = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(limit).map((entry) => entry.key).toList();
  }
}
