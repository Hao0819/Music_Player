import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import 'box_keys.dart';
import 'hive_setup.dart';
import 'models/folder_track_link.dart';
import 'models/known_track_record.dart';

/// Rewrites entries left by the older layout, which used the file path itself
/// as the Hive key — see [trackKey] for why that destroys a box.
///
/// Runs once: afterwards every key is a digest, [isDigestKey] is true for all
/// of them, and this does nothing.
Future<void> migrateLegacyBoxKeys() async {
  await _rewrite<KnownTrackRecord>(
    HiveBoxes.knownTracks,
    keyFor: (record) => trackKey(record.path),
    // Copied rather than re-put: a HiveObject carries the key it was read
    // under, and putting the same instance back under a different one is not
    // something Hive supports.
    copy: (record) => KnownTrackRecord(
      path: record.path,
      mediaStoreId: record.mediaStoreId,
      firstSeenAt: record.firstSeenAt,
      lastSeenAt: record.lastSeenAt,
      acknowledged: record.acknowledged,
      missing: record.missing,
    ),
  );

  await _rewrite<FolderTrackLink>(
    HiveBoxes.folderTrackLinks,
    keyFor: (link) => folderLinkKey(link.folderId, link.trackPath),
    copy: (link) => FolderTrackLink(
      folderId: link.folderId,
      trackPath: link.trackPath,
      addedAt: link.addedAt,
      manualOrder: link.manualOrder,
    ),
  );
}

Future<void> _rewrite<T>(
  String boxName, {
  required String Function(T) keyFor,
  required T Function(T) copy,
}) async {
  if (!Hive.isBoxOpen(boxName)) return;

  final box = Hive.box<T>(boxName);
  if (box.keys.every(isDigestKey)) return;

  final rewritten = <String, T>{};
  for (final key in box.keys.toList()) {
    final value = box.get(key);
    if (value != null) rewritten[keyFor(value)] = copy(value);
  }

  // Cleared rather than deleting the old keys one by one. A Hive delete writes
  // a tombstone frame that repeats the key — which for these keys is the very
  // thing that corrupts the file — while clear() truncates the file outright.
  // It leaves a window in which the box is empty on disk; that is a deliberate
  // trade for not re-writing a key that is known to break the box, and the
  // window only exists on the one launch that migrates.
  await box.clear();
  if (rewritten.isNotEmpty) await box.putAll(rewritten);

  debugPrint('Rewrote ${rewritten.length} ${box.name} entries onto digest keys.');
}
