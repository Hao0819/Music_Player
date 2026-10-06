import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/date_format.dart';
import '../../../data/hive/hive_setup.dart';
import '../../../services/backup/folder_backup_store.dart';
import '../../../widgets/empty_state.dart';
import '../../player/widgets/mini_player.dart';
import '../providers/backup_providers.dart';

/// Export and restore of the folder structure.
///
/// Folders and favorites are the only data here that no rescan can rebuild,
/// so this screen is the app's answer to losing them: a plain JSON file, in a
/// directory a file manager can reach, that can be copied off the device.
class FolderBackupScreen extends ConsumerWidget {
  const FolderBackupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final preview = ref.watch(folderBackupPreviewProvider);
    final backupsAsync = ref.watch(folderBackupsProvider);
    final directory = ref.watch(folderBackupDirectoryProvider).value;
    final setAside = ref.watch(setAsideBoxesProvider);

    return Scaffold(
      bottomNavigationBar: const MiniPlayer(isBottomMost: true),
      appBar: AppBar(title: const Text('Folder backup')),
      body: ListView(
        children: [
          if (setAside.isNotEmpty) _SetAsideNotice(setAside: setAside),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'A backup is a small text file listing your folders and the '
              'tracks in them. Your audio files are not copied or moved.',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: FilledButton.icon(
              icon: const Icon(Icons.save_alt),
              label: Text(
                'Export ${countLabel(preview.folders.length, 'folder')} '
                '(${countLabel(preview.trackCount, 'entry', plural: 'entries')})',
              ),
              onPressed: () => _export(context, ref),
            ),
          ),
          if (directory != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: SelectableText(
                directory,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          const Divider(height: 24),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text('Saved backups', style: theme.textTheme.titleSmall),
          ),
          ..._backupList(backupsAsync),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  List<Widget> _backupList(AsyncValue<List<StoredFolderBackup>> backupsAsync) {
    return switch (backupsAsync) {
      AsyncError(:final error) => [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text("Couldn't read the backup folder: $error"),
          ),
        ],
      AsyncData(:final value) when value.isEmpty => const [
          Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: EmptyState(
              icon: Icons.inventory_2_outlined,
              title: 'No backups yet',
              message: 'Export one now, then copy the file somewhere safe.',
            ),
          ),
        ],
      AsyncData(:final value) => [for (final stored in value) _BackupTile(stored: stored)],
      _ => const [
          Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
        ],
    };
  }

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final stored = await ref.read(folderBackupActionsProvider).exportNow();
      messenger.showSnackBar(SnackBar(content: Text('Saved ${stored.fileName}')));
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text("Couldn't write the backup: $error")));
    }
  }
}

/// Said out loud, because the alternative is the user meeting this as
/// "my folders are empty and I have no idea why".
class _SetAsideNotice extends StatelessWidget {
  const _SetAsideNotice({required this.setAside});

  final List<SetAsideBox> setAside;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onError = theme.colorScheme.onErrorContainer;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: onError),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Some saved data could not be read',
                  style: theme.textTheme.titleSmall?.copyWith(color: onError),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'This launch had to start it over. The old file was kept, not '
            'deleted — if you need what was in it, copy it off the device '
            'before reinstalling the app.',
            style: theme.textTheme.bodySmall?.copyWith(color: onError),
          ),
          const SizedBox(height: 8),
          for (final box in setAside)
            SelectableText(
              box.savedPath,
              style: theme.textTheme.bodySmall?.copyWith(color: onError, fontFamily: 'monospace'),
            ),
        ],
      ),
    );
  }
}

class _BackupTile extends ConsumerWidget {
  const _BackupTile({required this.stored});

  final StoredFolderBackup stored;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final backup = stored.backup;

    return ListTile(
      leading: Icon(backup == null ? Icons.broken_image_outlined : Icons.description_outlined),
      title: Text(backup == null ? stored.fileName : formatTimestamp(backup.createdAt)),
      subtitle: Text(
        backup == null
            ? 'Not a readable backup'
            : '${countLabel(backup.folders.length, 'folder')} · '
                '${countLabel(backup.trackCount, 'entry', plural: 'entries')}',
      ),
      trailing: PopupMenuButton<String>(
        onSelected: (action) =>
            action == 'restore' ? _confirmRestore(context, ref) : _confirmDelete(context, ref),
        itemBuilder: (context) => [
          if (backup != null) const PopupMenuItem(value: 'restore', child: Text('Restore')),
          const PopupMenuItem(value: 'delete', child: Text('Delete backup')),
        ],
      ),
      onTap: backup == null ? null : () => _confirmRestore(context, ref),
    );
  }

  Future<void> _confirmRestore(BuildContext context, WidgetRef ref) async {
    final backup = stored.backup;
    if (backup == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore this backup?'),
        content: Text(
          'Adds back anything from ${formatTimestamp(backup.createdAt)} that is '
          'missing right now.\n\n'
          'Nothing is removed or renamed, and your audio files are not touched. '
          'Restoring the same backup twice does nothing the second time.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Restore')),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      final summary = await ref.read(folderBackupActionsProvider).restore(stored);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            summary.changedNothing
                ? 'Everything in this backup was already here'
                : 'Restored ${countLabel(summary.foldersCreated, 'folder')} and '
                    '${countLabel(summary.linksAdded, 'entry', plural: 'entries')}',
          ),
        ),
      );
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text("Couldn't restore: $error")));
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this backup file?'),
        content: Text('${stored.fileName} will be removed. Your folders are not affected.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(folderBackupActionsProvider).delete(stored);
  }
}

/// `1 folder` / `3 folders`, for the many counts this screen reports.
String countLabel(int value, String singular, {String? plural}) =>
    '$value ${value == 1 ? singular : plural ?? '${singular}s'}';
