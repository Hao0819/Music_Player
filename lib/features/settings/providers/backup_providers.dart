import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/hive/hive_setup.dart';
import '../../../domain/folder_backup.dart';
import '../../../services/backup/folder_backup_store.dart';
import '../../folders/providers/folder_providers.dart';

final folderBackupStoreProvider = Provider<FolderBackupStore>((ref) => FolderBackupStore());

/// Boxes this launch had to set aside because their file would not open.
/// Startup state, so it never changes while the app is running.
final setAsideBoxesProvider = Provider<List<SetAsideBox>>((ref) => List.unmodifiable(setAsideBoxes));

/// The backup files currently on disk, newest first.
final folderBackupsProvider = FutureProvider<List<StoredFolderBackup>>((ref) {
  return ref.watch(folderBackupStoreProvider).list();
});

/// Where the backups are kept, shown to the user so they can get at the files
/// with a file manager or copy them off the device.
final folderBackupDirectoryProvider = FutureProvider<String>((ref) async {
  final directory = await ref.watch(folderBackupStoreProvider).directory();
  return directory.path;
});

/// What exporting right now would write out, for the button's subtitle.
final folderBackupPreviewProvider = Provider<FolderBackup>((ref) {
  ref.watch(folderLinksTickProvider);
  ref.watch(folderListProvider);
  return ref.watch(folderRepositoryProvider).exportBackup();
});

class FolderBackupActions {
  FolderBackupActions(this._ref);

  final Ref _ref;

  Future<StoredFolderBackup> exportNow() async {
    final backup = _ref.read(folderRepositoryProvider).exportBackup();
    final file = await _ref.read(folderBackupStoreProvider).write(backup);
    _ref.invalidate(folderBackupsProvider);
    return StoredFolderBackup(file: file, backup: backup);
  }

  /// Re-read from disk rather than trusting the parsed copy the list is
  /// holding, so what gets restored is what the file says right now.
  Future<FolderImportSummary> restore(StoredFolderBackup stored) async {
    final backup = await _ref.read(folderBackupStoreProvider).read(stored.file);
    final summary = await _ref.read(folderRepositoryProvider).importBackup(backup);
    _ref.read(folderActionsProvider).notifyLinksChanged();
    return summary;
  }

  Future<void> delete(StoredFolderBackup stored) async {
    await _ref.read(folderBackupStoreProvider).delete(stored.file);
    _ref.invalidate(folderBackupsProvider);
  }
}

final folderBackupActionsProvider = Provider<FolderBackupActions>((ref) => FolderBackupActions(ref));
