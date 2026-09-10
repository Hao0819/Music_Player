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

    // Everything that actually changed, written in one batch. Writing per
    // track meant one disk write per song on every scan, which stalls badly
    // on a real library.
    final pending = <String, KnownTrackRecord>{};
    final newPaths = <String>{};

    for (final entry in scannedPathsToIds.entries) {
      final existing = _box.get(entry.key);

      if (existing == null) {
        if (!isFirstScan) newPaths.add(entry.key);
        pending[entry.key] = KnownTrackRecord(
          path: entry.key,
          mediaStoreId: entry.value,
          firstSeenAt: now,
          lastSeenAt: now,
          // Nothing to announce about a library the user already had.
          acknowledged: isFirstScan,
        );
        continue;
      }

      // Only rewrite when something meaningful moved. An unchanged library
      // should cost zero writes.
      if (existing.mediaStoreId == entry.value && !existing.missing) continue;

      pending[entry.key] = KnownTrackRecord(
        path: existing.path,
        mediaStoreId: entry.value,
        firstSeenAt: existing.firstSeenAt,
        lastSeenAt: now,
        acknowledged: existing.acknowledged,
        missing: false,
      );
    }

    final missingPaths = <String>{};
    for (final record in _box.values) {
      if (scannedPaths.contains(record.path)) continue;
      missingPaths.add(record.path);
      if (record.missing) continue;

      pending[record.path] = KnownTrackRecord(
        path: record.path,
        mediaStoreId: record.mediaStoreId,
        firstSeenAt: record.firstSeenAt,
        lastSeenAt: record.lastSeenAt,
        acknowledged: record.acknowledged,
        missing: true,
      );
    }

    if (pending.isNotEmpty) await _box.putAll(pending);

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

  Future<void> acknowledge(Iterable<String> paths) =>
      _markAcknowledged(paths.map(_box.get).whereType<KnownTrackRecord>());

  Future<void> acknowledgeAll() => _markAcknowledged(_box.values);

  Future<void> _markAcknowledged(Iterable<KnownTrackRecord> records) async {
    final pending = <String, KnownTrackRecord>{};
    for (final record in records) {
      if (record.acknowledged) continue;
      pending[record.path] = KnownTrackRecord(
        path: record.path,
        mediaStoreId: record.mediaStoreId,
        firstSeenAt: record.firstSeenAt,
        lastSeenAt: record.lastSeenAt,
        acknowledged: true,
        missing: record.missing,
      );
    }
    if (pending.isNotEmpty) await _box.putAll(pending);
  }

  Future<void> forget(Iterable<String> paths) => _box.deleteAll(paths);
}
