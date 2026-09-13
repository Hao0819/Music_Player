import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/selection_notifier.dart';
import '../../../core/text_query_notifier.dart';
import '../../../core/utils/fuzzy_match.dart';
import '../../../domain/folder_sort_mode.dart';
import '../../../domain/track.dart';
import '../../../widgets/empty_state.dart';
import '../../library/widgets/track_tile.dart';
import '../../player/providers/player_providers.dart';
import '../../player/widgets/mini_player.dart';
import '../providers/folder_providers.dart';
import '../widgets/folder_name_dialog.dart';

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
                      PopupMenuItem(value: 'rename', child: Text('Rename')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
              ],
            ),
      body: tracksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
        data: (allTracks) {
          if (allTracks.isEmpty) {
            return const EmptyState(
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
          if (canReorder) {
            return _ReorderableTrackList(folderId: folderId, tracks: tracks);
          }

          return ListView.builder(
            itemCount: tracks.length,
            itemBuilder: (context, index) {
              final track = tracks[index];
              return TrackTile(
                key: ValueKey(track.path),
                track: track,
                selectionMode: inSelectionMode,
                selected: selection.contains(track.path),
                onLongPress: () => ref.read(_folderDetailSelectionProvider.notifier).toggle(track.path),
                onTap: inSelectionMode
                    ? () => ref.read(_folderDetailSelectionProvider.notifier).toggle(track.path)
                    : () => ref.read(playerControllerProvider).playTracks(tracks, initialIndex: index),
              );
            },
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

    if (action == 'rename') {
      final name = await promptForFolderName(context, initialValue: folder.name, title: 'Rename folder');
      if (name != null && name.trim().isNotEmpty) {
        await ref.read(folderActionsProvider).renameFolder(folderId, name);
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
      await ref.read(folderActionsProvider).deleteFolder(folderId);
      if (context.mounted) Navigator.pop(context);
    }
  }
}

class _ReorderableTrackList extends ConsumerStatefulWidget {
  const _ReorderableTrackList({required this.folderId, required this.tracks});

  final String folderId;
  final List<Track> tracks;

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
