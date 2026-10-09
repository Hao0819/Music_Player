import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:music_player/widgets/fallback_cover.dart';

void main() {
  group('fallbackCoverAssets', () {
    test('every listed picture is actually on disk', () {
      // The list is maintained by hand, and a path that no longer exists only
      // shows up as a broken box at runtime, on the one screen that is
      // hardest to notice it on.
      for (final asset in fallbackCoverAssets) {
        expect(File(asset).existsSync(), isTrue, reason: '$asset is missing');
      }
    });

    test('is declared as a bundled asset', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec, contains('assets/covers/'));
    });
  });

  group('fallbackCoverAsset', () {
    test('gives one track the same picture every time', () {
      expect(fallbackCoverAsset(1234), fallbackCoverAsset(1234));
    });

    test('spreads consecutive ids over the whole set', () {
      final picked = {
        for (var id = 0; id < fallbackCoverAssets.length; id++) fallbackCoverAsset(id),
      };
      expect(picked, hasLength(fallbackCoverAssets.length));
    });

    test('survives a negative id', () {
      // MediaStore ids are positive, but nothing in the type says so, and a
      // negative modulo would index off the front of the list.
      expect(fallbackCoverAssets, contains(fallbackCoverAsset(-7)));
    });
  });
}
