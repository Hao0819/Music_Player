import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../domain/library_filter_state.dart';
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

/// Heights of the chrome above the list.
///
/// The A–Z index converts a track index straight into a scroll offset, which
/// only works if everything above the list has a height known in advance — so
/// each of these blocks is pinned to its constant with a [SizedBox] rather
/// than being sized by its content. Change one of these and the jump lands in
/// the wrong place, silently.
/// Tall enough to hold the search field with breathing room; it lives in the
/// toolbar rather than in the app bar's `bottom`, because a `bottom` survives
/// the toolbar scrolling away and ends up drawn over the status bar.
const double _toolbarExtent = 64;
const double _chipsExtent = 48;
const double _statsExtent = 48;

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

  /// Everything the list scrolls out from under before the first row.
  ///
  /// The app bar is excluded even though it is above the list: pinned, it
  /// keeps painting over the top of the viewport, so the distance the content
  /// scrolls past it is exactly the height it then covers. Only the chips and
  /// the count row actually scroll away.
  double get _headerExtent => _chipsExtent + _statsExtent;

  void _jumpToLetter(String letter, List<Track> tracks, LibrarySortField field) {
    if (!_scrollController.hasClients) return;

    var index = tracks.indexWhere((track) => _letterOf(track, field) == letter);
    if (index < 0) {
      // Nothing under that letter — fall through to the next section that
      // does exist so the gesture still feels responsive.
      final target = AlphabetIndexBar.letters.indexOf(letter);
      for (var i = target + 1; i < AlphabetIndexBar.letters.length; i++) {
        final next = AlphabetIndexBar.letters[i];
        index = tracks.indexWhere((track) => _letterOf(track, field) == next);
        if (index >= 0) break;
      }
    }
    if (index < 0) return;

    final offset = (_headerExtent + index * _trackTileExtent)
        .clamp(0.0, _scrollController.position.maxScrollExtent);
    _scrollController.jumpTo(offset);
  }

  /// The index letter for whichever column the list is sorted on, so the
  /// strip and the list agree.
  static String _letterOf(Track track, LibrarySortField field) => switch (field) {
        LibrarySortField.artist => track.artistIndexLetter,
        LibrarySortField.album => track.albumIndexLetter,
        _ => track.indexLetter,
      };

  @override
  Widget build(BuildContext context) {
    final tracksAsync = ref.watch(visibleLibraryProvider);
    final selection = ref.watch(librarySelectionProvider);
    final inSelectionMode = selection.isNotEmpty;
    final filter = ref.watch(libraryFilterProvider);
    final query = ref.watch(librarySearchQueryProvider);
    final isFiltered = query.isNotEmpty || filter.isActive;
    final sortField = ref.watch(librarySortProvider).field;

    final tracks = tracksAsync.value ?? const <Track>[];

    // An A–Z index only means anything while the list is in alphabetical
    // order of something. It is also hidden while selecting, where the app bar
    // is pinned and so the offsets above would be off by its height.
    final showIndexBar = !inSelectionMode &&
        tracks.length > 20 &&
        (sortField == LibrarySortField.title ||
            sortField == LibrarySortField.artist ||
            sortField == LibrarySortField.album);

    final indexBarInset = showIndexBar ? AlphabetIndexBar.hitWidth : 0.0;

    return Scaffold(
      body: Stack(
        children: [
          RefreshIndicator(
            // The viewport starts at the top of the screen — the app bar is a
            // sliver and draws its own status bar inset — so the default
            // displacement puts the spinner on top of the search field.
            displacement: MediaQuery.paddingOf(context).top + _toolbarExtent,
            onRefresh: () => ref.read(libraryScanProvider.notifier).refresh(),
            child: CustomScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                _appBar(inSelectionMode, selection, filter, query),
                // The rows above the list have to clear the index strip too —
                // only the list itself was inset before, so the Shuffle pill
                // ran underneath the letters.
                if (!inSelectionMode)
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: _chipsExtent,
                      child: Padding(
                        padding: EdgeInsets.only(right: indexBarInset),
                        child: const _FolderStatusChips(),
                      ),
                    ),
                  ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: _statsExtent,
                    child: Padding(
                      padding: EdgeInsets.only(right: indexBarInset),
                      child: _LibraryStats(shown: tracks.length, isFiltered: isFiltered),
                    ),
                  ),
                ),
                ...tracksAsync.when(
                  loading: () => const [
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ],
                  error: (error, _) => [
                    SliverFillRemaining(hasScrollBody: false, child: _LibraryError(error: error)),
                  ],
                  data: (tracks) => tracks.isEmpty
                      ? [
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: EmptyState(
                              icon: isFiltered ? Icons.search_off : Icons.library_music_outlined,
                              title: isFiltered ? 'No matches' : 'No audio found',
                              message: isFiltered
                                  ? 'Try a different search, or clear your filters.'
                                  : 'Pull down to rescan your device.',
                            ),
                          ),
                        ]
                      : [_trackSliver(tracks, indexBarInset)],
                ),
              ],
            ),
          ),
          if (showIndexBar)
            Positioned(
              // Starts below the toolbar so it never sits on the title row.
              // Once the bar has scrolled away this leaves a little dead space
              // above the letters, which costs nothing.
              top: MediaQuery.paddingOf(context).top + _toolbarExtent + 8,
              bottom: 8,
              right: 0,
              child: AlphabetIndexBar(
                availableLetters: {for (final track in tracks) _letterOf(track, sortField)},
                onLetterSelected: (letter) => _jumpToLetter(letter, tracks, sortField),
              ),
            ),
        ],
      ),
    );
  }

  Widget _appBar(
    bool inSelectionMode,
    Set<String> selection,
    LibraryFilterState filter,
    String query,
  ) {
    if (inSelectionMode) {
      return SliverAppBar(
        // Stays put: it is a mode, and losing the way out of it while
        // scrolling through a long list would be the wrong kind of surprise.
        pinned: true,
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
      );
    }

    return SliverAppBar(
      // Pinned, not floating+snap. Snapping decides on finger-lift whether to
      // finish opening or spring shut, so lifting off to tap the field you
      // just revealed could take it away again — reaching for search is worth
      // more than the 64dp. The chips and count row still scroll away.
      pinned: true,
      toolbarHeight: _toolbarExtent,
      titleSpacing: 16,
      // No "Library" heading: the navigation bar already says which tab this
      // is, and the row is worth more as the search field.
      title: SizedBox(
        height: 48,
        child: SearchBar(
          controller: _searchController,
          hintText: 'Search your library',
          padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 12)),
          leading: const Icon(Icons.search, size: 20),
          trailing: [
            if (query.isNotEmpty)
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.clear, size: 20),
                onPressed: () {
                  _searchController.clear();
                  ref.read(librarySearchQueryProvider.notifier).clear();
                },
              ),
          ],
          onChanged: ref.read(librarySearchQueryProvider.notifier).set,
        ),
      ),
      actions: [
        IconButton(
          tooltip: 'Filters',
          icon: Badge(isLabelVisible: filter.isActive, child: const Icon(Icons.tune)),
          onPressed: () => showFilterPanel(context, libraryFilterProvider),
        ),
        const SortMenuButton(),
      ],
    );
  }

  Widget _trackSliver(List<Track> tracks, double inset) {
    final selection = ref.watch(librarySelectionProvider);
    final selectionNotifier = ref.read(librarySelectionProvider.notifier);
    final folderActions = ref.read(folderActionsProvider);
    final folderNamesByPath = ref.watch(folderNamesByPathProvider);
    final currentPath = ref.watch(currentMediaItemProvider).value?.id;

    return SliverPadding(
      padding: EdgeInsets.only(right: inset),
      sliver: SliverFixedExtentList(
        itemExtent: _trackTileExtent,
        delegate: SliverChildBuilderDelegate(
          childCount: tracks.length,
          (context, index) {
            final track = tracks[index];
            final isFavorite = ref.watch(isFavoriteProvider(track.path));

            return TrackTile(
              track: track,
              selectionMode: selection.isNotEmpty,
              selected: selection.contains(track.path),
              isFavorite: isFavorite,
              folderNames: folderNamesByPath[track.path] ?? const [],
              isCurrent: track.path == currentPath,
              onFavoriteToggle: () => folderActions.toggleFavorite(track.path),
              onLongPress: () => selectionNotifier.toggle(track.path),
              // Playing from the library queues the whole visible list, so
              // next/previous walk what you were looking at.
              onTap: selection.isNotEmpty
                  ? () => selectionNotifier.toggle(track.path)
                  : () => ref.read(playerControllerProvider).playTracks(tracks, initialIndex: index),
            );
          },
        ),
      ),
    );
  }
}

/// One-tap version of the filter panel's "Organization" setting — the same
/// state, so the two always agree.
class _FolderStatusChips extends ConsumerWidget {
  const _FolderStatusChips();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(libraryFilterProvider).categorized;
    final notifier = ref.read(libraryFilterProvider.notifier);

    Widget chip(CategorizedFilter value, String label, IconData icon) {
      return ChoiceChip(
        avatar: Icon(icon, size: 18),
        label: Text(label),
        selected: current == value,
        showCheckmark: false,
        visualDensity: VisualDensity.compact,
        onSelected: (_) => notifier.setCategorized(value),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Row(
        children: [
          chip(CategorizedFilter.any, 'All', Icons.library_music_outlined),
          const SizedBox(width: 8),
          chip(CategorizedFilter.categorized, 'In a folder', Icons.folder_outlined),
          const SizedBox(width: 8),
          chip(CategorizedFilter.uncategorized, 'Not in a folder', Icons.folder_off_outlined),
        ],
      ),
    );
  }
}

/// How many tracks are in view, and the fastest way into playing them.
///
/// The old version of this was a tinted card with an "All songs" heading above
/// the count. The heading said nothing the chips above it did not already say,
/// and the card put a second block of colour directly behind the Shuffle pill.
class _LibraryStats extends ConsumerWidget {
  const _LibraryStats({required this.shown, required this.isFiltered});

  final int shown;
  final bool isFiltered;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final total = ref.watch(libraryScanProvider).value?.length ?? shown;

    final label = isFiltered && total != shown
        ? '$shown of $total tracks'
        : '$shown ${shown == 1 ? 'track' : 'tracks'}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // The one bright element on this screen, and the fastest way into
          // playback from a long list. Deliberately the app's own accent
          // rather than the playing track's — the library is not re-themed
          // per track, or a long list would change colour under you.
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
              gradient: AppTheme.accentGradient(AppTheme.signal),
            ),
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                onTap: () => ref.read(playerControllerProvider).shufflePlay(
                      ref.read(visibleLibraryProvider).value ?? const [],
                    ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.shuffle, size: 17, color: AppTheme.onAccent(AppTheme.signal)),
                      const SizedBox(width: 7),
                      Text(
                        'Shuffle',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: AppTheme.onAccent(AppTheme.signal),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LibraryError extends ConsumerWidget {
  const _LibraryError({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return EmptyState(
      icon: Icons.error_outline,
      title: 'Could not load your library',
      message: '$error',
    );
  }
}
