import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:music_player/core/theme/app_theme.dart';
import 'package:music_player/core/theme/artwork_palette.dart';
import 'package:music_player/features/player/providers/artwork_theme_provider.dart';

void main() {
  test('light and dark themes build with the expected brightness', () {
    expect(AppTheme.light().brightness, Brightness.light);
    expect(AppTheme.dark().brightness, Brightness.dark);
  });

  group('typography', () {
    test('sets the bundled families rather than falling back to Roboto', () {
      final text = AppTheme.dark().textTheme;

      // The display face is the only place the expanded cut appears; the rest
      // of the app is the UI width.
      expect(text.displayMedium?.fontFamily, AppTheme.displayFamily);
      expect(text.displaySmall?.fontFamily, AppTheme.displayFamily);
      expect(text.titleMedium?.fontFamily, AppTheme.uiFamily);
      expect(text.bodyMedium?.fontFamily, AppTheme.uiFamily);
      expect(text.labelSmall?.fontFamily, AppTheme.uiFamily);
    });

    test('every style declares a weight the pubspec actually bundles', () {
      // Asking for a weight with no asset behind it makes the engine
      // synthesise a fake bold, which looks nothing like the real cut.
      final bundledUi = <FontWeight>{
        FontWeight.w400,
        FontWeight.w500,
        FontWeight.w600,
        FontWeight.w700,
      };
      final bundledDisplay = <FontWeight>{FontWeight.w800};

      final text = AppTheme.dark().textTheme;
      final styles = <String, TextStyle?>{
        'displayLarge': text.displayLarge,
        'displayMedium': text.displayMedium,
        'displaySmall': text.displaySmall,
        'headlineLarge': text.headlineLarge,
        'headlineMedium': text.headlineMedium,
        'headlineSmall': text.headlineSmall,
        'titleLarge': text.titleLarge,
        'titleMedium': text.titleMedium,
        'titleSmall': text.titleSmall,
        'bodyLarge': text.bodyLarge,
        'bodyMedium': text.bodyMedium,
        'bodySmall': text.bodySmall,
        'labelLarge': text.labelLarge,
        'labelMedium': text.labelMedium,
        'labelSmall': text.labelSmall,
      };

      for (final entry in styles.entries) {
        final style = entry.value;
        expect(style, isNotNull, reason: '${entry.key} is unset');
        final allowed =
            style!.fontFamily == AppTheme.displayFamily ? bundledDisplay : bundledUi;
        expect(
          allowed,
          contains(style.fontWeight),
          reason: '${entry.key} wants ${style.fontWeight} from ${style.fontFamily}',
        );
      }
    });
  });

  group('surfaces', () {
    test('are neutral, so a track accent is the only colour on screen', () {
      for (final theme in [AppTheme.light(), AppTheme.dark()]) {
        final surface = HSLColor.fromColor(theme.colorScheme.surface);
        expect(
          surface.saturation,
          lessThan(0.12),
          reason: 'surface carries a tint that would compete with the artwork',
        );
      }
    });

    test('do not let the M3 surface tint repaint chrome in the accent', () {
      // An app bar scrolled under tints itself with surfaceTint; left at the
      // default that is `primary`, which turned the whole header blue-violet
      // and undid the neutral ladder.
      for (final theme in [AppTheme.light(), AppTheme.dark()]) {
        expect(theme.colorScheme.surfaceTint, theme.colorScheme.surface);
      }
      for (final accent in [const Color(0xFFD1427A), const Color(0xFF17876B)]) {
        for (final brightness in Brightness.values) {
          final scheme = themeForAccent(accent, brightness).colorScheme;
          expect(scheme.surfaceTint, scheme.surface);
        }
      }
    });

    test('keep onSurface readable against surface in both modes', () {
      for (final theme in [AppTheme.light(), AppTheme.dark()]) {
        final scheme = theme.colorScheme;
        final contrast = _contrastRatio(scheme.onSurface, scheme.surface);
        expect(contrast, greaterThan(4.5), reason: 'body text fails WCAG AA');

        final variant = _contrastRatio(scheme.onSurfaceVariant, scheme.surface);
        expect(variant, greaterThan(4.5), reason: 'secondary text fails WCAG AA');
      }
    });
  });

  group('themeForAccent', () {
    test('keeps the sampled hue as the scheme primary', () {
      const accent = Color(0xFFD1427A); // magenta
      final scheme = themeForAccent(accent, Brightness.dark).colorScheme;

      final want = HSLColor.fromColor(accent).hue;
      final got = HSLColor.fromColor(scheme.primary).hue;
      // Material's tonal mapping moves the hue a little; it should still be
      // recognisably the same colour family.
      expect((got - want).abs(), lessThan(30), reason: 'primary drifted to $got from $want');
    });

    test('falls back to the signal blue when a track has no artwork', () {
      final scheme = themeForAccent(null, Brightness.dark).colorScheme;
      final signalHue = HSLColor.fromColor(AppTheme.signal).hue;
      final got = HSLColor.fromColor(scheme.primary).hue;

      expect((got - signalHue).abs(), lessThan(30));
    });

    test('still neutralises surfaces for an accent-derived theme', () {
      final scheme = themeForAccent(const Color(0xFFC2611B), Brightness.dark).colorScheme;
      expect(scheme.surface, AppTheme.dark().colorScheme.surface);
    });

    test('play-button glyph stays legible across the accent gradient', () {
      // The gradient runs from the sampled accent to a hue-shifted, deeper
      // neighbour, and the glyph is drawn in onAccent over both ends. Hues
      // are walked right round the wheel because the accent is whatever the
      // cover happened to be — yellow is the one that caught this before.
      for (var hue = 0; hue < 360; hue += 15) {
        for (final lightness in [0.40, 0.50, 0.62]) {
          final accent = ArtworkPalette.toSeed(
            HSLColor.fromAHSL(1, hue.toDouble(), 0.8, lightness).toColor(),
          );
          final glyph = AppTheme.onAccent(accent);

          for (final stop in AppTheme.accentGradient(accent).colors) {
            expect(
              _contrastRatio(glyph, stop),
              greaterThan(3.0),
              reason: 'glyph on $stop (hue $hue, lightness $lightness)',
            );
          }
        }
      }
    });
  });

  group('folder colours', () {
    test('a chosen colour wins over the one derived from the name', () {
      const picked = Color(0xFF8E57D6);
      expect(AppTheme.folderColor('Road trip', picked.toARGB32()), picked);
    });

    test('fall back to a stable colour derived from the name', () {
      expect(AppTheme.folderColor('Road trip', null), AppTheme.folderColor('Road trip', null));
      expect(AppTheme.folderPalette, contains(AppTheme.folderColor('Road trip', null)));
    });

    test('renaming changes the derived colour but not a chosen one', () {
      // The derived colour is a function of the name, so it moving on rename
      // is expected; a colour the user picked must not.
      const picked = Color(0xFF2A9D5C);
      expect(
        AppTheme.folderColor('Gym', picked.toARGB32()),
        AppTheme.folderColor('Gym renamed', picked.toARGB32()),
      );
    });

    test('the palette is spread round the wheel, not variations of one hue', () {
      expect(AppTheme.folderPalette.length, 10);

      // Hue spacing is only meaningful between saturated swatches. The slate
      // option shares a hue with blue and is still unmistakable, because
      // chroma separates them — so it is checked on chroma instead, below.
      final hues = AppTheme.folderPalette
          .where((c) => HSLColor.fromColor(c).saturation > 0.4)
          .map((c) => HSLColor.fromColor(c).hue)
          .toList()
        ..sort();
      expect(hues.last - hues.first, greaterThan(180));
      for (var i = 1; i < hues.length; i++) {
        expect(hues[i] - hues[i - 1], greaterThan(15), reason: 'hues $i and ${i - 1} collide');
      }
    });

    test('no two swatches are hard to tell apart', () {
      // Two colours are distinguishable if they differ in hue OR in chroma.
      // Checking only hue would reject slate, which shares blue's hue and is
      // obviously different; checking RGB distance would reject amber/orange,
      // which are obviously different but sit close in RGB because that space
      // is not perceptually uniform.
      final p = AppTheme.folderPalette.map(HSLColor.fromColor).toList();
      for (var i = 0; i < p.length; i++) {
        for (var j = i + 1; j < p.length; j++) {
          final raw = (p[i].hue - p[j].hue).abs();
          final hueGap = raw > 180 ? 360 - raw : raw;
          final chromaGap = (p[i].saturation - p[j].saturation).abs();
          expect(
            hueGap > 15 || chromaGap > 0.3,
            isTrue,
            reason: 'swatches $i and $j differ by only $hueGap° and $chromaGap chroma',
          );
        }
      }
    });

    test('no swatch produces a muddy olive far end', () {
      // A gold base used to step +28 into chartreuse, so the card read as
      // olive while the swatch that made it read as gold.
      for (final color in AppTheme.folderPalette) {
        final hsl = HSLColor.fromColor(color);
        for (final stop in AppTheme.accentGradient(color).colors) {
          final hue = HSLColor.fromColor(stop).hue;
          final isMusty = hue >= 55 && hue <= 95;
          // Only tolerated when the base itself lives there.
          final baseIsMusty = hsl.hue >= 55 && hsl.hue <= 95;
          expect(isMusty && !baseIsMusty, isFalse, reason: '$color drifted to hue $hue');
        }
      }
    });

    test('every swatch is legible with its own glyph colour', () {
      for (final color in AppTheme.folderPalette) {
        final glyph = AppTheme.onAccent(color);
        for (final stop in AppTheme.accentGradient(color).colors) {
          expect(_contrastRatio(glyph, stop), greaterThan(3.0), reason: 'glyph on $stop');
        }
      }
    });

    test('swatches sit in the mid band, so none jumps out of the set', () {
      for (final color in AppTheme.folderPalette) {
        final hsl = HSLColor.fromColor(color);
        expect(hsl.lightness, inInclusiveRange(0.38, 0.62), reason: '$color lightness');
        expect(hsl.saturation, inInclusiveRange(0.15, 0.95), reason: '$color saturation');
      }
    });
  });

  group('displayTitle', () {
    final text = AppTheme.dark().textTheme;

    test('sets a latin title in the bundled expanded cut', () {
      final style = AppTheme.displayTitle(text, 'Breathe');

      expect(style.fontFamily, AppTheme.displayFamily);
      expect(style.letterSpacing, lessThan(0));
    });

    test('hands a CJK title to the system face, whole', () {
      // Mixed script is the case that matters: the ASCII brackets and hyphen
      // would otherwise be set in Archivo while the ideographs fell back.
      final style = AppTheme.displayTitle(text, '( 歌詞 ) 田馥甄 - 你就不要想起我');

      expect(style.fontFamily, isNull);
      expect(style.letterSpacing, 0, reason: 'negative tracking crowds ideographs');
    });

    test('detects kana and hangul too, not just han', () {
      expect(AppTheme.hasCjk('secret base ~君がくれたもの~'), isTrue);
      expect(AppTheme.hasCjk('아무노래'), isTrue);
      expect(AppTheme.hasCjk('Nothing but latin'), isFalse);
    });

    test('steps a long title down a size in either script', () {
      final shortLatin = AppTheme.displayTitle(text, 'Breathe');
      final longLatin = AppTheme.displayTitle(
        text,
        'A Perfectly Reasonable Song Title That Runs Long',
      );
      expect(longLatin.fontSize, lessThan(shortLatin.fontSize!));

      final longCjk = AppTheme.displayTitle(text, '一' * 40);
      expect(longCjk.fontSize, text.displaySmall!.fontSize);
    });
  });
}

/// WCAG relative-luminance contrast ratio.
double _contrastRatio(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

double _luminance(Color c) {
  double channel(double v) => v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}
