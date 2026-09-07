import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/text_query_notifier.dart';
import '../../../core/utils/fuzzy_match.dart';
import '../../../data/repositories/history_repository.dart';
import '../../../domain/library_filter_state.dart';
import '../../../domain/track.dart';
import '../../folders/providers/folder_providers.dart';
import '../../library/providers/library_providers.dart';

final historyRepositoryProvider = Provider<HistoryRepository>((ref) => HistoryRepository());

final searchQueryProvider = NotifierProvider<TextQueryNotifier, String>(TextQueryNotifier.new);

class LibraryFilterNotifier extends Notifier<LibraryFilterState> {
  @override
  LibraryFilterState build() => const LibraryFilterState();

  void toggleFormat(String format) {
    final formats = {...state.formats};
    if (!formats.remove(format)) formats.add(format);
    state = state.copyWith(formats: formats);
  }

  void setDurationRange(Duration min, Duration max) {
    state = state.copyWith(minDuration: min, maxDuration: max);
  }

  void setCategorized(CategorizedFilter value) => state = state.copyWith(categorized: value);

  void setRecency(RecencyFilter value) => state = state.copyWith(recency: value);

  void reset() => state = const LibraryFilterState();
}

final libraryFilterProvider =
    NotifierProvider<LibraryFilterNotifier, LibraryFilterState>(LibraryFilterNotifier.new);

/// Formats actually present in the library, so the filter panel only offers
/// options that can return something.
final availableFormatsProvider = Provider<List<String>>((ref) {
  final tracks = ref.watch(libraryScanProvider).value ?? const <Track>[];
  final formats = tracks.map((track) => track.format).toSet().toList()..sort();
  return formats;
});

final searchResultsProvider = Provider<AsyncValue<List<Track>>>((ref) {
  final tracksAsync = ref.watch(libraryScanProvider);
  final query = ref.watch(searchQueryProvider);
  final filter = ref.watch(libraryFilterProvider);
  final folderRepository = ref.watch(folderRepositoryProvider);
  final historyRepository = ref.watch(historyRepositoryProvider);

  return tracksAsync.whenData((tracks) {
    final categorizedPaths = folderRepository.getCategorizedPaths();
    final addedCutoff = DateTime.now().subtract(LibraryFilterState.recencyWindow);
    final recentlyPlayed = filter.recency == RecencyFilter.recentlyPlayed
        ? historyRepository.recentlyPlayedPaths(within: LibraryFilterState.recencyWindow)
        : const <String>{};

    return tracks.where((track) {
      if (!fuzzyMatches(query, [track.title, track.artist, track.album])) return false;
      if (filter.formats.isNotEmpty && !filter.formats.contains(track.format)) return false;
      if (track.duration < filter.minDuration) return false;
      if (filter.hasUpperDurationLimit && track.duration > filter.maxDuration) return false;

      switch (filter.categorized) {
        case CategorizedFilter.categorized:
          if (!categorizedPaths.contains(track.path)) return false;
        case CategorizedFilter.uncategorized:
          if (categorizedPaths.contains(track.path)) return false;
        case CategorizedFilter.any:
          break;
      }

      switch (filter.recency) {
        case RecencyFilter.recentlyAdded:
          if (track.dateAdded.isBefore(addedCutoff)) return false;
        case RecencyFilter.recentlyPlayed:
          if (!recentlyPlayed.contains(track.path)) return false;
        case RecencyFilter.any:
          break;
      }

      return true;
    }).toList();
  });
});
