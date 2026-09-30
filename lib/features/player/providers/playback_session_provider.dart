import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/playback_session_repository.dart';
import '../../../domain/track.dart';
import '../../library/providers/library_providers.dart';
import 'player_providers.dart';

final playbackSessionRepositoryProvider =
    Provider<PlaybackSessionRepository>((ref) => PlaybackSessionRepository());

/// Brings back the last session once the library has loaded, then keeps it
/// saved as the user listens. Watch it from the shell to switch it on.
final playbackSessionProvider = Provider<void>((ref) {
  final keeper = _PlaybackSessionKeeper(ref);
  ref.onDispose(keeper.dispose);

  // Restoring needs real Track metadata, which only exists after a scan.
  ref.listen(libraryScanProvider, (_, next) {
    final tracks = next.value;
    if (tracks != null) keeper.restoreOnce(tracks);
  }, fireImmediately: true);
});

class _PlaybackSessionKeeper {
  _PlaybackSessionKeeper(this._ref);

  static const _positionSaveInterval = Duration(seconds: 5);

  final Ref _ref;
  final _subscriptions = <StreamSubscription<Object?>>[];
  Timer? _positionTimer;
  AppLifecycleListener? _lifecycle;
  bool _restoreAttempted = false;
  String? _lastSavedCurrent;

  PlaybackSessionRepository get _repository => _ref.read(playbackSessionRepositoryProvider);

  Future<void> restoreOnce(List<Track> library) async {
    if (_restoreAttempted) return;
    _restoreAttempted = true;

    try {
      await _restore(library);
    } catch (error) {
      debugPrint('Could not restore the last playback session: $error');
    } finally {
      // Saving only starts after the restore attempt: the player begins with
      // an empty queue, and saving that first would wipe the session we were
      // about to bring back.
      _startSaving();
    }
  }

  Future<void> _restore(List<Track> library) async {
    final handler = _ref.read(audioHandlerProvider);
    // The user already started something — never replace it.
    if (handler.queue.value.isNotEmpty) return;

    final session = _repository.load();
    if (session == null) return;

    final byPath = {for (final track in library) track.path: track};
    final tracks = session.queuePaths.map((path) => byPath[path]).whereType<Track>().toList();
    if (tracks.isEmpty) return;

    // Files may have been deleted since; if the current one is gone, start at
    // the top of what is left rather than a random neighbour mid-way through.
    final index = tracks.indexWhere((track) => track.path == session.currentPath);
    _lastSavedCurrent = index >= 0 ? session.currentPath : null;

    await handler.restoreTracks(
      tracks,
      initialIndex: index >= 0 ? index : 0,
      position: index >= 0 ? session.position : Duration.zero,
    );
  }

  void _startSaving() {
    final handler = _ref.read(audioHandlerProvider);

    _subscriptions
      ..add(handler.queue.listen((items) {
        if (items.isEmpty) return;
        _repository.saveQueue([for (final item in items) item.id]);
      }))
      ..add(handler.mediaItem.listen((item) {
        if (item == null || item.id == _lastSavedCurrent) return;
        _lastSavedCurrent = item.id;
        _repository.saveCurrent(item.id);
      }))
      // Paused, stopped or seeked while paused: these events are rare, so
      // saving on each one is cheap and catches the exact resume point.
      ..add(handler.playbackState.listen((state) {
        if (!state.playing) _savePosition();
      }));

    _positionTimer = Timer.periodic(_positionSaveInterval, (_) {
      if (handler.player.playing) _savePosition();
    });

    // MIUI and friends kill backgrounded apps without warning, so save the
    // moment the app leaves the screen too.
    _lifecycle = AppLifecycleListener(
      onHide: _savePosition,
      onPause: _savePosition,
      onDetach: _savePosition,
    );
  }

  void _savePosition() {
    if (_lastSavedCurrent == null) return;
    _repository.savePosition(_ref.read(audioHandlerProvider).player.position);
  }

  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _positionTimer?.cancel();
    _lifecycle?.dispose();
  }
}
