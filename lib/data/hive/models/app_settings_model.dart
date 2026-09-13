import 'package:hive/hive.dart';

part 'app_settings_model.g.dart';

@HiveType(typeId: 4)
class AppSettingsModel extends HiveObject {
  @HiveField(0)
  String themeMode;

  @HiveField(1)
  String librarySortField;

  @HiveField(2)
  bool librarySortAscending;

  /// 'none' | 'all' | 'one'. Nullable because settings saved by older
  /// versions have no value here — null means the default, repeat all.
  @HiveField(3)
  String? repeatMode;

  AppSettingsModel({
    this.themeMode = 'system',
    this.librarySortField = 'title',
    this.librarySortAscending = true,
    this.repeatMode,
  });
}
