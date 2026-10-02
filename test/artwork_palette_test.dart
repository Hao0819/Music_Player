import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:music_player/core/theme/artwork_palette.dart';

/// Builds a PNG the engine can decode, filled by a per-pixel callback.
Uint8List pngOf(int size, img.ColorRgb8 Function(int x, int y) pixel) {
  final image = img.Image(width: size, height: size);
  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      image.setPixel(x, y, pixel(x, y));
    }
  }
  return Uint8List.fromList(img.encodePng(image));
}

void main() {
  // instantiateImageCodec needs the engine, so the binding has to be up.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('dominantColor', () {
    test('finds the colour a person would name', () async {
      final red = img.ColorRgb8(200, 40, 50);
      final bytes = pngOf(64, (x, y) => red);

      final color = await ArtworkPalette.dominantColor(bytes);

      expect(color, isNotNull);
      final hue = HSLColor.fromColor(color!).hue;
      // Within a bucket's width of red; the histogram averages its winning
      // bucket, so this is not expected to come back exactly 200/40/50.
      expect(hue < 20 || hue > 340, isTrue, reason: 'expected a red hue, got $hue');
    });

    test('ignores the near-black majority of a dark cover', () async {
      // Nine tenths almost-black, one tenth saturated green. The green is
      // what the cover reads as, even though it is far from the most common
      // pixel value.
      final dark = img.ColorRgb8(8, 8, 10);
      final green = img.ColorRgb8(40, 190, 90);
      final bytes = pngOf(80, (x, y) => y >= 72 ? green : dark);

      final color = await ArtworkPalette.dominantColor(bytes);

      expect(color, isNotNull);
      final hue = HSLColor.fromColor(color!).hue;
      expect(hue, greaterThan(80));
      expect(hue, lessThan(180));
    });

    test('returns null for greyscale art rather than inventing an accent', () async {
      final bytes = pngOf(64, (x, y) {
        final v = (x * 4).clamp(0, 255);
        return img.ColorRgb8(v, v, v);
      });

      expect(await ArtworkPalette.dominantColor(bytes), isNull);
    });

    test('returns null for empty and undecodable bytes', () async {
      expect(await ArtworkPalette.dominantColor(Uint8List(0)), isNull);
      expect(
        await ArtworkPalette.dominantColor(Uint8List.fromList([1, 2, 3, 4, 5])),
        isNull,
      );
    });
  });

  group('toSeed', () {
    test('keeps the hue but pulls lightness into a usable band', () {
      const nearBlack = Color(0xFF1A0B2E); // very dark violet
      final seed = ArtworkPalette.toSeed(nearBlack);

      final before = HSLColor.fromColor(nearBlack);
      final after = HSLColor.fromColor(seed);

      expect(after.hue, closeTo(before.hue, 1.0));
      expect(after.lightness, greaterThanOrEqualTo(0.39));
      expect(after.lightness, lessThanOrEqualTo(0.63));
    });

    test('raises chroma on a washed-out sample', () {
      const pale = Color(0xFFBFC6CE);
      final after = HSLColor.fromColor(ArtworkPalette.toSeed(pale));

      expect(after.saturation, greaterThanOrEqualTo(0.44));
    });

    test('keeps an already-suitable colour vivid, short of neon', () {
      const good = Color(0xFF2F6BFF);
      final before = HSLColor.fromColor(good);
      final after = HSLColor.fromColor(ArtworkPalette.toSeed(good));

      expect(after.hue, closeTo(before.hue, 1.0));
      // The upper clamp exists so a fully saturated sample does not become an
      // eye-searing accent, so some chroma is expected to come off the top.
      // Tolerance covers the 8-bit round trip through Color and back.
      expect(after.saturation, closeTo(0.95, 0.01));
    });
  });
}
