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

  group('indexLetter', () {
    test('uses the first letter of the title', () {
      expect(trackFromRow({'path': '/a.mp3', 'title': 'yesterday'}).indexLetter, 'Y');
    });

    test('groups anything not starting with a letter under #', () {
      expect(trackFromRow({'path': '/a.mp3', 'title': '99 problems'}).indexLetter, '#');
      expect(trackFromRow({'path': '/a.mp3', 'title': '你好'}).indexLetter, '#');
    });
  });
}
