import 'package:on_audio_query/on_audio_query.dart';

/// Thin wrapper around [SongModel]. Deliberately holds no state of its own —
/// title/artist/cover/duration are always read live from on_audio_query, per
/// the app's rule that Hive only ever stores relationships, never metadata.
class Track {
  const Track(this.song);

  final SongModel song;

  int get id => song.id;

  String get title => song.title;

  String get artist {
    final value = song.artist;
    return (value == null || value.isEmpty || value == '<unknown>') ? 'Unknown artist' : value;
  }

  String get album {
    final value = song.album;
    return (value == null || value.isEmpty || value == '<unknown>') ? 'Unknown album' : value;
  }

  /// Stable file path, used as the key for folder links, favorites and
  /// history — never the MediaStore [id], which can be reassigned on rescan.
  String get path => song.data;

  Duration get duration => Duration(milliseconds: song.duration ?? 0);

  DateTime get dateAdded {
    final seconds = song.dateAdded;
    if (seconds == null) return DateTime.fromMillisecondsSinceEpoch(0);
    return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
  }

  String get format => song.fileExtension.toUpperCase();
}

enum LibrarySortField { title, artist, album, dateAdded, duration }
