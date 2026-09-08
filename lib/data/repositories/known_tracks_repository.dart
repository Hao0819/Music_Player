import 'package:hive/hive.dart';

import '../hive/hive_setup.dart';
import '../hive/models/known_track_record.dart';

/// Result of reconciling a fresh scan against what the app had seen before.
class ScanDiff {
  const ScanDiff({required this.newPaths, required this.missingPaths});

  const ScanDiff.empty() : newPaths = const {}, missingPaths = const {};

  /// Files seen for the first time. Empty on the very first scan — the whole
  /// library isn't "new", it's just the starting point.
  final Set<String> newPaths;

  /// Files known from an earlier scan that have since disappeared.
  final Set<String> missingPaths;
}

/// Tracks which files the app has already seen, so it can point out new
/// arrivals and flag records left behind by deleted files.
class KnownTracksRepository {
  Box<KnownTrackRecord> get _box => Hive.box<KnownTrackRecord>(HiveBoxes.knownTracks);

  /// Records the paths a scan turned up and reports what changed.
  Future<ScanDiff> reconcile(Map<String, int> scannedPathsToIds) async {
    final now = DateTime.now();
    final isFirstScan = _box.isEmpty;
    final scannedPaths = scannedPathsToIds.keys.toSet();

    final newPaths = <String>{};
    for (final entry in scannedPathsToIds.entries) {
      final existing = _box.get(entry.key);
      if (existing == null) {
        if (!isFirstScan) newPaths.add(entry.key);
        await _box.put(
          entry.key,
          KnownTrackRecord(
            path: entry.key,
            mediaStoreId: entry.value,
            firstSeenAt: now,
            lastSeenAt: now,
            // Nothing to announce about a library the user already had.
            acknowledged: isFirstScan,
          ),
        );
      } else {
        existing
          ..mediaStoreId = entry.value
          ..lastSeenAt = now
          ..missing = false;
        await existing.save();
      }
    }

    final missingPaths = <String>{};
    for (final record in _box.values) {
      if (scannedPaths.contains(record.path)) continue;
      missingPaths.add(record.path);
      if (!record.missing) {
        record.missing = true;
        await record.save();
      }
    }

    return ScanDiff(newPaths: newPaths, missingPaths: missingPaths);
  }

  /// Paths the user hasn't acknowledged yet, newest arrivals first.
  List<String> unacknowledgedPaths() {
    final records = _box.values.where((r) => !r.acknowledged && !r.missing).toList()
      ..sort((a, b) => b.firstSeenAt.compareTo(a.firstSeenAt));
    return records.map((record) => record.path).toList();
  }

  Set<String> missingPaths() =>
      _box.values.where((record) => record.missing).map((record) => record.path).toSet();

  Future<void> acknowledge(Iterable<String> paths) async {
    for (final path in paths) {
      final record = _box.get(path);
      if (record != null && !record.acknowledged) {
        record.acknowledged = true;
        await record.save();
      }
    }
  }

  Future<void> acknowledgeAll() async {
    for (final record in _box.values) {
      if (!record.acknowledged) {
        record.acknowledged = true;
        await record.save();
      }
    }
  }

  Future<void> forget(Iterable<String> paths) => _box.deleteAll(paths);
}
