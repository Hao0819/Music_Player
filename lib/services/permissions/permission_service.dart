import 'package:permission_handler/permission_handler.dart';

/// The two permissions this app asks for.
///
/// Reading on-device audio is the one it cannot work without. On Android 13+
/// that's [Permission.audio]; the plugin transparently falls back to
/// READ_EXTERNAL_STORAGE below API 33 based on the manifest, so callers never
/// need to branch on SDK version themselves.
///
/// Posting notifications is optional and asked for separately, because the app
/// is perfectly usable without it — it just loses the lock-screen controls.
class PermissionService {
  Future<PermissionStatus> status() => Permission.audio.status;

  Future<PermissionStatus> request() => Permission.audio.request();

  /// The media notification's permission. Only a runtime permission from
  /// Android 13; below that the plugin reports it granted, so callers do not
  /// branch on version here either.
  Future<PermissionStatus> notificationStatus() => Permission.notification.status;

  Future<PermissionStatus> requestNotification() => Permission.notification.request();

  Future<bool> openSettings() => openAppSettings();
}
