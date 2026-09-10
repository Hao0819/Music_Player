import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

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
}

Future<void> initHive() async {
  await Hive.initFlutter();

  Hive.registerAdapter(FolderModelAdapter());
  Hive.registerAdapter(FolderTrackLinkAdapter());
  Hive.registerAdapter(KnownTrackRecordAdapter());
  Hive.registerAdapter(PlayHistoryEntryAdapter());
  Hive.registerAdapter(AppSettingsModelAdapter());

  // Opened one at a time so a single unreadable box can be identified and
  // rebuilt, instead of one bad file taking the whole app down at launch.
  await _openBox<FolderModel>(HiveBoxes.folders);
  await _openBox<FolderTrackLink>(HiveBoxes.folderTrackLinks);
  await _openBox<KnownTrackRecord>(HiveBoxes.knownTracks);
  await _openBox<PlayHistoryEntry>(HiveBoxes.playHistory);
  await _openBox<AppSettingsModel>(HiveBoxes.settings);
}

/// Opens a box, and if its file is corrupt or was written by an incompatible
/// schema, discards just that box and starts it fresh. Losing one box's
/// contents is a far better outcome than an app that won't launch.
Future<void> _openBox<T>(String name) async {
  try {
    await Hive.openBox<T>(name);
  } catch (error) {
    debugPrint('Hive box "$name" could not be opened, rebuilding it: $error');
    try {
      await Hive.deleteBoxFromDisk(name);
    } catch (_) {
      // If even deleting fails there is nothing more to try here.
    }
    await Hive.openBox<T>(name);
  }
}
