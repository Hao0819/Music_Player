import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/settings_repository.dart';
import '../../../domain/track.dart';
import '../../../services/audio/audio_player_handler.dart';
import '../../library/providers/library_providers.dart';

/// Overridden in `main()` once [AudioService.init] has produced the handler.
final audioHandlerProvider = Provider<AudioPlayerHandler>((ref) {
  throw StateError('audioHandlerProvider must be overridden in main()');
});

final playbackStateProvider = StreamProvider<PlaybackState>((ref) {
  return ref.watch(audioHandlerProvider).playbackState;
});

final currentMediaItemProvider = StreamProvider<MediaItem?>((ref) {
  return ref.watch(audioHandlerProvider).mediaItem;
});

final queueProvider = StreamProvider<List<MediaItem>>((ref) {
  return ref.watch(audioHandlerProvider).queue;
});

final playbackPositionProvider = StreamProvider<Duration>((ref) {
  return ref.watch(audioHandlerProvider).positionStream;
});

/// Everything the UI needs to drive playback, so screens never touch
/// just_audio or audio_service directly.
class PlayerController {
  PlayerController(this._ref) {
    // Every time the current item changes — tapping a track, skipping, or the
    // queue advancing on its own — log it so "recently played" and "most
    // played" have something to read back.
    _mediaItemSubscription = _handler.mediaItem.listen((item) async {
      if (item == null) return;
      await _ref.read(historyRepositoryProvider).recordPlay(item.id);
      _ref.read(historyTickProvider.notifier).bump();
    });
    _ref.onDispose(() => _mediaItemSubscription.cancel());
  }

  final Ref _ref;
  late final StreamSubscription<MediaItem?> _mediaItemSubscription;

  AudioPlayerHandler get _handler => _ref.read(audioHandlerProvider);

  Future<void> playTracks(List<Track> tracks, {int initialIndex = 0}) {
    return _handler.playTracks(tracks, initialIndex: initialIndex);
  }

  Future<void> togglePlayPause() {
    final playing = _ref.read(playbackStateProvider).value?.playing ?? false;
    return playing ? _handler.pause() : _handler.play();
  }

  Future<void> next() => _handler.skipToNext();

  Future<void> previous() => _handler.skipToPrevious();

  Future<void> seek(Duration position) => _handler.seek(position);

  Future<void> skipToQueueItem(int index) => _handler.skipToQueueItem(index);

  Future<void> moveQueueItem(int oldIndex, int newIndex) => _handler.moveQueueItem(oldIndex, newIndex);

  Future<void> removeQueueItemAt(int index) => _handler.removeQueueItemAt(index);

  /// Cycles all -> one -> none -> all, matching the button's three icons, and
  /// remembers the choice across launches.
  Future<void> cycleRepeatMode() async {
    final current = _ref.read(playbackStateProvider).value?.repeatMode ?? AudioServiceRepeatMode.all;
    final next = switch (current) {
      AudioServiceRepeatMode.all => AudioServiceRepeatMode.one,
      AudioServiceRepeatMode.one => AudioServiceRepeatMode.none,
      _ => AudioServiceRepeatMode.all,
    };
    await _handler.setRepeatMode(next);
    await _ref.read(settingsRepositoryProvider).updateRepeatMode(switch (next) {
      AudioServiceRepeatMode.one => 'one',
      AudioServiceRepeatMode.none => 'none',
      _ => 'all',
    });
  }

  Future<void> toggleShuffle() {
    final enabled = (_ref.read(playbackStateProvider).value?.shuffleMode ?? AudioServiceShuffleMode.none) !=
        AudioServiceShuffleMode.none;
    return _handler.setShuffleMode(
      enabled ? AudioServiceShuffleMode.none : AudioServiceShuffleMode.all,
    );
  }
}

final playerControllerProvider = Provider<PlayerController>((ref) => PlayerController(ref));
