import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import 'permission_service.dart';

final permissionServiceProvider = Provider<PermissionService>((ref) => PermissionService());

class AudioPermissionNotifier extends AsyncNotifier<PermissionStatus> {
  @override
  Future<PermissionStatus> build() => ref.read(permissionServiceProvider).status();

  Future<void> request() async {
    final status = await ref.read(permissionServiceProvider).request();
    state = AsyncData(status);
  }

  Future<void> refresh() async {
    final status = await ref.read(permissionServiceProvider).status();
    state = AsyncData(status);
  }
}

final audioPermissionProvider =
    AsyncNotifierProvider<AudioPermissionNotifier, PermissionStatus>(AudioPermissionNotifier.new);

/// Whether the media notification is allowed to appear.
///
/// Kept apart from the audio permission because nothing is gated on it: the app
/// runs either way, and denying it costs the lock-screen and notification-shade
/// controls rather than the library.
class NotificationPermissionNotifier extends AsyncNotifier<PermissionStatus> {
  @override
  Future<PermissionStatus> build() => ref.read(permissionServiceProvider).notificationStatus();

  Future<void> request() async {
    state = AsyncData(await ref.read(permissionServiceProvider).requestNotification());
  }

  Future<void> refresh() async {
    state = AsyncData(await ref.read(permissionServiceProvider).notificationStatus());
  }
}

final notificationPermissionProvider =
    AsyncNotifierProvider<NotificationPermissionNotifier, PermissionStatus>(
  NotificationPermissionNotifier.new,
);
