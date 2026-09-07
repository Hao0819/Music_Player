import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import '../hive/hive_setup.dart';
import '../hive/models/folder_model.dart';
import '../hive/models/folder_track_link.dart';

const favoritesFolderId = 'favorites';

/// Owns the folder <-> track relationship, kept entirely decoupled from the
/// filesystem: folders and links only ever reference a track by its stable
/// file path, never duplicate its metadata, and are never touched by a
/// rescan — only [KnownTrackRecord]-based diffing reacts to real file changes.
class FolderRepository {
  static const _uuid = Uuid();

  Box<FolderModel> get _folders => Hive.box<FolderModel>(HiveBoxes.folders);
  Box<FolderTrackLink> get _links => Hive.box<FolderTrackLink>(HiveBoxes.folderTrackLinks);

  void ensureSystemFolders() {
    if (_folders.containsKey(favoritesFolderId)) return;
    _folders.put(
      favoritesFolderId,
      FolderModel(
        id: favoritesFolderId,
        name: 'Favorites',
        createdAt: DateTime.now(),
        isSystem: true,
      ),
    );
  }

  List<FolderModel> getAllFolders() {
    final all = _folders.values.toList()
      ..sort((a, b) {
        if (a.isSystem != b.isSystem) return a.isSystem ? -1 : 1;
        return a.createdAt.compareTo(b.createdAt);
      });
    return all;
  }

  FolderModel? getFolder(String id) => _folders.get(id);

  Future<FolderModel> createFolder(String name) async {
    final folder = FolderModel(id: _uuid.v4(), name: name.trim(), createdAt: DateTime.now());
    await _folders.put(folder.id, folder);
    return folder;
  }

  Future<void> renameFolder(String id, String newName) async {
    final folder = _folders.get(id);
    if (folder == null || folder.isSystem) return;
    folder.name = newName.trim();
    await folder.save();
  }

  Future<void> deleteFolder(String id) async {
    final folder = _folders.get(id);
    if (folder == null || folder.isSystem) return;
    final keysToRemove = _links.values.where((link) => link.folderId == id).map(_linkKeyFor).toList();
    await _links.deleteAll(keysToRemove);
    await _folders.delete(id);
  }

  Future<void> setSortMode(String folderId, String sortMode) async {
    final folder = _folders.get(folderId);
    if (folder == null) return;
    folder.sortMode = sortMode;
    await folder.save();
  }

  String _linkKey(String folderId, String trackPath) => '$folderId|$trackPath';

  String _linkKeyFor(FolderTrackLink link) => _linkKey(link.folderId, link.trackPath);

  bool isTrackInFolder(String folderId, String trackPath) => _links.containsKey(_linkKey(folderId, trackPath));

  bool isFavorite(String trackPath) => isTrackInFolder(favoritesFolderId, trackPath);

  /// Track paths in a folder, ordered by [FolderTrackLink.manualOrder].
  List<String> getTrackPaths(String folderId) {
    final links = _links.values.where((link) => link.folderId == folderId).toList()
      ..sort((a, b) => a.manualOrder.compareTo(b.manualOrder));
    return links.map((link) => link.trackPath).toList();
  }

  DateTime? addedAt(String folderId, String trackPath) => _links.get(_linkKey(folderId, trackPath))?.addedAt;

  Future<void> addTracks(String folderId, List<String> trackPaths) async {
    final existingOrders = _links.values.where((link) => link.folderId == folderId).map((l) => l.manualOrder);
    var nextOrder = existingOrders.isEmpty ? 0 : existingOrders.reduce((a, b) => a > b ? a : b) + 1;
    for (final path in trackPaths) {
      final key = _linkKey(folderId, path);
      if (_links.containsKey(key)) continue;
      await _links.put(
        key,
        FolderTrackLink(folderId: folderId, trackPath: path, addedAt: DateTime.now(), manualOrder: nextOrder++),
      );
    }
  }

  Future<void> removeTrack(String folderId, String trackPath) async {
    await _links.delete(_linkKey(folderId, trackPath));
  }

  Future<void> toggleFavorite(String trackPath) async {
    if (isFavorite(trackPath)) {
      await removeTrack(favoritesFolderId, trackPath);
    } else {
      await addTracks(favoritesFolderId, [trackPath]);
    }
  }

  /// Applies a new manual order to a folder from a freshly reordered path list.
  Future<void> reorder(String folderId, List<String> orderedPaths) async {
    for (var i = 0; i < orderedPaths.length; i++) {
      final link = _links.get(_linkKey(folderId, orderedPaths[i]));
      if (link != null) {
        link.manualOrder = i;
        await link.save();
      }
    }
  }

  /// Track paths that belong to at least one user-created (non-Favorites)
  /// folder — used by the "uncategorized" filter (module 4).
  Set<String> getCategorizedPaths() {
    return _links.values.where((link) => link.folderId != favoritesFolderId).map((link) => link.trackPath).toSet();
  }
}
