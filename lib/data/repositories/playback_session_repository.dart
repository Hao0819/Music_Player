import 'package:hive/hive.dart';

import '../hive/hive_setup.dart';

/// What was playing when the app was last used.
class PlaybackSession {
  const PlaybackSession({
    required this.queuePaths,
    required this.currentPath,
    required this.position,
  });

  final List<String> queuePaths;
  final String currentPath;
  final Duration position;
}

/// Remembers the queue, the current track and how far into it playback got,
/// so reopening the app picks up where the user left off. Tracks are stored by
/// path, like everything else, and matched back to the library on restore.
class PlaybackSessionRepository {
  static const _queueKey = 'queue';
  static const _currentKey = 'current';
  static const _positionKey = 'position_ms';

  Box<dynamic> get _box => Hive.box<dynamic>(HiveBoxes.playbackSession);

  PlaybackSession? load() {
    final queue = (_box.get(_queueKey) as List?)?.whereType<String>().toList();
    final current = _box.get(_currentKey) as String?;
    if (queue == null || queue.isEmpty || current == null) return null;

    return PlaybackSession(
      queuePaths: queue,
      currentPath: current,
      position: Duration(milliseconds: (_box.get(_positionKey) as int?) ?? 0),
    );
  }

  Future<void> saveQueue(List<String> paths) => _box.put(_queueKey, paths);

  Future<void> saveCurrent(String path) => _box.putAll({_currentKey: path, _positionKey: 0});

  Future<void> savePosition(Duration position) => _box.put(_positionKey, position.inMilliseconds);
}
