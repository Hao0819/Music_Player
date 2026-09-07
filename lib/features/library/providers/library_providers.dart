import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:on_audio_query/on_audio_query.dart';

import '../../../core/selection_notifier.dart';
import '../../../data/repositories/audio_library_repository.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../domain/track.dart';

final librarySelectionProvider = NotifierProvider<SelectionNotifier, Set<String>>(SelectionNotifier.new);

final onAudioQueryProvider = Provider<OnAudioQuery>((ref) => OnAudioQuery());

final audioLibraryRepositoryProvider = Provider<AudioLibraryRepository>((ref) {
  return AudioLibraryRepository(ref.watch(onAudioQueryProvider));
});

class LibraryScanNotifier extends AsyncNotifier<List<Track>> {
  @override
  Future<List<Track>> build() => _scan();

  /// Rescans without clearing the currently displayed list first, so a
  /// pull-to-refresh doesn't flash the list away while it re-queries.
  Future<void> refresh() async {
    state = await AsyncValue.guard(_scan);
  }

  Future<List<Track>> _scan() => ref.read(audioLibraryRepositoryProvider).fetchTracks();
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

final sortedLibraryProvider = Provider<AsyncValue<List<Track>>>((ref) {
  final tracksAsync = ref.watch(libraryScanProvider);
  final sort = ref.watch(librarySortProvider);

  return tracksAsync.whenData((tracks) {
    final sorted = [...tracks]..sort((a, b) => _compare(a, b, sort.field));
    return sort.ascending ? sorted : sorted.reversed.toList();
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
