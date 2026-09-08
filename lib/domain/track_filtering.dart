import '../core/utils/fuzzy_match.dart';
import 'library_filter_state.dart';
import 'track.dart';

/// Applies a text query and a filter set to a track list.
///
/// Pure and source-agnostic so the Library tab and the Search tab can each
/// hold their own query/filter state without duplicating the rules.
List<Track> filterTracks({
  required List<Track> tracks,
  required String query,
  required LibraryFilterState filter,
  required Set<String> categorizedPaths,
  required Set<String> recentlyPlayedPaths,
  DateTime? now,
}) {
  final addedCutoff = (now ?? DateTime.now()).subtract(LibraryFilterState.recencyWindow);

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
        if (!recentlyPlayedPaths.contains(track.path)) return false;
      case RecencyFilter.any:
        break;
    }

    return true;
  }).toList();
}
