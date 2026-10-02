import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Pulls a usable accent colour out of a piece of cover art.
///
/// Hand-rolled rather than taken from `palette_generator`, which is
/// discontinued. It is also cheaper: the image is decoded straight to a 32×32
/// thumbnail by the codec, so the histogram below runs over ~1 000 pixels
/// instead of a full-size bitmap, and no k-means pass is needed.
class ArtworkPalette {
  ArtworkPalette._();

  /// Side length the codec decodes to. Small enough that the scan is free,
  /// large enough that a small logo in one corner cannot outvote the body of
  /// the image.
  static const _sampleSize = 32;

  /// Buckets per RGB channel. Six is coarse on purpose — finer buckets split
  /// a single gradient-ish cover across neighbours and no bucket wins.
  static const _bucketsPerChannel = 6;

  /// Returns the dominant *interesting* colour, or null when the art is
  /// effectively greyscale and any accent would be invented rather than
  /// sampled.
  static Future<Color?> dominantColor(Uint8List bytes) async {
    if (bytes.isEmpty) return null;

    final ui.Image image;
    try {
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: _sampleSize,
        targetHeight: _sampleSize,
      );
      final frame = await codec.getNextFrame();
      image = frame.image;
      codec.dispose();
    } on Exception {
      // Covers embedded art that is not a format the engine can decode.
      return null;
    }

    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    if (data == null) return null;

    final pixels = data.buffer.asUint8List();
    // Weight per bucket, plus running colour sums so the winner can be
    // averaged back to a real colour instead of snapping to a bucket centre.
    final weights = <int, double>{};
    final sums = <int, List<int>>{};

    for (var i = 0; i + 3 < pixels.length; i += 4) {
      final a = pixels[i + 3];
      if (a < 128) continue; // Transparent padding is not part of the art.

      final r = pixels[i];
      final g = pixels[i + 1];
      final b = pixels[i + 2];

      final hsl = HSLColor.fromColor(Color.fromARGB(255, r, g, b));
      // Near-black and near-white pixels are the bulk of most covers and tell
      // us nothing about its colour, so they are excluded rather than merely
      // down-weighted — otherwise a dark cover's accent is always "dark grey".
      if (hsl.lightness < 0.12 || hsl.lightness > 0.93) continue;
      if (hsl.saturation < 0.15) continue;

      // Favour saturated, mid-lightness pixels: those are what a person would
      // point at if asked what colour the cover is.
      final weight = hsl.saturation * (1 - (hsl.lightness - 0.5).abs());

      final key = (r * _bucketsPerChannel ~/ 256) * _bucketsPerChannel * _bucketsPerChannel +
          (g * _bucketsPerChannel ~/ 256) * _bucketsPerChannel +
          (b * _bucketsPerChannel ~/ 256);

      weights[key] = (weights[key] ?? 0) + weight;
      final sum = sums[key] ??= [0, 0, 0, 0];
      sum[0] += r;
      sum[1] += g;
      sum[2] += b;
      sum[3] += 1;
    }

    if (weights.isEmpty) return null;

    var bestKey = weights.keys.first;
    var bestWeight = 0.0;
    for (final entry in weights.entries) {
      if (entry.value > bestWeight) {
        bestWeight = entry.value;
        bestKey = entry.key;
      }
    }

    final sum = sums[bestKey]!;
    final count = sum[3];
    return Color.fromARGB(255, sum[0] ~/ count, sum[1] ~/ count, sum[2] ~/ count);
  }

  /// Nudges a sampled colour into a range that works as a Material seed.
  ///
  /// A seed that is very dark, very pale or nearly grey produces a scheme with
  /// no usable accent at all, so the hue is kept and only chroma and lightness
  /// are corrected — the result still reads as "this cover's colour".
  static Color toSeed(Color sampled) {
    final hsl = HSLColor.fromColor(sampled);
    return hsl
        .withSaturation(hsl.saturation.clamp(0.45, 0.95))
        .withLightness(hsl.lightness.clamp(0.40, 0.62))
        .toColor();
  }
}
