import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../hive/hive_setup.dart';
import '../hive/models/app_settings_model.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) => SettingsRepository());

class SettingsRepository {
  static const _key = 'settings';

  Box<AppSettingsModel> get _box => Hive.box<AppSettingsModel>(HiveBoxes.settings);

  AppSettingsModel get current => _box.get(_key) ?? AppSettingsModel();

  Future<void> save(AppSettingsModel settings) => _box.put(_key, settings);

  Future<void> updateThemeMode(String themeMode) async {
    final settings = current;
    settings.themeMode = themeMode;
    await save(settings);
  }
}
