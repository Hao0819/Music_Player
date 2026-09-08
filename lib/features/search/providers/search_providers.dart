import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/library_filter_notifier.dart';
import '../../../core/text_query_notifier.dart';
import '../../../domain/library_filter_state.dart';
import '../../../domain/track.dart';
import '../../../domain/track_filtering.dart';
import '../../folders/providers/folder_providers.dart';
import '../../library/providers/library_providers.dart';

final searchQueryProvider = NotifierProvider<TextQueryNotifier, String>(TextQueryNotifier.new);

/// Separate from the Library tab's filter so the two screens don't fight over
/// one another's state.
final searchFilterProvider = LibraryFilterProvider(LibraryFilterNotifier.new);

final searchResultsProvider = Provider<AsyncValue<List<Track>>>((ref) {
  final tracksAsync = ref.watch(libraryScanProvider);
  final query = ref.watch(searchQueryProvider);
  final filter = ref.watch(searchFilterProvider);
  final folderRepository = ref.watch(folderRepositoryProvider);
  final historyRepository = ref.watch(historyRepositoryProvider);

  return tracksAsync.whenData((tracks) {
    return filterTracks(
      tracks: tracks,
      query: query,
      filter: filter,
      categorizedPaths: folderRepository.getCategorizedPaths(),
      recentlyPlayedPaths: filter.recency == RecencyFilter.recentlyPlayed
          ? historyRepository.recentlyPlayedPaths(within: LibraryFilterState.recencyWindow)
          : const <String>{},
    );
  });
});
