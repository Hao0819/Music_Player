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

  AppSettingsModel({
    this.themeMode = 'system',
    this.librarySortField = 'title',
    this.librarySortAscending = true,
  });
}
