import 'package:on_audio_query/on_audio_query.dart';

/// A single audio file. Built from whatever source found it — the
/// `on_audio_query` plugin or our own broader MediaStore query — so the rest
/// of the app never cares which scan turned it up.
///
/// Nothing here is ever persisted: folders, favorites and history all
/// reference a track by [path], and metadata is re-read on every scan.
class Track {
  const Track({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.path,
    required this.duration,
    required this.dateAdded,
    required this.format,
  });

  factory Track.fromSongModel(SongModel song) {
    return Track(
      id: song.id,
      title: _cleanTitle(song.title, song.data),
      artist: _clean(song.artist, 'Unknown artist'),
      album: _clean(song.album, 'Unknown album'),
      path: song.data,
      duration: Duration(milliseconds: song.duration ?? 0),
      dateAdded: _dateFromSeconds(song.dateAdded),
      format: song.fileExtension.toUpperCase(),
    );
  }

  /// Built from the raw row returned by our native MediaStore query.
  factory Track.fromMediaStoreMap(Map<Object?, Object?> row) {
    final path = (row['path'] as String?) ?? '';
    return Track(
      id: (row['id'] as num?)?.toInt() ?? 0,
      title: _cleanTitle(row['title'] as String?, path),
      artist: _clean(row['artist'] as String?, 'Unknown artist'),
      album: _clean(row['album'] as String?, 'Unknown album'),
      path: path,
      duration: Duration(milliseconds: (row['duration'] as num?)?.toInt() ?? 0),
      dateAdded: _dateFromSeconds((row['dateAdded'] as num?)?.toInt()),
      format: _extensionOf(path),
    );
  }

  final int id;
  final String title;
  final String artist;
  final String album;

  /// Stable key for folder links, favorites and history — never the
  /// MediaStore [id], which can be reassigned when the system re-indexes.
  final String path;

  final Duration duration;
  final DateTime dateAdded;
  final String format;

  /// First letter used by the A–Z index, or '#' for anything non-alphabetic.
  String get indexLetter {
    for (final char in title.trim().toUpperCase().split('')) {
      if (RegExp('[A-Z]').hasMatch(char)) return char;
      break;
    }
    return '#';
  }

  static String _clean(String? value, String fallback) {
    if (value == null) return fallback;
    final trimmed = value.trim();
    if (trimmed.isEmpty || trimmed == '<unknown>') return fallback;
    return trimmed;
  }

  /// Files that MediaStore never parsed have no title, so fall back to the
  /// file name rather than showing a blank row.
  static String _cleanTitle(String? title, String path) {
    final value = title?.trim();
    if (value != null && value.isNotEmpty && value != '<unknown>') return value;

    final name = path.split('/').last;
    final dot = name.lastIndexOf('.');
    return dot > 0 ? name.substring(0, dot) : name;
  }

  static DateTime _dateFromSeconds(int? seconds) {
    if (seconds == null || seconds <= 0) return DateTime.fromMillisecondsSinceEpoch(0);
    return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
  }

  static String _extensionOf(String path) {
    final name = path.split('/').last;
    final dot = name.lastIndexOf('.');
    return dot > 0 ? name.substring(dot + 1).toUpperCase() : '';
  }
}

enum LibrarySortField { title, artist, album, dateAdded, duration }
