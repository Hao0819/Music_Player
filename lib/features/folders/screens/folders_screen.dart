import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/hive/models/folder_model.dart';
import '../../../widgets/empty_state.dart';
import '../../favorites_history/providers/history_providers.dart';
import '../../favorites_history/screens/history_screen.dart';
import '../../settings/providers/maintenance_providers.dart';
import '../../settings/screens/new_audio_screen.dart';
import '../providers/folder_providers.dart';
import '../widgets/folder_name_dialog.dart';
import 'folder_detail_screen.dart';

class FoldersScreen extends ConsumerWidget {
  const FoldersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final folders = ref.watch(folderListProvider);
    final systemFolders = folders.where((folder) => folder.isSystem).toList();
    final userFolders = folders.where((folder) => !folder.isSystem).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Folders'),
        actions: [
          IconButton(
            tooltip: 'New folder',
            icon: const Icon(Icons.create_new_folder_outlined),
            onPressed: () async {
              final result = await promptForFolder(context);
              if (result == null) return;
              await ref
                  .read(folderActionsProvider)
                  .createFolder(result.name, colorValue: result.colorValue);
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          const _NewAudioTile(),
          const _SectionLabel('Auto collections'),
          const _HistoryTile(view: HistoryView.recentlyPlayed),
          const _HistoryTile(view: HistoryView.mostPlayed),
          for (final folder in systemFolders) _FolderListTile(folder: folder),
          const _SectionLabel('Your folders'),
          if (userFolders.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 40),
              child: EmptyState(
                icon: Icons.folder_outlined,
                title: 'No folders yet',
                message: 'Tap the folder+ icon to create one — folders organize tracks without touching the files.',
              ),
            )
          else
            // A grid of coloured cards rather than another run of identical
            // rows, so your own folders are the part that stands out.
            GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.35,
              ),
              itemCount: userFolders.length,
              itemBuilder: (context, index) => _FolderCard(folder: userFolders[index]),
            ),
        ],
      ),
    );
  }
}

/// Only appears when a scan actually turned up something new — deliberately
/// a quiet row rather than a dialog interrupting the user.
class _NewAudioTile extends ConsumerWidget {
  const _NewAudioTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(newTracksProvider).length;
    if (count == 0) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;

    return ListTile(
      leading: Icon(Icons.new_releases_outlined, color: scheme.primary),
      title: const Text('New audio'),
      subtitle: Text('$count track${count == 1 ? '' : 's'} not filed yet'),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: scheme.primary,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '$count',
          style: TextStyle(color: scheme.onPrimary, fontWeight: FontWeight.w600, fontSize: 12),
        ),
      ),
      tileColor: scheme.secondaryContainer.withValues(alpha: 0.4),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => const NewAudioScreen()),
      ),
    );
  }
}

/// Auto-collections built from the play log, pinned above the folders the
/// user actually created.
class _HistoryTile extends ConsumerWidget {
  const _HistoryTile({required this.view});

  final HistoryView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(historyTracksProvider(view)).length;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      leading: _RoundIcon(switch (view) {
        HistoryView.recentlyPlayed => Icons.history_rounded,
        HistoryView.mostPlayed => Icons.trending_up_rounded,
      }),
      title: Text(switch (view) {
        HistoryView.recentlyPlayed => 'Recently played',
        HistoryView.mostPlayed => 'Most played',
      }),
      subtitle: Text(count == 0 ? 'Nothing played yet' : '$count track${count == 1 ? '' : 's'}'),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => HistoryScreen(view: view)),
      ),
    );
  }
}

class _FolderListTile extends ConsumerWidget {
  const _FolderListTile({required this.folder});

  final FolderModel folder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contents = ref.watch(folderTracksProvider(folder.id)).value;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      leading: _RoundIcon(folder.isSystem ? Icons.favorite_rounded : Icons.folder_rounded),
      title: Text(folder.name),
      subtitle: contents == null ? null : Text(_countLabel(contents)),
      trailing: folder.isSystem
          ? null
          : PopupMenuButton<String>(
              onSelected: (action) => handleFolderAction(context, ref, folder, action),
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'edit', child: Text('Rename or recolour')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => FolderDetailScreen(folderId: folder.id)),
      ),
    );
  }
}

/// `12 tracks`, with any links the scan could not match called out — a count
/// that silently excluded them is what made missing links look like an empty
/// folder.
String _countLabel(FolderContents contents) {
  final count = contents.tracks.length;
  final label = '$count track${count == 1 ? '' : 's'}';
  if (!contents.hasUnavailable) return label;
  return '$label · ${contents.unavailablePaths.length} not found';
}

/// Square tinted container behind a leading icon — the same shape as the
/// folder cards below, so the two halves of the screen match.
class _RoundIcon extends StatelessWidget {
  const _RoundIcon(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        color: scheme.primaryContainer.withValues(alpha: 0.7),
      ),
      child: Icon(icon, color: scheme.onPrimaryContainer, size: 22),
    );
  }
}

/// A section heading between the pinned auto-collections and the user's own
/// folders, so the two groups don't read as one long undifferentiated list.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
      child: Text(
        text,
        style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
    );
  }
}

/// A gradient card for a user folder. Each folder keeps its own colour from
/// [AppTheme.gradientFor], which is what makes the grid readable at a glance.
class _FolderCard extends ConsumerWidget {
  const _FolderCard({required this.folder});

  final FolderModel folder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final count = ref.watch(folderTracksProvider(folder.id)).value?.tracks.length;
    final base = AppTheme.folderColor(folder.name, folder.colorValue);
    final onBase = AppTheme.onAccent(base);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        gradient: AppTheme.accentGradient(base),
        boxShadow: [
          BoxShadow(
            color: base.withValues(alpha: 0.32),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => FolderDetailScreen(folderId: folder.id)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 4, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.folder_rounded, color: onBase, size: 26),
                    const Spacer(),
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert, color: onBase.withValues(alpha: 0.75), size: 20),
                      onSelected: (action) => handleFolderAction(context, ref, folder, action),
                      itemBuilder: (context) => const [
                        PopupMenuItem(value: 'edit', child: Text('Rename or recolour')),
                        PopupMenuItem(value: 'delete', child: Text('Delete')),
                      ],
                    ),
                  ],
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Text(
                    folder.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: onBase,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  count == null ? '—' : '$count track${count == 1 ? '' : 's'}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: onBase.withValues(alpha: 0.75),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shared by the system-folder rows and the folder cards, so rename/delete
/// behave identically in both places.
Future<void> handleFolderAction(
  BuildContext context,
  WidgetRef ref,
  FolderModel folder,
  String action,
) async {
  if (action == 'edit') {
    final result = await promptForFolder(
      context,
      initialName: folder.name,
      initialColor: folder.colorValue,
      title: 'Edit folder',
    );
    if (result != null) {
      await ref.read(folderActionsProvider).editFolder(
            folder.id,
            result.name,
            colorValue: result.colorValue,
            setColor: true,
          );
    }
    return;
  }

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete folder?'),
      content: Text('This only removes "${folder.name}" — your audio files are not affected.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
      ],
    ),
  );
  if (confirmed == true) {
    await ref.read(folderActionsProvider).deleteFolder(folder.id);
  }
}
