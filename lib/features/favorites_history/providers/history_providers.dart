import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/track.dart';
import '../../library/providers/library_providers.dart';

/// Which auto-collection a history screen is showing.
enum HistoryView { recentlyPlayed, mostPlayed }

/// History stores paths; the live library supplies the metadata. Tracks whose
/// file has since disappeared simply drop out of the list.
List<Track> _resolve(List<String> paths, Map<String, Track> byPath) {
  return paths.map((path) => byPath[path]).whereType<Track>().toList();
}

final recentlyPlayedTracksProvider = Provider<List<Track>>((ref) {
  ref.watch(historyTickProvider);
  final byPath = ref.watch(tracksByPathProvider);
  return _resolve(ref.watch(historyRepositoryProvider).recentPaths(limit: 100), byPath);
});

final mostPlayedTracksProvider = Provider<List<Track>>((ref) {
  ref.watch(historyTickProvider);
  final byPath = ref.watch(tracksByPathProvider);
  return _resolve(ref.watch(historyRepositoryProvider).mostPlayedPaths(limit: 100), byPath);
});

final playCountsProvider = Provider<Map<String, int>>((ref) {
  ref.watch(historyTickProvider);
  return ref.watch(historyRepositoryProvider).playCounts();
});

final historyTracksProvider = Provider.family<List<Track>, HistoryView>((ref, view) {
  return switch (view) {
    HistoryView.recentlyPlayed => ref.watch(recentlyPlayedTracksProvider),
    HistoryView.mostPlayed => ref.watch(mostPlayedTracksProvider),
  };
});

final clearHistoryProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    await ref.read(historyRepositoryProvider).clear();
    ref.read(historyTickProvider.notifier).bump();
  };
});
