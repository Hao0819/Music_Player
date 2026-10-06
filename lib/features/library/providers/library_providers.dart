import 'dart:async';

import 'package:flutter/foundation.dart';
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
  /// The last list this notifier produced, kept so a rescan can hand back the
  /// very same [Track] objects for files that have not changed. Not read from
  /// `state`, which is not available while [build] is still running.
  List<Track> _previous = const [];

  /// Distinguishes scans, so the tail end of one that has been superseded does
  /// not publish its result over a newer one.
  int _token = 0;

  @override
  Future<List<Track>> build() => _scan();

  /// Rescans without clearing the currently displayed list first, so a
  /// pull-to-refresh doesn't flash the list away while it re-queries.
  Future<void> refresh() async {
    state = await AsyncValue.guard(_scan);
  }

  /// Resolves as soon as the plugin's rows are ready; the broader native pass
  /// and the Hive bookkeeping both land afterwards, through [_finish].
  Future<List<Track>> _scan() async {
    final token = ++_token;
    final scan = ref.read(audioLibraryRepositoryProvider).startScan();
    final firstPass = _reusing(await scan.firstPass);

    // Deliberately not awaited: it continues after this future completes, and
    // therefore after build() has returned, which is what makes assigning
    // state from it legal.
    unawaited(_finish(scan, token));

    return firstPass;
  }

  /// Merges the second pass and records the scan, in that order, once the list
  /// on screen is already usable.
  Future<void> _finish(LibraryScan scan, int token) async {
    try {
      final merged = await scan.complete;
      if (!_isCurrent(token)) return;
      // Null means the broader pass found nothing new, so the list on screen
      // is already the final answer and re-publishing it would only cost a
      // re-sort of every row.
      if (merged != null) state = AsyncData(_reusing(merged));
    } catch (error) {
      // The second pass is an addition to a list that already works, so a
      // failure here must not replace the library with an error.
      debugPrint('The broader MediaStore pass failed: $error');
    }

    if (!_isCurrent(token)) return;

    // Bookkeeping last, and off the critical path: it writes to Hive, and
    // doing that before returning the tracks put a disk write between the scan
    // finishing and the first frame that could show it.
    try {
      await ref.read(knownTracksRepositoryProvider).reconcile({
        for (final track in _previous) track.path: track.id,
      });
      if (_isCurrent(token)) ref.read(knownTracksTickProvider.notifier).bump();
    } catch (_) {
      // Bookkeeping is best-effort.
    }
  }

  /// Whether [token] is still the live scan and the provider is still alive.
  bool _isCurrent(int token) => token == _token && ref.mounted;

  /// Swaps in the previous [Track] instance wherever the file is unchanged.
  ///
  /// Track computes its sort keys, index letters and search haystack on first
  /// use and caches them on the instance. A scan that replaces every object
  /// throws all of that away and pays for it again on the next sort, which is
  /// most of what made a rescan stutter — even though a rescan usually finds
  /// the library exactly as it left it.
  List<Track> _reusing(List<Track> scanned) {
    if (_previous.isEmpty) return _previous = scanned;

    final existing = {for (final track in _previous) track.path: track};
    return _previous = [
      for (final track in scanned)
        if (existing[track.path] case final known? when known.matches(track)) known else track,
    ];
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
      return a.titleKey.compareTo(b.titleKey);
    case LibrarySortField.artist:
      return a.artistKey.compareTo(b.artistKey);
    case LibrarySortField.album:
      return a.albumKey.compareTo(b.albumKey);
    case LibrarySortField.dateAdded:
      return a.dateAdded.compareTo(b.dateAdded);
    case LibrarySortField.duration:
      return a.duration.compareTo(b.duration);
  }
}
