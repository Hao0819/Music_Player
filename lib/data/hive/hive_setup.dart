import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'models/app_settings_model.dart';
import 'models/folder_model.dart';
import 'models/folder_track_link.dart';
import 'models/known_track_record.dart';
import 'models/play_history_entry.dart';

class HiveBoxes {
  HiveBoxes._();

  static const folders = 'folders';
  static const folderTrackLinks = 'folder_track_links';
  static const knownTracks = 'known_tracks';
  static const playHistory = 'play_history';
  static const settings = 'settings';

  /// Untyped key/value box for the last playback session. Kept apart from
  /// [settings] so the frequent position saves don't rewrite everything else.
  static const playbackSession = 'playback_session';
}

/// A box whose file could not be read at launch and was renamed out of the
/// way so a fresh one could take its place.
class SetAsideBox {
  const SetAsideBox({required this.boxName, required this.savedPath});

  final String boxName;

  /// Where the unreadable file now lives. It is the only remaining copy of
  /// whatever was in that box, so it is worth showing to the user.
  final String savedPath;
}

/// Boxes set aside during this launch. Empty on a healthy start.
///
/// Reported in Settings rather than only logged: the contents of these boxes
/// are things the user made by hand, and a silent swap for an empty box looks
/// exactly like the app having lost their work for no reason.
final List<SetAsideBox> setAsideBoxes = [];

/// Where Hive keeps its box files, remembered so [_setAside] can find them.
String? _hiveHome;

Future<void> initHive() async {
  // Resolved here instead of through `Hive.initFlutter()` so the fallback
  // below knows the directory the box files are in. This is the same path
  // initFlutter picks, so boxes written by earlier versions are still found.
  final home = await getApplicationDocumentsDirectory();
  _hiveHome = home.path;
  Hive.init(home.path);

  Hive.registerAdapter(FolderModelAdapter());
  Hive.registerAdapter(FolderTrackLinkAdapter());
  Hive.registerAdapter(KnownTrackRecordAdapter());
  Hive.registerAdapter(PlayHistoryEntryAdapter());
  Hive.registerAdapter(AppSettingsModelAdapter());

  // Opened one at a time so a single unreadable box can be identified and
  // replaced, instead of one bad file taking the whole app down at launch.
  await _openBox<FolderModel>(HiveBoxes.folders);
  await _openBox<FolderTrackLink>(HiveBoxes.folderTrackLinks);
  await _openBox<KnownTrackRecord>(HiveBoxes.knownTracks);
  await _openBox<PlayHistoryEntry>(HiveBoxes.playHistory);
  await _openBox<AppSettingsModel>(HiveBoxes.settings);
  await _openBox<dynamic>(HiveBoxes.playbackSession);
}

/// Opens a box, and if its file cannot be read, moves that file aside and
/// starts a fresh box in its place.
///
/// The file is never deleted. Folders, favorites and play history are the only
/// things in this app that a rescan cannot rebuild, so the box file is their
/// single copy — an earlier version of this function called
/// `deleteBoxFromDisk` here, which turned one unreadable byte into the silent
/// loss of every folder link on the device with nothing left to recover from.
Future<void> _openBox<T>(String name) async {
  try {
    await Hive.openBox<T>(name);
    return;
  } catch (error) {
    debugPrint('Hive box "$name" did not open, retrying: $error');
  }

  // One retry, after a beat. A first failure is sometimes a lock file still
  // held by an instance of the app that is on its way out — worth ruling out
  // before treating the data as unreadable.
  await Future<void>.delayed(const Duration(milliseconds: 200));
  try {
    await Hive.openBox<T>(name);
    return;
  } catch (error) {
    debugPrint('Hive box "$name" is unreadable, setting it aside: $error');
  }

  if (await _setAside(name)) {
    await Hive.openBox<T>(name);
    return;
  }

  // The file could not be moved either. Open a box that exists only in
  // memory: the app still starts, the unreadable file is left untouched for
  // the next launch to retry, and the only cost is that nothing written this
  // session is kept.
  debugPrint('Hive box "$name" could not be set aside; running it in memory.');
  await Hive.openBox<T>(name, bytes: Uint8List(0));
}

/// Renames a box's data files to `<file>.corrupt-<timestamp>`, returning
/// whether the box's path is now clear for a fresh file.
Future<bool> _setAside(String name) async {
  final home = _hiveHome;
  if (home == null) return false;

  // Hive lower-cases box names when building its file names.
  final base = name.toLowerCase();
  final stamp = DateTime.now().toIso8601String().replaceAll(RegExp('[:.]'), '-');
  var movedAny = false;

  // `.hive` is the box, `.hivec` a compacted copy mid-swap; either can be the
  // one holding the data, so both move.
  for (final extension in const ['hive', 'hivec']) {
    final file = File(p.join(home, '$base.$extension'));
    if (!file.existsSync()) continue;

    final target = '${file.path}.corrupt-$stamp';
    try {
      await file.rename(target);
      setAsideBoxes.add(SetAsideBox(boxName: name, savedPath: target));
      movedAny = true;
    } catch (error) {
      // Leaving the file in place is the right failure here: the caller falls
      // back to an in-memory box rather than destroying anything.
      debugPrint('Could not set aside "${file.path}": $error');
      return false;
    }
  }

  // The lock file holds no data, so it is the one file safe to remove, and a
  // stale one can keep the replacement box from opening.
  try {
    final lock = File(p.join(home, '$base.lock'));
    if (lock.existsSync()) await lock.delete();
  } catch (_) {
    // Not worth failing startup over.
  }

  // Nothing to move means the box failed for some other reason — a missing
  // adapter, say — and a fresh file will not be any more readable.
  return movedAny;
}
