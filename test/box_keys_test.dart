import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:music_player/data/hive/box_keys.dart';
import 'package:music_player/data/hive/hive_setup.dart';
import 'package:music_player/data/hive/key_migration.dart';
import 'package:music_player/data/hive/models/folder_model.dart';
import 'package:music_player/data/hive/models/folder_track_link.dart';
import 'package:music_player/data/hive/models/known_track_record.dart';
import 'package:music_player/data/repositories/folder_repository.dart';
import 'package:music_player/data/repositories/known_tracks_repository.dart';

/// A real-shaped path from the library this was found on: a video rip whose
/// title is Han characters, three UTF-8 bytes each. Comfortably past the 255
/// bytes Hive can express in a key's one-byte length field.
final longPath = '/storage/emulated/0/Download/'
    '${'我是歌手天赐的声音动态歌词高音质现场版' * 5}.m4a';

void main() {
  group('digest keys', () {
    test('are 40 ASCII characters whatever the path', () {
      expect(utf8.encode(longPath).length, greaterThan(255), reason: 'the premise');

      for (final path in [longPath, '/a.mp3', '', '/storage/emulated/0/Music/稻香.m4a']) {
        expect(trackKey(path).length, 40);
        expect(utf8.encode(trackKey(path)).length, 40);
        expect(isDigestKey(trackKey(path)), isTrue);
      }
    });

    test('a folder link stays bounded even with the folder id folded in', () {
      const folderId = '6f2b1c9e-7f3a-4c51-9a2e-0d4b8e1f6a37';
      final key = folderLinkKey(folderId, longPath);

      expect(utf8.encode(key).length, 40);
      expect(key, isNot(contains(folderId)), reason: 'the id is digested, not prefixed');
    });

    test('different inputs do not collide, and the same input is stable', () {
      expect(trackKey('/a.mp3'), trackKey('/a.mp3'));
      expect(trackKey('/a.mp3'), isNot(trackKey('/b.mp3')));
      expect(
        folderLinkKey('folder-1', '/a.mp3'),
        isNot(folderLinkKey('folder-2', '/a.mp3')),
      );
    });

    test('a raw path is not mistaken for a digest', () {
      expect(isDigestKey('/storage/emulated/0/Music/a.mp3'), isFalse);
      expect(isDigestKey('favorites'), isFalse);
      expect(isDigestKey('ABCDEF0123456789abcdef0123456789abcdef01'), isFalse,
          reason: 'upper case is not what sha1.toString() produces');
    });
  });

  group('against a real box', () {
    late Directory directory;

    Future<void> openBoxes() async {
      await Hive.openBox<FolderModel>(HiveBoxes.folders);
      await Hive.openBox<FolderTrackLink>(HiveBoxes.folderTrackLinks);
      await Hive.openBox<KnownTrackRecord>(HiveBoxes.knownTracks);
    }

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('box_keys_test');
      Hive.init(directory.path);
      if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(FolderModelAdapter());
      if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(FolderTrackLinkAdapter());
      if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(KnownTrackRecordAdapter());
      await openBoxes();
    });

    tearDown(() async {
      await Hive.deleteFromDisk();
      await Hive.close();
      if (directory.existsSync()) directory.deleteSync(recursive: true);
    });

    test('a scan holding an over-long path survives closing and reopening', () async {
      // The bug this guards: the write succeeds either way, and the damage only
      // shows on the next launch, so reopening is the whole test.
      await KnownTracksRepository().reconcile({longPath: 1, '/short.mp3': 2});

      await Hive.close();
      Hive.init(directory.path);
      await openBoxes();

      final records = Hive.box<KnownTrackRecord>(HiveBoxes.knownTracks).values;
      expect(records.map((record) => record.path), containsAll([longPath, '/short.mp3']));
    });

    test('a folder holding an over-long path survives closing and reopening', () async {
      final repository = FolderRepository()..ensureSystemFolders();
      final folder = await repository.createFolder('夜跑');
      await repository.addTracks(folder.id, [longPath, '/short.mp3']);

      await Hive.close();
      Hive.init(directory.path);
      await openBoxes();

      expect(FolderRepository().getTrackPaths(folder.id), [longPath, '/short.mp3']);
    });

    test('every key written is within what Hive can encode', () async {
      final repository = FolderRepository()..ensureSystemFolders();
      final folder = await repository.createFolder('夜跑');
      await repository.addTracks(folder.id, [longPath]);
      await repository.toggleFavorite(longPath);
      await KnownTracksRepository().reconcile({longPath: 1});

      final boxes = <String, Iterable<dynamic>>{
        HiveBoxes.folderTrackLinks: Hive.box<FolderTrackLink>(HiveBoxes.folderTrackLinks).keys,
        HiveBoxes.knownTracks: Hive.box<KnownTrackRecord>(HiveBoxes.knownTracks).keys,
      };
      for (final entry in boxes.entries) {
        for (final key in entry.value) {
          expect(utf8.encode('$key').length, lessThanOrEqualTo(255),
              reason: '${entry.key} key "$key"');
        }
      }
    });

    test('entries left by the path-keyed layout are rewritten once', () async {
      // Written the old way, with a path short enough that the box still opens
      // — which is the state an existing install is in.
      const legacyPath = '/storage/emulated/0/Music/old.mp3';
      await Hive.box<KnownTrackRecord>(HiveBoxes.knownTracks).put(
        legacyPath,
        KnownTrackRecord(
          path: legacyPath,
          mediaStoreId: 7,
          firstSeenAt: DateTime.utc(2026, 9, 1),
          lastSeenAt: DateTime.utc(2026, 10, 1),
          acknowledged: true,
        ),
      );
      await Hive.box<FolderTrackLink>(HiveBoxes.folderTrackLinks).put(
        'folder-1|$legacyPath',
        FolderTrackLink(
          folderId: 'folder-1',
          trackPath: legacyPath,
          addedAt: DateTime.utc(2026, 9, 2),
          manualOrder: 3,
        ),
      );

      await migrateLegacyBoxKeys();

      final known = Hive.box<KnownTrackRecord>(HiveBoxes.knownTracks);
      expect(known.keys.single, trackKey(legacyPath));
      expect(known.get(trackKey(legacyPath))?.acknowledged, isTrue);
      expect(known.get(trackKey(legacyPath))?.mediaStoreId, 7);

      final links = Hive.box<FolderTrackLink>(HiveBoxes.folderTrackLinks);
      expect(links.keys.single, folderLinkKey('folder-1', legacyPath));
      expect(FolderRepository().getTrackPaths('folder-1'), [legacyPath]);
      expect(links.values.single.manualOrder, 3);

      // Idempotent: a second launch has nothing to do.
      await migrateLegacyBoxKeys();
      expect(known.keys.single, trackKey(legacyPath));
      expect(links.keys.single, folderLinkKey('folder-1', legacyPath));
    });
  });
}
