import 'dart:math';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:music_player/core/theme/app_theme.dart';

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
    test('carry at most a trace of hue, so album art is the only colour', () {
      // Measured as the spread between the RGB channels rather than as HSL
      // saturation. For a near-black surface HSL inflates saturation past 0.2
      // for a difference of ten values out of 255, which is invisible, so that
      // reading fails a ground the eye reads as neutral.
      for (final theme in [AppTheme.light(), AppTheme.dark()]) {
        final surface = theme.colorScheme.surface;
        final channels = [surface.r, surface.g, surface.b];
        final spread = channels.reduce(math.max) - channels.reduce(math.min);

        expect(
          spread,
          lessThan(0.06),
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

  // The 'themeForAccent' and 'theme caching' groups lived here, covering a
  // theme derived from the playing track's artwork. That feature is gone: the
  // app is black and white, and a disc that took its colour from the current
  // cover was the only coloured control on the screen.

  group('chrome colours', () {
    test('every role is neutral, so album art is the only colour anywhere', () {
      // Every field, not a sample of them. A shortlist is what let
      // primaryContainer stay coloured while the palette was supposedly gone,
      // and it surfaced as a tinted icon tile at the top of Playlists.
      for (final theme in [AppTheme.light(), AppTheme.dark()]) {
        final scheme = theme.colorScheme;
        final roles = {
          'primary': scheme.primary,
          'onPrimary': scheme.onPrimary,
          'primaryContainer': scheme.primaryContainer,
          'onPrimaryContainer': scheme.onPrimaryContainer,
          'primaryFixed': scheme.primaryFixed,
          'primaryFixedDim': scheme.primaryFixedDim,
          'onPrimaryFixed': scheme.onPrimaryFixed,
          'onPrimaryFixedVariant': scheme.onPrimaryFixedVariant,
          'secondary': scheme.secondary,
          'onSecondary': scheme.onSecondary,
          'secondaryContainer': scheme.secondaryContainer,
          'onSecondaryContainer': scheme.onSecondaryContainer,
          'secondaryFixed': scheme.secondaryFixed,
          'secondaryFixedDim': scheme.secondaryFixedDim,
          'onSecondaryFixed': scheme.onSecondaryFixed,
          'onSecondaryFixedVariant': scheme.onSecondaryFixedVariant,
          'tertiary': scheme.tertiary,
          'onTertiary': scheme.onTertiary,
          'tertiaryContainer': scheme.tertiaryContainer,
          'onTertiaryContainer': scheme.onTertiaryContainer,
          'tertiaryFixed': scheme.tertiaryFixed,
          'tertiaryFixedDim': scheme.tertiaryFixedDim,
          'onTertiaryFixed': scheme.onTertiaryFixed,
          'onTertiaryFixedVariant': scheme.onTertiaryFixedVariant,
          'error': scheme.error,
          'onError': scheme.onError,
          'errorContainer': scheme.errorContainer,
          'onErrorContainer': scheme.onErrorContainer,
          'surface': scheme.surface,
          'surfaceDim': scheme.surfaceDim,
          'surfaceBright': scheme.surfaceBright,
          'surfaceTint': scheme.surfaceTint,
          'surfaceContainerLowest': scheme.surfaceContainerLowest,
          'surfaceContainerLow': scheme.surfaceContainerLow,
          'surfaceContainer': scheme.surfaceContainer,
          'surfaceContainerHigh': scheme.surfaceContainerHigh,
          'surfaceContainerHighest': scheme.surfaceContainerHighest,
          'onSurface': scheme.onSurface,
          'onSurfaceVariant': scheme.onSurfaceVariant,
          'outline': scheme.outline,
          'outlineVariant': scheme.outlineVariant,
          'inverseSurface': scheme.inverseSurface,
          'onInverseSurface': scheme.onInverseSurface,
          'inversePrimary': scheme.inversePrimary,
          'shadow': scheme.shadow,
          'scrim': scheme.scrim,
        };

        for (final role in roles.entries) {
          final channels = [role.value.r, role.value.g, role.value.b];
          expect(
            channels.reduce(math.max) - channels.reduce(math.min),
            lessThan(0.06),
            reason: '${role.key} carries a hue in ${scheme.brightness.name}',
          );
        }
      }
    });

    test('selected chip text is readable on its container', () {
      for (final theme in [AppTheme.light(), AppTheme.dark()]) {
        final scheme = theme.colorScheme;
        expect(
          _contrastRatio(scheme.onSecondaryContainer, scheme.secondaryContainer),
          greaterThanOrEqualTo(4.5),
        );
        expect(_contrastRatio(scheme.onPrimary, scheme.primary), greaterThanOrEqualTo(4.5));
      }
    });
  });

  // The 'folder ink' and 'folder colours' groups lived here. They checked a
  // per-folder palette, its legibility as text and the spread of its hues.
  // The app is black and white now: there is no palette to check, and a
  // playlist is identified by its cover instead of by a colour.

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
