import 'package:on_audio_query/on_audio_query.dart';

import '../../domain/track.dart';
import '../../services/scanning/media_store_scanner.dart';

/// Path fragments whose audio is noise rather than music. Matched
/// case-insensitively against the full file path.
const _excludedPathFragments = [
  '/whatsapp/media/whatsapp audio/',
  '/whatsapp/media/whatsapp voice notes/',
  '/whatsapp business/media/whatsapp business audio/',
  '/whatsapp business/media/whatsapp business voice notes/',
];

class AudioLibraryRepository {
  AudioLibraryRepository(this._query, this._scanner);

  final OnAudioQuery _query;
  final MediaStoreScanner _scanner;

  /// Combines two scans and keeps the union:
  ///
  /// * `on_audio_query` — well-parsed rows from the audio collection, which
  ///   carry the best metadata.
  /// * our native files-collection query — catches audio MediaStore filed as
  ///   generic files (common for Download folders) and other volumes.
  ///
  /// Plugin rows win on conflict since their metadata is richer.
  Future<List<Track>> fetchTracks() async {
    final results = await Future.wait([
      _queryViaPlugin(),
      _scanner.queryAudioFiles(),
    ]);

    final byPath = <String, Track>{};
    for (final track in results[1]) {
      byPath[track.path] = track;
    }
    for (final track in results[0]) {
      byPath[track.path] = track;
    }

    return byPath.values.where(_isWanted).toList();
  }

  Future<List<Track>> _queryViaPlugin() async {
    final songs = await _query.querySongs(
      sortType: SongSortType.TITLE,
      orderType: OrderType.ASC_OR_SMALLER,
      uriType: UriType.EXTERNAL,
      ignoreCase: true,
    );
    return songs.map(Track.fromSongModel).toList();
  }

  bool _isWanted(Track track) {
    if (track.path.isEmpty) return false;

    final path = track.path.toLowerCase();
    return !_excludedPathFragments.any(path.contains);
  }
}
