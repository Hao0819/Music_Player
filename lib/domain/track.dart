import 'package:on_audio_query/on_audio_query.dart';
import 'package:pinyin/pinyin.dart';

/// A single audio file. Built from whatever source found it — the
/// `on_audio_query` plugin or our own broader MediaStore query — so the rest
/// of the app never cares which scan turned it up.
///
/// Nothing here is ever persisted: folders, favorites and history all
/// reference a track by [path], and metadata is re-read on every scan.
class Track {
  Track({
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

  /// Sort keys, with Han characters romanised.
  ///
  /// Sorting on the raw strings ordered Chinese by UTF-16 code point, which is
  /// not an order anyone reads in, and left the A–Z index pointing at
  /// positions that did not correspond to its letters. Non-Han text is passed
  /// through unchanged, so Latin titles sort exactly as before.
  ///
  /// Computed once per track instead of per comparison: sorting a library of a
  /// thousand runs on the order of ten thousand comparisons, and the whole
  /// sort reruns whenever the query changes.
  late final String titleKey = _sortKey(title);
  late final String artistKey = _sortKey(artist);
  late final String albumKey = _sortKey(album);

  /// Everything a text query is matched against, lower-cased and joined once.
  ///
  /// Deliberately the original text, not the romanised form: typing Chinese
  /// has to match Chinese. (Searching by pinyin would be a separate feature,
  /// and would need this to hold both.)
  late final String searchHaystack = '$title $artist $album'.toLowerCase();

  /// First letter used by the A–Z index, per field, so the strip agrees with
  /// whichever column the list is currently sorted on. It used to be derived
  /// from the title whatever the sort was, which made every jump wrong while
  /// sorted by artist or album.
  late final String indexLetter = _indexLetterOf(title);
  late final String artistIndexLetter = _indexLetterOf(artist);
  late final String albumIndexLetter = _indexLetterOf(album);

  static final _letterPattern = RegExp('[A-Z]');
  static final _digitPattern = RegExp('[0-9]');
  static final _han = RegExp(r'[㐀-䶿一-鿿豈-﫿]');

  /// Strips leading `[...]` / `(...)` tags.
  ///
  /// Files pulled off YouTube arrive titled `[1080P] ...`, `( 歌詞 ) ...`,
  /// `[4K _ 60fps] ...`. Indexing on those puts most of a library under a
  /// single letter — and under '#', since they start with punctuation — which
  /// is the same as having no index at all.
  static String _withoutLeadingTags(String value) {
    var rest = value.trimLeft();

    while (rest.isNotEmpty) {
      final close = switch (rest[0]) {
        '[' => ']',
        '(' => ')',
        '（' => '）',
        '【' => '】',
        _ => null,
      };
      if (close == null) break;

      final end = rest.indexOf(close);
      if (end < 0) break;
      rest = rest.substring(end + 1).trimLeft();
    }

    // A title that is nothing but a tag keeps its original text; dropping it
    // entirely would leave the row with no sort position at all.
    return rest.isEmpty ? value.trimLeft() : rest;
  }

  static String _sortKey(String value) {
    final stripped = _withoutLeadingTags(value);
    if (!_han.hasMatch(stripped)) return stripped.toLowerCase();

    return PinyinHelper.getPinyinE(
      stripped,
      separator: ' ',
      format: PinyinFormat.WITHOUT_TONE,
    ).toLowerCase();
  }

  static String _indexLetterOf(String value) {
    final stripped = _withoutLeadingTags(value);

    for (final char in stripped.split('')) {
      if (_han.hasMatch(char)) {
        final pinyin = PinyinHelper.getFirstWordPinyin(char);
        if (pinyin.isEmpty) return '#';
        final letter = pinyin[0].toUpperCase();
        return _letterPattern.hasMatch(letter) ? letter : '#';
      }

      final upper = char.toUpperCase();
      if (_letterPattern.hasMatch(upper)) return upper;
      // Numbers get their own bucket; anything else — punctuation, spaces,
      // scripts with no letter of their own — is skipped so a stray dash does
      // not decide the whole row.
      if (_digitPattern.hasMatch(char)) return '#';
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
