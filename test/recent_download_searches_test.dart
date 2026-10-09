import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:music_player/data/hive/hive_setup.dart';
import 'package:music_player/data/hive/models/app_settings_model.dart';
import 'package:music_player/data/repositories/settings_repository.dart';
import 'package:music_player/features/download/providers/download_providers.dart';

/// The recent-search list is short and shared with disk, so the rules about
/// what gets dropped are the whole feature.
void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('recent_searches_test');
    Hive.init(directory.path);
    if (!Hive.isAdapterRegistered(4)) Hive.registerAdapter(AppSettingsModelAdapter());
    await Hive.openBox<AppSettingsModel>(HiveBoxes.settings);
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await Hive.close();
    if (directory.existsSync()) directory.deleteSync(recursive: true);
  });

  RecentDownloadSearchesNotifier notifierIn(ProviderContainer container) =>
      container.read(recentDownloadSearchesProvider.notifier);

  ProviderContainer freshContainer() {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    return container;
  }

  test('starts empty on settings written before the field existed', () {
    expect(freshContainer().read(recentDownloadSearchesProvider), isEmpty);
  });

  test('keeps the newest first', () async {
    final container = freshContainer();
    await notifierIn(container).remember('first');
    await notifierIn(container).remember('second');

    expect(container.read(recentDownloadSearchesProvider), ['second', 'first']);
  });

  test('moves a repeat to the front instead of listing it twice', () async {
    final container = freshContainer();
    for (final query in ['a', 'b', 'c']) {
      await notifierIn(container).remember(query);
    }
    await notifierIn(container).remember('A');

    expect(container.read(recentDownloadSearchesProvider), ['A', 'c', 'b']);
  });

  test('drops the oldest past the limit', () async {
    final container = freshContainer();
    for (var i = 1; i <= SettingsRepository.recentDownloadSearchLimit + 2; i++) {
      await notifierIn(container).remember('query $i');
    }

    final recent = container.read(recentDownloadSearchesProvider);
    expect(recent, hasLength(SettingsRepository.recentDownloadSearchLimit));
    expect(recent.first, 'query ${SettingsRepository.recentDownloadSearchLimit + 2}');
    expect(recent, isNot(contains('query 1')));
  });

  test('ignores a blank query', () async {
    final container = freshContainer();
    await notifierIn(container).remember('   ');

    expect(container.read(recentDownloadSearchesProvider), isEmpty);
  });

  test('survives a restart, and forget and clear reach disk', () async {
    final first = freshContainer();
    await notifierIn(first).remember('kept');
    await notifierIn(first).remember('dropped');
    await notifierIn(first).forget('dropped');

    // A second container reads the box fresh, which is what the next launch
    // does — the point of persisting these at all.
    final second = freshContainer();
    expect(second.read(recentDownloadSearchesProvider), ['kept']);

    await notifierIn(second).clear();
    expect(freshContainer().read(recentDownloadSearchesProvider), isEmpty);
  });
}
