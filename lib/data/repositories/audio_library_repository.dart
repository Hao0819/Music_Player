import 'package:on_audio_query/on_audio_query.dart';

import '../../domain/track.dart';

class AudioLibraryRepository {
  AudioLibraryRepository(this._query);

  final OnAudioQuery _query;

  Future<List<Track>> fetchTracks() async {
    final songs = await _query.querySongs(
      sortType: SongSortType.TITLE,
      orderType: OrderType.ASC_OR_SMALLER,
      uriType: UriType.EXTERNAL,
      ignoreCase: true,
    );
    return songs.map(Track.new).toList();
  }
}
