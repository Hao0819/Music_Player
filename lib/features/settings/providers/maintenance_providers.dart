import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/track.dart';
import '../../folders/providers/folder_providers.dart';
import '../../library/providers/library_providers.dart';

/// Tracks discovered since the last time the user looked, so they can be
/// filed into folders. Empty on a first install — the existing library isn't
/// "new", it's the baseline.
final newTracksProvider = Provider<List<Track>>((ref) {
  ref.watch(knownTracksTickProvider);
  final byPath = ref.watch(tracksByPathProvider);
  final paths = ref.watch(knownTracksRepositoryProvider).unacknowledgedPaths();
  return paths.map((path) => byPath[path]).whereType<Track>().toList();
});

/// What a cleanup would remove: records left behind by files that are no
/// longer on the device.
class StaleRecords {
  const StaleRecords({
    required this.missingPaths,
    required this.folderLinks,
    required this.historyEntries,
  });

  final Set<String> missingPaths;
  final int folderLinks;
  final int historyEntries;

  bool get isEmpty => missingPaths.isEmpty;
}

final staleRecordsProvider = Provider<StaleRecords>((ref) {
  ref.watch(knownTracksTickProvider);
  ref.watch(folderLinksTickProvider);

  final missing = ref.watch(knownTracksRepositoryProvider).missingPaths();
  return StaleRecords(
    missingPaths: missing,
    folderLinks: ref.watch(folderRepositoryProvider).countLinksFor(missing),
    historyEntries: ref.watch(historyRepositoryProvider).countEntriesFor(missing),
  );
});

class MaintenanceActions {
  MaintenanceActions(this._ref);

  final Ref _ref;

  /// Removes folder links, history entries and the known-file records for
  /// every file that has disappeared. Audio files are never touched — by
  /// definition these ones are already gone.
  Future<void> cleanUpStaleRecords() async {
    final missing = _ref.read(knownTracksRepositoryProvider).missingPaths();
    if (missing.isEmpty) return;

    await _ref.read(folderRepositoryProvider).removeLinksFor(missing);
    await _ref.read(historyRepositoryProvider).removeEntriesFor(missing);
    await _ref.read(knownTracksRepositoryProvider).forget(missing);

    _ref.read(knownTracksTickProvider.notifier).bump();
    _ref.read(historyTickProvider.notifier).bump();
    _ref.read(folderActionsProvider).notifyLinksChanged();
  }

  Future<void> acknowledgeNewTracks(Iterable<String> paths) async {
    await _ref.read(knownTracksRepositoryProvider).acknowledge(paths);
    _ref.read(knownTracksTickProvider.notifier).bump();
  }

  Future<void> acknowledgeAllNewTracks() async {
    await _ref.read(knownTracksRepositoryProvider).acknowledgeAll();
    _ref.read(knownTracksTickProvider.notifier).bump();
  }
}

final maintenanceActionsProvider = Provider<MaintenanceActions>((ref) => MaintenanceActions(ref));
