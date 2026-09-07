import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/permissions/permission_provider.dart';

/// Shown in place of the app shell until audio permission is granted.
/// Never a blocking system dialog on its own — explains why the app needs
/// access, then either requests it or, once permanently denied, links out
/// to system settings since re-requesting would silently no-op there.
class PermissionGateScreen extends ConsumerWidget {
  const PermissionGateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(audioPermissionProvider).value ?? PermissionStatus.denied;
    final isPermanentlyDenied = status.isPermanentlyDenied;
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.audiotrack_rounded, size: 64, color: theme.colorScheme.primary),
                const SizedBox(height: 20),
                Text('Access your music', style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                Text(
                  isPermanentlyDenied
                      ? "Audio access was denied. Enable it from system settings so this app can find your local music."
                      : "This app reads your device's local audio files to build your library. Nothing leaves your device.",
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 28),
                FilledButton(
                  onPressed: () {
                    if (isPermanentlyDenied) {
                      ref.read(permissionServiceProvider).openSettings();
                    } else {
                      ref.read(audioPermissionProvider.notifier).request();
                    }
                  },
                  child: Text(isPermanentlyDenied ? 'Open settings' : 'Grant access'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
