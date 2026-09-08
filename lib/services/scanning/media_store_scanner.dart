import 'package:flutter/services.dart';

import '../../domain/track.dart';

/// Talks to the native broader MediaStore query (see `MainActivity.kt`).
class MediaStoreScanner {
  static const _channel = MethodChannel('music_player/media_store');

  /// Returns every audio-looking file MediaStore knows about, across all
  /// volumes. Returns an empty list rather than throwing if the platform side
  /// is unavailable, so the plugin-based scan can still stand alone.
  Future<List<Track>> queryAudioFiles() async {
    try {
      final rows = await _channel.invokeListMethod<Object?>('queryAudioFiles');
      if (rows == null) return const [];

      return rows
          .whereType<Map<Object?, Object?>>()
          .map(Track.fromMediaStoreMap)
          .where((track) => track.path.isNotEmpty)
          .toList();
    } on PlatformException {
      return const [];
    } on MissingPluginException {
      return const [];
    }
  }
}
