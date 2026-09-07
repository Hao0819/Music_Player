import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/track.dart';
import '../../../widgets/empty_state.dart';
import '../../folders/providers/folder_providers.dart';
import '../../folders/widgets/add_to_folder_sheet.dart';
import '../../player/providers/player_providers.dart';
import '../providers/library_providers.dart';
import '../widgets/sort_menu_button.dart';
import '../widgets/track_tile.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracksAsync = ref.watch(sortedLibraryProvider);
    final selection = ref.watch(librarySelectionProvider);
    final inSelectionMode = selection.isNotEmpty;

    return Scaffold(
      appBar: inSelectionMode
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => ref.read(librarySelectionProvider.notifier).clear(),
              ),
              title: Text('${selection.length} selected'),
              actions: [
                IconButton(
                  tooltip: 'Add to folder',
                  icon: const Icon(Icons.create_new_folder_outlined),
                  onPressed: () async {
                    final paths = selection.toList();
                    await showAddToFolderSheet(context, ref, paths);
                    ref.read(librarySelectionProvider.notifier).clear();
                  },
                ),
              ],
            )
          : AppBar(
              title: const Text('Library'),
              actions: const [SortMenuButton()],
            ),
      body: tracksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _LibraryError(error: error),
        data: (tracks) => _LibraryList(tracks: tracks),
      ),
    );
  }
}

class _LibraryList extends ConsumerWidget {
  const _LibraryList({required this.tracks});

  final List<Track> tracks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Future<void> refresh() => ref.read(libraryScanProvider.notifier).refresh();

    if (tracks.isEmpty) {
      return RefreshIndicator(
        onRefresh: refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 120),
            EmptyState(
              icon: Icons.library_music_outlined,
              title: 'No audio found',
              message: 'Pull down to rescan your device.',
            ),
          ],
        ),
      );
    }

    final selection = ref.watch(librarySelectionProvider);
    final selectionNotifier = ref.read(librarySelectionProvider.notifier);
    final folderActions = ref.read(folderActionsProvider);

    return RefreshIndicator(
      onRefresh: refresh,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: tracks.length,
        itemBuilder: (context, index) {
          final track = tracks[index];
          final isFavorite = ref.watch(isFavoriteProvider(track.path));
          final selected = selection.contains(track.path);

          return TrackTile(
            track: track,
            selectionMode: selection.isNotEmpty,
            selected: selected,
            isFavorite: isFavorite,
            onFavoriteToggle: () => folderActions.toggleFavorite(track.path),
            onLongPress: () => selectionNotifier.toggle(track.path),
            // Playing from the library queues the whole visible list, so
            // next/previous walk the list you were looking at.
            onTap: selection.isNotEmpty
                ? () => selectionNotifier.toggle(track.path)
                : () => ref.read(playerControllerProvider).playTracks(tracks, initialIndex: index),
          );
        },
      ),
    );
  }
}

class _LibraryError extends ConsumerWidget {
  const _LibraryError({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () => ref.read(libraryScanProvider.notifier).refresh(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 120),
          EmptyState(
            icon: Icons.error_outline,
            title: 'Could not load your library',
            message: '$error',
          ),
        ],
      ),
    );
  }
}
