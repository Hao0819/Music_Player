import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../library/providers/library_providers.dart';
import '../providers/maintenance_providers.dart';
import '../providers/theme_mode_provider.dart';

final _packageInfoProvider = FutureProvider<PackageInfo>((ref) => PackageInfo.fromPlatform());

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final stale = ref.watch(staleRecordsProvider);
    final packageInfo = ref.watch(_packageInfoProvider).value;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          _SectionHeader(title: 'Appearance'),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(value: ThemeMode.system, label: Text('System'), icon: Icon(Icons.brightness_auto)),
                ButtonSegment(value: ThemeMode.light, label: Text('Light'), icon: Icon(Icons.light_mode)),
                ButtonSegment(value: ThemeMode.dark, label: Text('Dark'), icon: Icon(Icons.dark_mode)),
              ],
              selected: {themeMode},
              onSelectionChanged: (selection) =>
                  ref.read(themeModeProvider.notifier).setThemeMode(selection.first),
            ),
          ),
          const Divider(height: 32),

          _SectionHeader(title: 'Library'),
          ListTile(
            leading: const Icon(Icons.refresh),
            title: const Text('Rescan device'),
            subtitle: const Text('Look for audio added or removed since the last scan'),
            onTap: () async {
              await ref.read(libraryScanProvider.notifier).refresh();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Rescan finished')),
              );
            },
          ),
          ListTile(
            leading: Icon(
              stale.isEmpty ? Icons.check_circle_outline : Icons.cleaning_services_outlined,
              color: stale.isEmpty ? null : theme.colorScheme.error,
            ),
            title: const Text('Clean up missing files'),
            subtitle: Text(
              stale.isEmpty
                  ? 'Nothing to clean up'
                  : '${stale.missingPaths.length} file${stale.missingPaths.length == 1 ? '' : 's'} '
                      'no longer on this device',
            ),
            enabled: !stale.isEmpty,
            onTap: stale.isEmpty ? null : () => _confirmCleanup(context, ref, stale),
          ),
          const Divider(height: 32),

          _SectionHeader(title: 'About'),
          ListTile(
            leading: const Icon(Icons.music_note_outlined),
            title: Text(packageInfo?.appName ?? 'Music Player'),
            subtitle: Text(
              packageInfo == null
                  ? 'Local audio player'
                  : 'Version ${packageInfo.version} (build ${packageInfo.buildNumber})',
            ),
          ),
          const ListTile(
            leading: Icon(Icons.lock_outline),
            title: Text('Everything stays on your device'),
            subtitle: Text(
              'Your library, folders and play history are stored locally. '
              'Nothing is uploaded anywhere.',
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _confirmCleanup(BuildContext context, WidgetRef ref, StaleRecords stale) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clean up missing files?'),
        content: Text(
          '${stale.missingPaths.length} audio file(s) that used to be on this device are gone.\n\n'
          'This removes ${stale.folderLinks} folder entr${stale.folderLinks == 1 ? 'y' : 'ies'} '
          'and ${stale.historyEntries} history entr${stale.historyEntries == 1 ? 'y' : 'ies'} '
          'pointing at them.\n\n'
          'Your other folders, favorites and audio files are not affected.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Clean up')),
        ],
      ),
    );

    if (confirmed != true) return;

    await ref.read(maintenanceActionsProvider).cleanUpStaleRecords();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cleaned up records for missing files')),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
