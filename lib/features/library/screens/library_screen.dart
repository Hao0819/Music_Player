import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/track.dart';
import '../../../widgets/empty_state.dart';
import '../../folders/providers/folder_providers.dart';
import '../../folders/widgets/add_to_folder_sheet.dart';
import '../../player/providers/player_providers.dart';
import '../../search/widgets/filter_panel.dart';
import '../providers/library_providers.dart';
import '../widgets/alphabet_index_bar.dart';
import '../widgets/sort_menu_button.dart';
import '../widgets/track_tile.dart';

/// Fixed row height so the A–Z index can jump straight to an offset without
/// measuring every tile.
const double _trackTileExtent = 72;

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _jumpToLetter(String letter, List<Track> tracks) {
    if (!_scrollController.hasClients) return;

    var index = tracks.indexWhere((track) => track.indexLetter == letter);
    if (index < 0) {
      // Nothing under that letter — fall through to the next section that
      // does exist so the gesture still feels responsive.
      final target = AlphabetIndexBar.letters.indexOf(letter);
      for (var i = target + 1; i < AlphabetIndexBar.letters.length; i++) {
        index = tracks.indexWhere((track) => track.indexLetter == AlphabetIndexBar.letters[i]);
        if (index >= 0) break;
      }
    }
    if (index < 0) return;

    final offset = (index * _trackTileExtent).clamp(0.0, _scrollController.position.maxScrollExtent);
    _scrollController.jumpTo(offset);
  }

  @override
  Widget build(BuildContext context) {
    final tracksAsync = ref.watch(visibleLibraryProvider);
    final selection = ref.watch(librarySelectionProvider);
    final inSelectionMode = selection.isNotEmpty;
    final filter = ref.watch(libraryFilterProvider);
    final query = ref.watch(librarySearchQueryProvider);

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
              actions: [
                IconButton(
                  tooltip: 'Filters',
                  icon: Badge(
                    isLabelVisible: filter.isActive,
                    child: const Icon(Icons.tune),
                  ),
                  onPressed: () => showFilterPanel(context, libraryFilterProvider),
                ),
                const SortMenuButton(),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(60),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: SearchBar(
                    controller: _searchController,
                    hintText: 'Search your library',
                    leading: const Icon(Icons.search),
                    trailing: [
                      if (query.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            ref.read(librarySearchQueryProvider.notifier).clear();
                          },
                        ),
                    ],
                    onChanged: ref.read(librarySearchQueryProvider.notifier).set,
                  ),
                ),
              ),
            ),
      body: tracksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _LibraryError(error: error),
        data: (tracks) => _LibraryList(
          tracks: tracks,
          scrollController: _scrollController,
          onLetterSelected: (letter) => _jumpToLetter(letter, tracks),
          isFiltered: query.isNotEmpty || filter.isActive,
        ),
      ),
    );
  }
}

class _LibraryList extends ConsumerWidget {
  const _LibraryList({
    required this.tracks,
    required this.scrollController,
    required this.onLetterSelected,
    required this.isFiltered,
  });

  final List<Track> tracks;
  final ScrollController scrollController;
  final ValueChanged<String> onLetterSelected;
  final bool isFiltered;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Future<void> refresh() => ref.read(libraryScanProvider.notifier).refresh();

    if (tracks.isEmpty) {
      return RefreshIndicator(
        onRefresh: refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 120),
            EmptyState(
              icon: isFiltered ? Icons.search_off : Icons.library_music_outlined,
              title: isFiltered ? 'No matches' : 'No audio found',
              message: isFiltered
                  ? 'Try a different search, or clear your filters.'
                  : 'Pull down to rescan your device.',
            ),
          ],
        ),
      );
    }

    final selection = ref.watch(librarySelectionProvider);
    final selectionNotifier = ref.read(librarySelectionProvider.notifier);
    final folderActions = ref.read(folderActionsProvider);
    final sortField = ref.watch(librarySortProvider).field;

    // An A–Z index only means anything while the list is in alphabetical
    // order of something.
    final showIndexBar = tracks.length > 20 &&
        (sortField == LibrarySortField.title ||
            sortField == LibrarySortField.artist ||
            sortField == LibrarySortField.album);

    return Column(
      children: [
        _LibraryCountHeader(count: tracks.length, isFiltered: isFiltered),
        Expanded(
          child: RefreshIndicator(
            onRefresh: refresh,
            child: Stack(
              children: [
                ListView.builder(
                  controller: scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemExtent: _trackTileExtent,
                  padding: EdgeInsets.only(right: showIndexBar ? 24 : 0),
                  itemCount: tracks.length,
                  itemBuilder: (context, index) {
                    final track = tracks[index];
                    final isFavorite = ref.watch(isFavoriteProvider(track.path));

                    return TrackTile(
                      track: track,
                      selectionMode: selection.isNotEmpty,
                      selected: selection.contains(track.path),
                      isFavorite: isFavorite,
                      onFavoriteToggle: () => folderActions.toggleFavorite(track.path),
                      onLongPress: () => selectionNotifier.toggle(track.path),
                      // Playing from the library queues the whole visible
                      // list, so next/previous walk what you were looking at.
                      onTap: selection.isNotEmpty
                          ? () => selectionNotifier.toggle(track.path)
                          : () => ref.read(playerControllerProvider).playTracks(tracks, initialIndex: index),
                    );
                  },
                ),
                if (showIndexBar)
                  Positioned(
                    top: 8,
                    bottom: 8,
                    right: 0,
                    child: AlphabetIndexBar(
                      availableLetters: {for (final track in tracks) track.indexLetter},
                      onLetterSelected: onLetterSelected,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _LibraryCountHeader extends StatelessWidget {
  const _LibraryCountHeader({required this.count, required this.isFiltered});

  final int count;
  final bool isFiltered;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          '$count ${count == 1 ? 'song' : 'songs'}${isFiltered ? ' matched' : ''}',
          style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
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
