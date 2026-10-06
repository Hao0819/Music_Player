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

  /// The title with its leading `[...]` / `(...)` tags removed, and those tags
  /// on their own, in the order they appeared.
  ///
  /// Files pulled off YouTube arrive titled `[4K 60fps] 稻香 (Live)`. The tag is
  /// real information, but it is not the name of the song, and at the front of
  /// a row it eats exactly the width the name needs — so a list shows
  /// [displayTitle] and puts [tagLabel] down on the metadata line. Empty when
  /// the title has no tags, which is most of a normal library.
  late final String displayTitle = _splitLeadingTags(title).rest;
  late final String tagLabel = _splitLeadingTags(title).tags;

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

  /// Whether [other] describes the same file with the same metadata, so this
  /// instance's already-computed keys are still correct for it.
  ///
  /// Everything a row shows is compared, not just the path: reusing an
  /// instance whose title had changed would leave the list showing metadata
  /// the scan has already corrected.
  bool matches(Track other) =>
      id == other.id &&
      path == other.path &&
      title == other.title &&
      artist == other.artist &&
      album == other.album &&
      duration == other.duration &&
      format == other.format &&
      dateAdded == other.dateAdded;

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

  /// Derived strings cached by their source text rather than per track.
  ///
  /// Two things make this pay. Artists and albums repeat heavily — a folder
  /// of one artist is thirty rows holding the same two strings — and a rescan
  /// builds a fresh set of Track objects even for files that have not changed,
  /// discarding every key those instances had computed. Keying on the text
  /// means each distinct string is romanised once for the life of the process
  /// instead of once per row per scan.
  static final Map<String, ({String tags, String rest})> _splitTitles = {};
  static final Map<String, String> _sortKeys = {};
  static final Map<String, String> _indexLetters = {};

  /// Bounded so a pathological library cannot grow these without limit. The
  /// oldest entry goes first, and a miss only costs what it used to cost, so
  /// the eviction order does not need to be clever.
  static const _maxCachedKeys = 6000;

  static String _cached(Map<String, String> cache, String value, String Function() compute) {
    final hit = cache[value];
    if (hit != null) return hit;

    final computed = compute();
    if (cache.length >= _maxCachedKeys) cache.remove(cache.keys.first);
    return cache[value] = computed;
  }

  /// Strips leading `[...]` / `(...)` tags.
  ///
  /// Files pulled off YouTube arrive titled `[1080P] ...`, `( 歌詞 ) ...`,
  /// `[4K _ 60fps] ...`. Indexing on those puts most of a library under a
  /// single letter — and under '#', since they start with punctuation — which
  /// is the same as having no index at all.
  static String _withoutLeadingTags(String value) => _splitLeadingTags(value).rest;

  /// Splits a leading run of bracketed tags off the front of [value].
  ///
  /// Cached because both halves are read per row and the sort keys read the
  /// rest again; the walk is cheap but it is done for every track in the
  /// library on every sort.
  static ({String tags, String rest}) _splitLeadingTags(String value) {
    final hit = _splitTitles[value];
    if (hit != null) return hit;

    var rest = value.trimLeft();
    final tags = <String>[];

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

      final tag = rest.substring(1, end).trim();
      if (tag.isNotEmpty) tags.add(tag);
      rest = rest.substring(end + 1).trimLeft();
    }

    // A title that is nothing but a tag keeps its original text: dropping it
    // entirely would leave the row with no name and no sort position at all,
    // and then the tag is the only thing there is to call it.
    final result = rest.isEmpty
        ? (tags: '', rest: value.trimLeft())
        : (tags: tags.join(' · '), rest: rest);

    if (_splitTitles.length >= _maxCachedKeys) _splitTitles.remove(_splitTitles.keys.first);
    return _splitTitles[value] = result;
  }

  static String _sortKey(String value) => _cached(_sortKeys, value, () => _computeSortKey(value));

  static String _computeSortKey(String value) {
    final stripped = _withoutLeadingTags(value);
    if (!_han.hasMatch(stripped)) return stripped.toLowerCase();

    return PinyinHelper.getPinyinE(
      stripped,
      separator: ' ',
      format: PinyinFormat.WITHOUT_TONE,
    ).toLowerCase();
  }

  static String _indexLetterOf(String value) =>
      _cached(_indexLetters, value, () => _computeIndexLetter(value));

  static String _computeIndexLetter(String value) {
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
