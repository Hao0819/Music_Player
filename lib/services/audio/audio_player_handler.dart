import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

import '../../domain/track.dart';

/// Bridges [just_audio] (playback) and [audio_service] (notification, lock
/// screen, media buttons, background execution). The rest of the app talks to
/// this through `PlayerController` rather than touching either package.
class AudioPlayerHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  AudioPlayerHandler() {
    _player.playbackEventStream.map(_transformEvent).pipe(playbackState);

    _player.currentIndexStream.listen((index) {
      final items = queue.value;
      if (index != null && index >= 0 && index < items.length) {
        mediaItem.add(items[index]);
      }
    });
  }

  final AudioPlayer _player = AudioPlayer();

  AudioPlayer get player => _player;

  Stream<Duration> get positionStream => _player.positionStream;

  Stream<SequenceState> get sequenceStateStream => _player.sequenceStateStream;

  /// Replaces the queue with [tracks] and starts playing at [initialIndex].
  Future<void> playTracks(List<Track> tracks, {int initialIndex = 0}) async {
    if (tracks.isEmpty) return;

    final items = tracks.map(_toMediaItem).toList();
    queue.add(items);
    mediaItem.add(items[initialIndex.clamp(0, items.length - 1)]);

    await _player.setAudioSources(
      [for (final track in tracks) AudioSource.file(track.path)],
      initialIndex: initialIndex.clamp(0, tracks.length - 1),
    );
    await _player.play();
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() => _player.seekToNext();

  @override
  Future<void> skipToPrevious() => _player.seekToPrevious();

  @override
  Future<void> skipToQueueItem(int index) async {
    if (index < 0 || index >= queue.value.length) return;
    await _player.seek(Duration.zero, index: index);
    await _player.play();
  }

  @override
  Future<void> stop() async {
    await _player.stop();
    await super.stop();
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    await _player.setLoopMode(switch (repeatMode) {
      AudioServiceRepeatMode.one => LoopMode.one,
      AudioServiceRepeatMode.none => LoopMode.off,
      _ => LoopMode.all,
    });
    playbackState.add(playbackState.value.copyWith(repeatMode: repeatMode));
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    final enabled = shuffleMode != AudioServiceShuffleMode.none;
    if (enabled) await _player.shuffle();
    await _player.setShuffleModeEnabled(enabled);
    playbackState.add(playbackState.value.copyWith(shuffleMode: shuffleMode));
  }

  /// Reorders the queue, keeping the player's playlist and the media session's
  /// queue in step.
  Future<void> moveQueueItem(int oldIndex, int newIndex) async {
    final items = [...queue.value];
    if (oldIndex < 0 || oldIndex >= items.length || newIndex < 0 || newIndex >= items.length) return;

    await _player.moveAudioSource(oldIndex, newIndex);
    items.insert(newIndex, items.removeAt(oldIndex));
    queue.add(items);
  }

  @override
  Future<void> removeQueueItemAt(int index) async {
    final items = [...queue.value];
    if (index < 0 || index >= items.length) return;

    await _player.removeAudioSourceAt(index);
    items.removeAt(index);
    queue.add(items);
  }

  Future<void> dispose() => _player.dispose();

  MediaItem _toMediaItem(Track track) => MediaItem(
        id: track.path,
        title: track.title,
        artist: track.artist,
        album: track.album,
        duration: track.duration,
      );

  PlaybackState _transformEvent(PlaybackEvent event) {
    return PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        if (_player.playing) MediaControl.pause else MediaControl.play,
        MediaControl.skipToNext,
      ],
      systemActions: const {MediaAction.seek, MediaAction.seekForward, MediaAction.seekBackward},
      androidCompactActionIndices: const [0, 1, 2],
      processingState: switch (_player.processingState) {
        ProcessingState.idle => AudioProcessingState.idle,
        ProcessingState.loading => AudioProcessingState.loading,
        ProcessingState.buffering => AudioProcessingState.buffering,
        ProcessingState.ready => AudioProcessingState.ready,
        ProcessingState.completed => AudioProcessingState.completed,
      },
      playing: _player.playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: event.currentIndex,
      repeatMode: switch (_player.loopMode) {
        LoopMode.one => AudioServiceRepeatMode.one,
        LoopMode.all => AudioServiceRepeatMode.all,
        LoopMode.off => AudioServiceRepeatMode.none,
      },
      shuffleMode:
          _player.shuffleModeEnabled ? AudioServiceShuffleMode.all : AudioServiceShuffleMode.none,
    );
  }
}
