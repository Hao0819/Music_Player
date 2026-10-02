import 'package:flutter_test/flutter_test.dart';

import 'package:music_player/domain/track.dart';

Track trackFromRow(Map<String, Object?> row) => Track.fromMediaStoreMap(row);

void main() {
  group('Track.fromMediaStoreMap', () {
    test('falls back to the file name when MediaStore has no title', () {
      final track = trackFromRow({
        'path': '/storage/emulated/0/Download/MusicDownload/my song.mp3',
        'title': null,
      });

      expect(track.title, 'my song');
    });

    test('treats <unknown> and blanks as unknown artist/album', () {
      final track = trackFromRow({
        'path': '/a/b.mp3',
        'artist': '<unknown>',
        'album': '   ',
      });

      expect(track.artist, 'Unknown artist');
      expect(track.album, 'Unknown album');
    });

    test('derives the format from the file extension', () {
      expect(trackFromRow({'path': '/a/b.FLAC'}).format, 'FLAC');
      expect(trackFromRow({'path': '/a/no-extension'}).format, '');
    });
  });

  String letterOf(String title) =>
      trackFromRow({'path': '/a.mp3', 'title': title}).indexLetter;

  group('indexLetter', () {
    test('uses the first letter of the title', () {
      expect(trackFromRow({'path': '/a.mp3', 'title': 'yesterday'}).indexLetter, 'Y');
    });

    test('groups numbers and symbol-only titles under #', () {
      expect(letterOf('99 problems'), '#');
      expect(letterOf('...'), '#');
      expect(letterOf('에스파'), '#', reason: 'hangul has no latin letter of its own');
    });

    test('romanises Han characters instead of dumping them in #', () {
      expect(letterOf('你好'), 'N');
      expect(letterOf('方大同 - 三人游'), 'F');
      expect(letterOf('好歌分享_徐佳瑩'), 'H');
    });

    test('handles traditional as well as simplified', () {
      expect(letterOf('專屬天使'), 'Z');
      expect(letterOf('鄧紫棋'), 'D');
      expect(letterOf('一樣的月光'), 'Y');
      expect(letterOf('爱我吧'), 'A');
    });

    test('skips leading bracket tags', () {
      // Files pulled off YouTube arrive wearing these, and they would
      // otherwise put most of a library under '#'.
      expect(letterOf('[1080P] G.E.M.鄧紫棋'), 'G');
      expect(letterOf('( 歌詞 ) TANK - 專屬天使'), 'T');
      expect(letterOf('[12.06.12] 方大同 孤獨患者'), 'F');
      expect(letterOf('[avex官方] A-Lin'), 'A');
      expect(letterOf('【中文字幕】某首歌'), 'M');
      expect(letterOf('[4K _ 60fps] NINGNING'), 'N');
    });

    test('keeps the tag when it is the whole title', () {
      // Stripping everything would leave the row with no sort position, so the
      // original text comes back — and the bracket is then skipped as ordinary
      // punctuation, which lands somewhere more useful than '#'.
      expect(letterOf('[Unreleased]'), 'U');
      expect(letterOf('( 歌詞 )'), 'G');
    });

    test('ignores leading punctuation rather than bucketing on it', () {
      expect(letterOf('- 方大同'), 'F');
      expect(letterOf('  Shawn Mendes'), 'S');
    });

    test('the per-field letters each read their own field', () {
      final track = trackFromRow({
        'path': '/a.mp3',
        'title': '專屬天使',
        'artist': '方大同',
        'album': 'Great Hits',
      });
      expect(track.indexLetter, 'Z');
      expect(track.artistIndexLetter, 'F');
      expect(track.albumIndexLetter, 'G');
    });

    test('sort keys romanise so Chinese orders the way it reads', () {
      // By code point these would sort in an order nobody reads in.
      final keys = ['鄧紫棋', '方大同', '一樣的月光', '曾沛慈']
          .map((t) => trackFromRow({'path': '/a.mp3', 'title': t}).titleKey)
          .toList();
      final sorted = [...keys]..sort();
      expect(sorted.first, startsWith('ceng'));
      expect(sorted.last, startsWith('yi'));
    });

    test('latin sort keys are untouched', () {
      expect(trackFromRow({'path': '/a.mp3', 'title': 'Stitches'}).titleKey, 'stitches');
    });
  });
}
