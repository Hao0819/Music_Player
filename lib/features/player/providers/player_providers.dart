import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/track.dart';
import '../../../services/audio/audio_player_handler.dart';
import '../../search/providers/search_providers.dart';

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
    _mediaItemSubscription = _handler.mediaItem.listen((item) {
      if (item != null) {
        _ref.read(historyRepositoryProvider).recordPlay(item.id);
      }
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

  /// Cycles none -> all -> one -> none, matching the button's three icons.
  Future<void> cycleRepeatMode() {
    final current = _ref.read(playbackStateProvider).value?.repeatMode ?? AudioServiceRepeatMode.none;
    final next = switch (current) {
      AudioServiceRepeatMode.none => AudioServiceRepeatMode.all,
      AudioServiceRepeatMode.all => AudioServiceRepeatMode.one,
      _ => AudioServiceRepeatMode.none,
    };
    return _handler.setRepeatMode(next);
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
