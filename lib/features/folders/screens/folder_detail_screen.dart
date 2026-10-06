import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/selection_notifier.dart';
import '../../../data/hive/models/folder_model.dart';
import '../../../core/text_query_notifier.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/duration_format.dart';
import '../../../core/utils/fuzzy_match.dart';
import '../../../domain/folder_sort_mode.dart';
import '../../../domain/track.dart';
import '../../../widgets/empty_state.dart';
import '../../library/widgets/track_tile.dart';
import '../../player/providers/player_providers.dart';
import '../../player/widgets/mini_player.dart';
import '../providers/folder_providers.dart';
import '../widgets/folder_name_dialog.dart';
import 'folders_screen.dart';
import '../widgets/playlist_cover.dart';

final _folderDetailSelectionProvider = NotifierProvider<SelectionNotifier, Set<String>>(SelectionNotifier.new);

/// Search scoped to the folder currently open — the "search within this
/// folder" half of the spec's two search scopes.
final _folderSearchProvider = NotifierProvider<TextQueryNotifier, String>(TextQueryNotifier.new);

class FolderDetailScreen extends ConsumerStatefulWidget {
  const FolderDetailScreen({super.key, required this.folderId});

  final String folderId;

  @override
  ConsumerState<FolderDetailScreen> createState() => _FolderDetailScreenState();
}

class _FolderDetailScreenState extends ConsumerState<FolderDetailScreen> {
  final _searchController = TextEditingController();

  String get folderId => widget.folderId;

  @override
  void initState() {
    super.initState();
    // These providers are shared across folder screens, so clear whatever the
    // previously opened folder left behind.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(_folderSearchProvider.notifier).clear();
      ref.read(_folderDetailSelectionProvider.notifier).clear();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final folder = ref.watch(folderByIdProvider(folderId));
    if (folder == null) {
      return const Scaffold(body: Center(child: Text('Folder not found')));
    }

    final tracksAsync = ref.watch(folderTracksProvider(folderId));
    final selection = ref.watch(_folderDetailSelectionProvider);
    final inSelectionMode = selection.isNotEmpty;
    final searchQuery = ref.watch(_folderSearchProvider);
    final isSearching = searchQuery.trim().isNotEmpty;
    final sortMode = FolderSortMode.values.firstWhere(
      (mode) => mode.name == folder.sortMode,
      orElse: () => FolderSortMode.manual,
    );

    return Scaffold(
      // Pushed over the tab shell, so it needs its own copy of the playback
      // bar — otherwise playing from a folder hides the controls entirely.
      bottomNavigationBar: const MiniPlayer(isBottomMost: true),
      appBar: inSelectionMode
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => ref.read(_folderDetailSelectionProvider.notifier).clear(),
              ),
              title: Text('${selection.length} selected'),
              actions: [
                IconButton(
                  tooltip: 'Remove from folder',
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: () async {
                    final actions = ref.read(folderActionsProvider);
                    for (final path in selection) {
                      await actions.removeTrack(folderId, path);
                    }
                    ref.read(_folderDetailSelectionProvider.notifier).clear();
                  },
                ),
              ],
            )
          : AppBar(
              title: Text(folder.name),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(64),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: SearchBar(
                    controller: _searchController,
                    hintText: 'Search in this folder',
                    leading: const Icon(Icons.search),
                    trailing: [
                      if (isSearching)
                        IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            ref.read(_folderSearchProvider.notifier).clear();
                          },
                        ),
                    ],
                    onChanged: ref.read(_folderSearchProvider.notifier).set,
                  ),
                ),
              ),
              actions: [
                PopupMenuButton<FolderSortMode>(
                  tooltip: 'Sort',
                  icon: const Icon(Icons.sort),
                  initialValue: sortMode,
                  onSelected: (mode) => ref.read(folderActionsProvider).setSortMode(folderId, mode),
                  itemBuilder: (context) => [
                    for (final mode in FolderSortMode.values)
                      CheckedPopupMenuItem(value: mode, checked: mode == sortMode, child: Text(_sortLabel(mode))),
                  ],
                ),
                if (!folder.isSystem)
                  PopupMenuButton<String>(
                    onSelected: (action) => _handleMenuAction(context, action),
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'cover', child: Text('Change cover')),
                      PopupMenuItem(value: 'edit', child: Text('Rename')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
              ],
            ),
      body: tracksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
        data: (contents) {
          final allTracks = contents.tracks;
          if (allTracks.isEmpty) {
            // A folder nobody filled and a folder whose files have all gone
            // missing need different words — the second is not something the
            // user did, and telling them apart is the whole point of
            // tracking unmatched links.
            return contents.hasUnavailable
                ? _UnavailableState(count: contents.unavailablePaths.length)
                : const EmptyState(
                    icon: Icons.music_off_outlined,
                    title: 'No tracks in this folder yet',
                    message: 'Add tracks from your Library using multi-select.',
                  );
          }

          final tracks = isSearching
              ? allTracks
                  .where((track) => fuzzyMatches(searchQuery, [track.title, track.artist, track.album]))
                  .toList()
              : allTracks;

          if (tracks.isEmpty) {
            return const EmptyState(
              icon: Icons.search_off,
              title: 'No matches in this folder',
              message: 'Try a different search term.',
            );
          }

          // Dragging is only meaningful when the full list is shown in its
          // stored custom order — not while filtered by search or selecting.
          final canReorder = sortMode == FolderSortMode.manual && !inSelectionMode && !isSearching;
          final currentPath = ref.watch(currentMediaItemProvider).value?.id;

          return Column(
            children: [
              if (!inSelectionMode) _FolderPlayHeader(tracks: tracks, folder: folder),
              if (contents.hasUnavailable) _UnavailableBanner(count: contents.unavailablePaths.length),
              Expanded(
                child: canReorder
                    ? _ReorderableTrackList(folderId: folderId, tracks: tracks, currentPath: currentPath)
                    : ListView.builder(
                        itemCount: tracks.length,
                        itemBuilder: (context, index) {
                          final track = tracks[index];
                          return TrackTile(
                            key: ValueKey(track.path),
                            track: track,
                            selectionMode: inSelectionMode,
                            selected: selection.contains(track.path),
                            isCurrent: track.path == currentPath,
                            onLongPress: () =>
                                ref.read(_folderDetailSelectionProvider.notifier).toggle(track.path),
                            onTap: inSelectionMode
                                ? () => ref.read(_folderDetailSelectionProvider.notifier).toggle(track.path)
                                : () => ref
                                    .read(playerControllerProvider)
                                    .playTracks(tracks, initialIndex: index),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _sortLabel(FolderSortMode mode) => switch (mode) {
        FolderSortMode.manual => 'Custom order',
        FolderSortMode.title => 'Title',
        FolderSortMode.artist => 'Artist',
        FolderSortMode.album => 'Album',
        FolderSortMode.addedToFolder => 'Date added',
        FolderSortMode.duration => 'Duration',
      };

  Future<void> _handleMenuAction(BuildContext context, String action) async {
    final folder = ref.read(folderByIdProvider(folderId));
    if (folder == null) return;

    if (action == 'cover') {
      await handleFolderAction(context, ref, folder, 'cover');
      return;
    }

    if (action == 'edit') {
      final name = await promptForFolder(
        context,
        initialName: folder.name,
        title: 'Rename playlist',
      );
      if (name != null) {
        await ref.read(folderActionsProvider).editFolder(folderId, name);
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
      await ref.read(folderActionsProvider).deleteFolder(folderId);
      if (context.mounted) Navigator.pop(context);
    }
  }
}

/// Shown when every track in a folder is a link the scan could not match.
///
/// The folder is not empty — it has entries pointing at files that are not
/// turning up — so the message points at the two things that actually cause
/// it rather than inviting the user to add tracks.
class _UnavailableState extends StatelessWidget {
  const _UnavailableState({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.help_outline,
      title: '$count track${count == 1 ? '' : 's'} in this folder '
          "can't be found",
      message: 'The files may have been moved, renamed or deleted, or the '
          'storage they are on is not available. Nothing has been removed '
          'from the folder — if the files come back, so do these.',
    );
  }
}

/// The same fact, as a strip above a folder that is only partly resolvable.
class _UnavailableBanner extends StatelessWidget {
  const _UnavailableBanner({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      ),
      child: Row(
        children: [
          Icon(Icons.help_outline, size: 18, color: scheme.onSecondaryContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$count more track${count == 1 ? '' : 's'} '
              "in this folder can't be found right now",
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSecondaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}

/// Gives a folder an identity at the top of the screen — cover tile, name,
/// how much music is in it — plus Play / Shuffle, so listening to one doesn't
/// require first hunting for a track to tap.
class _FolderPlayHeader extends ConsumerWidget {
  const _FolderPlayHeader({required this.tracks, required this.folder});

  final List<Track> tracks;
  final FolderModel folder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final controller = ref.read(playerControllerProvider);
    final total = tracks.fold(Duration.zero, (sum, track) => sum + track.duration);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // The folder's first cover, not a coloured folder glyph. A
              // folder is identified by what is in it, and one real sleeve
              // says that faster than a tinted icon ever did.
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.28),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: PlaylistCover(
                  folderId: folder.id,
                  size: 104,
                  borderRadius: AppTheme.radiusMedium,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Kind and size first, in small grey type, then the name
                    // large — the order the reference uses, and the one that
                    // lets a long folder name have the whole line to itself.
                    Text(
                      'Playlist  ·  ${tracks.length} ${tracks.length == 1 ? 'song' : 'songs'}'
                      '  ·  ${formatDuration(total)}',
                      style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      folder.name,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.1,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  icon: const Icon(Icons.play_arrow, size: 20),
                  label: const Text('Play'),
                  onPressed: () => controller.playTracks(tracks),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.shuffle, size: 18),
                  label: const Text('Shuffle'),
                  onPressed: () => controller.shufflePlay(tracks),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReorderableTrackList extends ConsumerStatefulWidget {
  const _ReorderableTrackList({required this.folderId, required this.tracks, this.currentPath});

  final String folderId;
  final List<Track> tracks;
  final String? currentPath;

  @override
  ConsumerState<_ReorderableTrackList> createState() => _ReorderableTrackListState();
}

class _ReorderableTrackListState extends ConsumerState<_ReorderableTrackList> {
  /// Local copy so a drop lands instantly. Saving the new order is async, and
  /// rendering straight from the provider made the row snap back for a
  /// moment before jumping to where it was dropped.
  late List<Track> _tracks = [...widget.tracks];

  @override
  void didUpdateWidget(_ReorderableTrackList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.tracks, widget.tracks)) {
      _tracks = [...widget.tracks];
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ReorderableListView.builder(
      // The default drag gesture on mobile is long-press on the whole row,
      // but long-press here already means "select". Leaving the default on
      // meant selection always won and dragging never happened. Instead the
      // handle drags immediately and long-press stays free for selecting.
      buildDefaultDragHandles: false,
      itemCount: _tracks.length,
      onReorderItem: (oldIndex, newIndex) {
        setState(() => _tracks.insert(newIndex, _tracks.removeAt(oldIndex)));
        ref.read(folderActionsProvider).reorder(
              widget.folderId,
              [for (final track in _tracks) track.path],
            );
      },
      itemBuilder: (context, index) {
        final track = _tracks[index];
        return TrackTile(
          key: ValueKey(track.path),
          track: track,
          isCurrent: track.path == widget.currentPath,
          onLongPress: () => ref.read(_folderDetailSelectionProvider.notifier).toggle(track.path),
          onTap: () => ref.read(playerControllerProvider).playTracks(_tracks, initialIndex: index),
          trailing: ReorderableDragStartListener(
            index: index,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Icon(Icons.drag_handle, color: scheme.onSurfaceVariant),
            ),
          ),
        );
      },
    );
  }
}
