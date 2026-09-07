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

  await Future.wait([
    Hive.openBox<FolderModel>(HiveBoxes.folders),
    Hive.openBox<FolderTrackLink>(HiveBoxes.folderTrackLinks),
    Hive.openBox<KnownTrackRecord>(HiveBoxes.knownTracks),
    Hive.openBox<PlayHistoryEntry>(HiveBoxes.playHistory),
    Hive.openBox<AppSettingsModel>(HiveBoxes.settings),
  ]);
}
