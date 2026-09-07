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
