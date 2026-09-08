import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:on_audio_query/on_audio_query.dart';

import '../../../core/library_filter_notifier.dart';
import '../../../core/selection_notifier.dart';
import '../../../core/text_query_notifier.dart';
import '../../../data/repositories/audio_library_repository.dart';
import '../../../data/repositories/history_repository.dart';
import '../../../data/repositories/known_tracks_repository.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../domain/library_filter_state.dart';
import '../../../domain/track.dart';
import '../../../domain/track_filtering.dart';
import '../../../services/scanning/media_store_scanner.dart';
import '../../folders/providers/folder_providers.dart';

final librarySelectionProvider = NotifierProvider<SelectionNotifier, Set<String>>(SelectionNotifier.new);

final historyRepositoryProvider = Provider<HistoryRepository>((ref) => HistoryRepository());

/// Bumped whenever a play is logged or the log is cleared, so the history
/// views recompute. Same lightweight approach as the folder-link tick.
class HistoryTickNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final historyTickProvider = NotifierProvider<HistoryTickNotifier, int>(HistoryTickNotifier.new);

final onAudioQueryProvider = Provider<OnAudioQuery>((ref) => OnAudioQuery());

final mediaStoreScannerProvider = Provider<MediaStoreScanner>((ref) => MediaStoreScanner());

final audioLibraryRepositoryProvider = Provider<AudioLibraryRepository>((ref) {
  return AudioLibraryRepository(
    ref.watch(onAudioQueryProvider),
    ref.watch(mediaStoreScannerProvider),
  );
});

final knownTracksRepositoryProvider =
    Provider<KnownTracksRepository>((ref) => KnownTracksRepository());

/// Bumped after each scan reconciles against the known-files record, so the
/// "new audio" and cleanup views refresh.
class KnownTracksTickNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final knownTracksTickProvider =
    NotifierProvider<KnownTracksTickNotifier, int>(KnownTracksTickNotifier.new);

class LibraryScanNotifier extends AsyncNotifier<List<Track>> {
  @override
  Future<List<Track>> build() => _scan();

  /// Rescans without clearing the currently displayed list first, so a
  /// pull-to-refresh doesn't flash the list away while it re-queries.
  Future<void> refresh() async {
    state = await AsyncValue.guard(_scan);
  }

  Future<List<Track>> _scan() async {
    final tracks = await ref.read(audioLibraryRepositoryProvider).fetchTracks();

    // Record what this scan saw so new arrivals and vanished files can both
    // be surfaced. Never let bookkeeping failure break the library itself.
    try {
      await ref.read(knownTracksRepositoryProvider).reconcile({
        for (final track in tracks) track.path: track.id,
      });
      ref.read(knownTracksTickProvider.notifier).bump();
    } catch (_) {
      // Bookkeeping is best-effort.
    }

    return tracks;
  }
}

final libraryScanProvider = AsyncNotifierProvider<LibraryScanNotifier, List<Track>>(LibraryScanNotifier.new);

class LibrarySortState {
  const LibrarySortState(this.field, this.ascending);

  final LibrarySortField field;
  final bool ascending;
}

class LibrarySortNotifier extends Notifier<LibrarySortState> {
  @override
  LibrarySortState build() {
    final settings = ref.read(settingsRepositoryProvider).current;
    return LibrarySortState(_parseField(settings.librarySortField), settings.librarySortAscending);
  }

  Future<void> setField(LibrarySortField field) async {
    state = LibrarySortState(field, state.ascending);
    await _persist();
  }

  Future<void> toggleDirection() async {
    state = LibrarySortState(state.field, !state.ascending);
    await _persist();
  }

  Future<void> _persist() async {
    final repository = ref.read(settingsRepositoryProvider);
    final settings = repository.current;
    settings.librarySortField = state.field.name;
    settings.librarySortAscending = state.ascending;
    await repository.save(settings);
  }

  LibrarySortField _parseField(String value) {
    return LibrarySortField.values.firstWhere(
      (field) => field.name == value,
      orElse: () => LibrarySortField.title,
    );
  }
}

final librarySortProvider = NotifierProvider<LibrarySortNotifier, LibrarySortState>(LibrarySortNotifier.new);

final tracksByPathProvider = Provider<Map<String, Track>>((ref) {
  final tracks = ref.watch(libraryScanProvider).value ?? const <Track>[];
  return {for (final track in tracks) track.path: track};
});

/// Looks a scanned track back up from a stored path (queue items, folder
/// links and history all reference tracks by path).
final trackByPathProvider = Provider.family<Track?, String>((ref, path) {
  return ref.watch(tracksByPathProvider)[path];
});

/// Formats actually present in the library, so the filter panel only offers
/// options that can return something.
final availableFormatsProvider = Provider<List<String>>((ref) {
  final tracks = ref.watch(libraryScanProvider).value ?? const <Track>[];
  final formats = tracks.map((track) => track.format).where((f) => f.isNotEmpty).toSet().toList()..sort();
  return formats;
});

final librarySearchQueryProvider = NotifierProvider<TextQueryNotifier, String>(TextQueryNotifier.new);

final libraryFilterProvider = LibraryFilterProvider(LibraryFilterNotifier.new);

/// The library exactly as the list renders it: sorted, then narrowed by the
/// Library tab's own search box and filter panel.
final visibleLibraryProvider = Provider<AsyncValue<List<Track>>>((ref) {
  final tracksAsync = ref.watch(libraryScanProvider);
  final sort = ref.watch(librarySortProvider);
  final query = ref.watch(librarySearchQueryProvider);
  final filter = ref.watch(libraryFilterProvider);
  final folderRepository = ref.watch(folderRepositoryProvider);
  final historyRepository = ref.watch(historyRepositoryProvider);

  return tracksAsync.whenData((tracks) {
    final matched = filterTracks(
      tracks: tracks,
      query: query,
      filter: filter,
      categorizedPaths: folderRepository.getCategorizedPaths(),
      recentlyPlayedPaths: filter.recency == RecencyFilter.recentlyPlayed
          ? historyRepository.recentlyPlayedPaths(within: LibraryFilterState.recencyWindow)
          : const <String>{},
    );

    matched.sort((a, b) => _compare(a, b, sort.field));
    return sort.ascending ? matched : matched.reversed.toList();
  });
});

int _compare(Track a, Track b, LibrarySortField field) {
  switch (field) {
    case LibrarySortField.title:
      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    case LibrarySortField.artist:
      return a.artist.toLowerCase().compareTo(b.artist.toLowerCase());
    case LibrarySortField.album:
      return a.album.toLowerCase().compareTo(b.album.toLowerCase());
    case LibrarySortField.dateAdded:
      return a.dateAdded.compareTo(b.dateAdded);
    case LibrarySortField.duration:
      return a.duration.compareTo(b.duration);
  }
}
