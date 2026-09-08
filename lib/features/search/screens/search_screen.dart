import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../widgets/empty_state.dart';
import '../../folders/providers/folder_providers.dart';
import '../../library/widgets/track_tile.dart';
import '../../player/providers/player_providers.dart';
import '../providers/search_providers.dart';
import '../widgets/filter_panel.dart';

class SearchScreen extends ConsumerWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(searchQueryProvider);
    final filter = ref.watch(searchFilterProvider);
    final resultsAsync = ref.watch(searchResultsProvider);
    final folderActions = ref.read(folderActionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          autofocus: false,
          decoration: const InputDecoration(
            hintText: 'Search title, artist, album',
            border: InputBorder.none,
          ),
          onChanged: ref.read(searchQueryProvider.notifier).set,
        ),
        actions: [
          if (query.isNotEmpty)
            IconButton(
              tooltip: 'Clear',
              icon: const Icon(Icons.clear),
              onPressed: ref.read(searchQueryProvider.notifier).clear,
            ),
          IconButton(
            tooltip: 'Filters',
            icon: Badge(
              isLabelVisible: filter.isActive,
              child: const Icon(Icons.tune),
            ),
            onPressed: () => showFilterPanel(context, searchFilterProvider),
          ),
        ],
      ),
      body: query.isEmpty && !filter.isActive
          ? const EmptyState(
              icon: Icons.search,
              title: 'Search your library',
              message: 'Type to search by title, artist or album — or use filters to narrow things down.',
            )
          : resultsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => EmptyState(
                icon: Icons.error_outline,
                title: 'Search failed',
                message: '$error',
              ),
              data: (tracks) {
                if (tracks.isEmpty) {
                  return const EmptyState(
                    icon: Icons.search_off,
                    title: 'No matches',
                    message: 'Try a different search, or adjust your filters.',
                  );
                }
                return ListView.builder(
                  itemCount: tracks.length,
                  itemBuilder: (context, index) {
                    final track = tracks[index];
                    return TrackTile(
                      track: track,
                      isFavorite: ref.watch(isFavoriteProvider(track.path)),
                      onFavoriteToggle: () => folderActions.toggleFavorite(track.path),
                      onTap: () => ref
                          .read(playerControllerProvider)
                          .playTracks(tracks, initialIndex: index),
                    );
                  },
                );
              },
            ),
    );
  }
}
