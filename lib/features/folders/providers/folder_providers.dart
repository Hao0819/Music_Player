import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/hive/models/folder_model.dart';
import '../../../data/repositories/folder_repository.dart';
import '../../../domain/folder_sort_mode.dart';
import '../../../domain/track.dart';
import '../../library/providers/library_providers.dart';

final folderRepositoryProvider = Provider<FolderRepository>((ref) => FolderRepository());

/// Bumped after any folder-track link mutation (add/remove/reorder/favorite)
/// so dependent providers know to recompute. Hive writes are synchronous
/// local state, so a simple version counter is enough — no need for a
/// separate stream/notifier per relationship.
class _LinksTickNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final _linksTickProvider = NotifierProvider<_LinksTickNotifier, int>(_LinksTickNotifier.new);

final folderListProvider = Provider<List<FolderModel>>((ref) {
  ref.watch(_linksTickProvider);
  final repository = ref.watch(folderRepositoryProvider);
  repository.ensureSystemFolders();
  return repository.getAllFolders();
});

final folderByIdProvider = Provider.family<FolderModel?, String>((ref, id) {
  final folders = ref.watch(folderListProvider);
  for (final folder in folders) {
    if (folder.id == id) return folder;
  }
  return null;
});

final isFavoriteProvider = Provider.family<bool, String>((ref, trackPath) {
  ref.watch(_linksTickProvider);
  return ref.watch(folderRepositoryProvider).isFavorite(trackPath);
});

final folderTracksProvider = Provider.family<AsyncValue<List<Track>>, String>((ref, folderId) {
  ref.watch(_linksTickProvider);
  final tracksAsync = ref.watch(libraryScanProvider);
  final repository = ref.watch(folderRepositoryProvider);
  final folder = repository.getFolder(folderId);
  final sortMode = FolderSortMode.values.firstWhere(
    (mode) => mode.name == folder?.sortMode,
    orElse: () => FolderSortMode.manual,
  );

  return tracksAsync.whenData((allTracks) {
    final byPath = {for (final track in allTracks) track.path: track};
    final orderedPaths = repository.getTrackPaths(folderId);
    final tracks = orderedPaths.map((path) => byPath[path]).whereType<Track>().toList();

    if (sortMode == FolderSortMode.manual) return tracks;

    tracks.sort((a, b) => switch (sortMode) {
          FolderSortMode.title => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
          FolderSortMode.artist => a.artist.toLowerCase().compareTo(b.artist.toLowerCase()),
          FolderSortMode.album => a.album.toLowerCase().compareTo(b.album.toLowerCase()),
          FolderSortMode.duration => a.duration.compareTo(b.duration),
          FolderSortMode.addedToFolder => (repository.addedAt(folderId, a.path) ?? DateTime(0))
              .compareTo(repository.addedAt(folderId, b.path) ?? DateTime(0)),
          FolderSortMode.manual => 0,
        });
    return tracks;
  });
});

class FolderActions {
  FolderActions(this._ref);

  final Ref _ref;

  FolderRepository get _repository => _ref.read(folderRepositoryProvider);

  Future<FolderModel> createFolder(String name) async {
    final folder = await _repository.createFolder(name);
    _ref.invalidate(folderListProvider);
    return folder;
  }

  Future<void> renameFolder(String id, String name) async {
    await _repository.renameFolder(id, name);
    _ref.invalidate(folderListProvider);
  }

  Future<void> deleteFolder(String id) async {
    await _repository.deleteFolder(id);
    _ref.invalidate(folderListProvider);
    _bumpLinks();
  }

  Future<void> setSortMode(String folderId, FolderSortMode mode) async {
    await _repository.setSortMode(folderId, mode.name);
    _ref.invalidate(folderListProvider);
  }

  Future<void> addTracks(String folderId, List<String> trackPaths) async {
    await _repository.addTracks(folderId, trackPaths);
    _bumpLinks();
  }

  Future<void> removeTrack(String folderId, String trackPath) async {
    await _repository.removeTrack(folderId, trackPath);
    _bumpLinks();
  }

  Future<void> reorder(String folderId, List<String> orderedPaths) async {
    await _repository.reorder(folderId, orderedPaths);
    _bumpLinks();
  }

  Future<void> toggleFavorite(String trackPath) async {
    await _repository.toggleFavorite(trackPath);
    _bumpLinks();
  }

  void _bumpLinks() => _ref.read(_linksTickProvider.notifier).bump();
}

final folderActionsProvider = Provider<FolderActions>((ref) => FolderActions(ref));
