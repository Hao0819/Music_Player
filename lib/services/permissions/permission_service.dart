import 'package:permission_handler/permission_handler.dart';

/// Wraps the single permission this app actually needs: read access to
/// on-device audio. On Android 13+ that's [Permission.audio]; the plugin
/// transparently falls back to READ_EXTERNAL_STORAGE below API 33 based on
/// the manifest, so callers never need to branch on SDK version themselves.
class PermissionService {
  Future<PermissionStatus> status() => Permission.audio.status;

  Future<PermissionStatus> request() => Permission.audio.request();

  Future<bool> openSettings() => openAppSettings();
}
