import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../domain/folder_backup.dart';

/// A backup file on disk, with its contents if they could be parsed.
class StoredFolderBackup {
  const StoredFolderBackup({required this.file, this.backup, this.error});

  final File file;

  /// Null when the file could not be read as a backup; [error] then says why.
  final FolderBackup? backup;
  final String? error;

  String get fileName => p.basename(file.path);
}

/// Reads and writes folder backups as JSON files.
///
/// Files go somewhere a file manager can see, because the case this exists for
/// is the app's own storage going wrong: a backup kept inside the app's
/// private directory would be lost by the same clear-data that loses the
/// folders. Nothing here touches Hive or the user's audio.
class FolderBackupStore {
  static const _directoryName = 'folder_backups';
  static const _prefix = 'folders-';
  static const _extension = '.json';

  /// `Android/data/<package>/files/folder_backups` on Android: visible to a
  /// file manager, writable without asking for any storage permission, and
  /// the app's own space so nothing else is at risk if it goes wrong.
  Future<Directory> directory() async {
    final external = Platform.isAndroid ? await getExternalStorageDirectory() : null;
    final base = external ?? await getApplicationDocumentsDirectory();
    final directory = Directory(p.join(base.path, _directoryName));
    if (!await directory.exists()) await directory.create(recursive: true);
    return directory;
  }

  Future<File> write(FolderBackup backup) async {
    final directory = await this.directory();
    final file = File(p.join(directory.path, '$_prefix${_stamp(backup.createdAt)}$_extension'));
    await file.writeAsString(backup.encode(), flush: true);
    return file;
  }

  /// Every backup in the directory, newest first, each parsed so the list can
  /// show what restoring it would bring back.
  Future<List<StoredFolderBackup>> list() async {
    final directory = await this.directory();
    final files = (await directory.list().toList())
        .whereType<File>()
        .where((file) => p.extension(file.path) == _extension)
        .toList()
      // Names carry a sortable timestamp, so this is chronological. Mtime
      // would not be: copying files about rewrites it.
      ..sort((a, b) => p.basename(b.path).compareTo(p.basename(a.path)));

    final result = <StoredFolderBackup>[];
    for (final file in files) {
      try {
        result.add(StoredFolderBackup(file: file, backup: FolderBackup.decode(await file.readAsString())));
      } catch (error) {
        // Listed anyway: an unreadable file in this directory is something the
        // user should see rather than have quietly hidden from them.
        result.add(StoredFolderBackup(file: file, error: '$error'));
      }
    }
    return result;
  }

  Future<FolderBackup> read(File file) async => FolderBackup.decode(await file.readAsString());

  Future<void> delete(File file) async {
    if (await file.exists()) await file.delete();
  }

  /// `2026-10-06-153012` — sortable as text, and legible in a file name.
  String _stamp(DateTime time) {
    final local = time.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)}'
        '-${two(local.hour)}${two(local.minute)}${two(local.second)}';
  }
}
