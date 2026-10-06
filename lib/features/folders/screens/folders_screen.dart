import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
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
import '../widgets/playlist_cover.dart';
import 'folder_detail_screen.dart';

class FoldersScreen extends ConsumerWidget {
  const FoldersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final folders = ref.watch(folderListProvider);
    final systemFolders = folders.where((folder) => folder.isSystem).toList();
    final userFolders = folders.where((folder) => !folder.isSystem).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Playlists')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          const _NewAudioTile(),
          const _SectionLabel('Auto collections'),
          const _HistoryTile(view: HistoryView.recentlyPlayed),
          const _HistoryTile(view: HistoryView.mostPlayed),
          for (final folder in systemFolders) _FolderListTile(folder: folder),
          _CreatedHeader(count: userFolders.length),
          if (userFolders.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 32),
              child: EmptyState(
                icon: Icons.queue_music,
                title: 'No playlists yet',
                message: 'Tap + to make one — a playlist groups tracks without moving or copying any files.',
              ),
            )
          else
            for (final folder in userFolders) _PlaylistRow(folder: folder),
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
                PopupMenuItem(value: 'edit', child: Text('Rename')),
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
        color: scheme.surfaceContainerHigh,
      ),
      child: Icon(icon, color: scheme.onSurface, size: 22),
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

/// The heading above the user's own playlists, with the count and a + beside
/// it — the shape the reference screenshot uses, where making a playlist is an
/// action on the list rather than an icon up in the app bar.
class _CreatedHeader extends ConsumerWidget {
  const _CreatedHeader({required this.count});

  final int count;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 8, 4),
      child: Row(
        children: [
          Text(
            'CREATED PLAYLIST',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$count',
            style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline),
          ),
          const Spacer(),
          IconButton(
            tooltip: 'New playlist',
            icon: const Icon(Icons.add),
            onPressed: () async {
              final name = await promptForFolder(context);
              if (name == null) return;
              await ref.read(folderActionsProvider).createFolder(name);
            },
          ),
        ],
      ),
    );
  }
}

/// One playlist: its cover, its name, how many songs are in it.
///
/// A row rather than a grid cell. A grid of two columns gave each playlist a
/// large cover and a cramped name, and these are named things — `david tao`,
/// `粤语` — that you pick by reading, not by recognising a sleeve.
class _PlaylistRow extends ConsumerWidget {
  const _PlaylistRow({required this.folder});

  final FolderModel folder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final contents = ref.watch(folderTracksProvider(folder.id)).value;

    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => FolderDetailScreen(folderId: folder.id)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
        child: Row(
          children: [
            PlaylistCover(folderId: folder.id, size: 60, borderRadius: 8),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    folder.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _subtitle(contents),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: scheme.onSurfaceVariant, size: 20),
              onSelected: (action) => handleFolderAction(context, ref, folder, action),
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'cover', child: Text('Change cover')),
                PopupMenuItem(value: 'edit', child: Text('Rename')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _subtitle(FolderContents? contents) {
    if (contents == null) return '';

    final count = contents.tracks.length;
    final missing = contents.unavailablePaths.length;
    return '$count ${count == 1 ? 'song' : 'songs'}'
        '${missing == 0 ? '' : '  ·  $missing not found'}';
  }
}

/// Shared by the system rows and the playlist rows, so rename, cover and
/// delete behave identically wherever they are reached from.
Future<void> handleFolderAction(
  BuildContext context,
  WidgetRef ref,
  FolderModel folder,
  String action,
) async {
  if (action == 'cover') {
    await _pickCover(context, ref, folder);
    return;
  }

  if (action == 'edit') {
    final name = await promptForFolder(
      context,
      initialName: folder.name,
      title: 'Rename playlist',
    );
    if (name != null) {
      await ref.read(folderActionsProvider).editFolder(folder.id, name);
    }
    return;
  }

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete playlist?'),
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

/// Lets the user pick a playlist cover from the device gallery.
///
/// The picked file is **copied** into the app's own directory rather than
/// referenced where it sits. The picker hands back a path in a cache the system
/// is free to clear, and the original can be deleted from the gallery at any
/// time; either would leave the playlist with a cover that worked until it
/// suddenly did not.
Future<void> _pickCover(BuildContext context, WidgetRef ref, FolderModel folder) async {
  final messenger = ScaffoldMessenger.of(context);
  final actions = ref.read(folderActionsProvider);
  final isDark = Theme.of(context).brightness == Brightness.dark;

  if (folder.coverPath != null) {
    final keep = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Playlist cover'),
        content: const Text('Choose a new picture, or go back to using the artwork of the tracks inside.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Use track artwork'),
          ),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Choose picture')),
        ],
      ),
    );
    if (keep == null) return;
    if (!keep) {
      await actions.setCover(folder.id, null);
      return;
    }
  }

  try {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    // Square, and locked square: a cover is drawn into a square box everywhere
    // it appears, so letting the crop be any other shape only decides which
    // part of it gets cut off later, out of sight.
    final cropped = await ImageCropper().cropImage(
      sourcePath: picked.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 90,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop cover',
          lockAspectRatio: true,
          hideBottomControls: true,
          initAspectRatio: CropAspectRatioPreset.square,
          // The crop screen is a native activity, so it cannot inherit the
          // app's theme — these are the same black-and-white values written
          // out by hand, and they follow the mode the app is in.
          toolbarColor: isDark ? const Color(0xFF121212) : const Color(0xFFFFFFFF),
          toolbarWidgetColor: isDark ? const Color(0xFFFFFFFF) : const Color(0xFF121212),
          // Not a colour any more: the flag says whether the bar sits on a
          // light background, so UCrop can pick icons that show up on it.
          statusBarLight: !isDark,
          backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFF121212),
          activeControlsWidgetColor: isDark ? const Color(0xFFFFFFFF) : const Color(0xFF121212),
          cropFrameColor: const Color(0xFFFFFFFF),
          cropGridColor: const Color(0x55FFFFFF),
          dimmedLayerColor: const Color(0xCC000000),
        ),
      ],
    );
    if (cropped == null) return;

    final directory = Directory(p.join((await getApplicationDocumentsDirectory()).path, 'playlist_covers'));
    if (!await directory.exists()) await directory.create(recursive: true);

    // Named for the playlist and stamped, so replacing a cover never has to
    // overwrite a file that something on screen is still painting.
    final target = p.join(
      directory.path,
      '${folder.id}-${DateTime.now().millisecondsSinceEpoch}${p.extension(cropped.path)}',
    );
    await File(cropped.path).copy(target);

    final previous = folder.coverPath;
    await actions.setCover(folder.id, target);
    if (previous != null) {
      try {
        final old = File(previous);
        if (old.existsSync()) await old.delete();
      } catch (_) {
        // A leftover file is not worth telling anyone about.
      }
    }
  } catch (error) {
    messenger.showSnackBar(SnackBar(content: Text("Couldn't set that picture: $error")));
  }
}
