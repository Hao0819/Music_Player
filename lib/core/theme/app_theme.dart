import 'dart:math';

import 'package:flutter/material.dart';

/// One design language across light and dark, built on a single idea: **the
/// only colour in the app comes from the music.**
///
/// The surface ladder below is deliberately neutral — a graphite/paper grey
/// rather than the blue-tinted neutrals `ColorScheme.fromSeed` produces. That
/// is what lets a track's own artwork colour read as the accent instead of
/// competing with a tint baked into every surface. [signal] is only the
/// fallback for tracks with no artwork to sample.
///
/// Type is Archivo throughout, one superfamily whose width axis separates
/// display from UI, so there is no second typeface to keep in sync.
class AppTheme {
  AppTheme._();

  /// Fallback accent, used until a track's artwork supplies one.
  static const signal = Color(0xFF2F6BFF);

  /// The gradient for play buttons and pills, built from the sampled accent
  /// itself rather than from `scheme.primary`.
  ///
  /// Material 3 puts `primary` at a light tone in dark mode, which turns the
  /// main transport control into a pale pill with a dark glyph — correct by
  /// the spec, and a clear downgrade for the one button the whole screen is
  /// built around. [ArtworkPalette.toSeed] already clamps lightness to a mid
  /// band, so taking the accent directly keeps the button a solid, saturated
  /// chip with a light glyph in both modes.
  /// Hues that look muddy as a gradient's far end — the olive/chartreuse band
  /// between yellow and green.
  static const _mustyBand = (start: 55.0, end: 95.0);

  static bool _inMustyBand(double hue) => hue >= _mustyBand.start && hue <= _mustyBand.end;

  static LinearGradient accentGradient(Color base) {
    final glyph = onAccent(base);
    final hsl = HSLColor.fromColor(base);

    // A fixed +28° does not mean the same thing everywhere on the wheel. On
    // blue (223→251) it is a clean step into indigo; on a gold like #D9A227 it
    // lands at 69°, dragging the colour into olive — the folder card came out
    // visibly muddier than the swatch that produced it. So the step turns back
    // on itself rather than crossing that band, unless the base already sits
    // inside it and there is nowhere better to go.
    const step = 28.0;
    final forward = (hsl.hue + step) % 360;
    final hue = _inMustyBand(forward) && !_inMustyBand(hsl.hue)
        ? (hsl.hue - step + 360) % 360
        : forward;

    final far = hsl
        .withHue(hue)
        // A lightness step alone barely reads at these mid tones; it is the
        // chroma step that gives the gradient its edge.
        .withSaturation((hsl.saturation * 1.18).clamp(0.0, 1.0))
        .toColor();

    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [base, _ensureContrast(far, glyph)],
    );
  }

  /// Glyph colour for anything painted on [accentGradient] — whichever of
  /// light or dark actually measures better, rather than a luminance
  /// threshold. A mid-lightness yellow needs a dark glyph; a mid-lightness
  /// blue needs a light one, and both sit in the band the sampler produces.
  static Color onAccent(Color base) {
    const dark = Color(0xFF101114);
    return _contrast(base, Colors.white) >= _contrast(base, dark) ? Colors.white : dark;
  }

  /// Darkens or lightens [color] until [glyph] is legible on it.
  ///
  /// HSL lightness is not perceived brightness: rotating a red toward orange
  /// raises luminance sharply at the same lightness, which is exactly how the
  /// white glyph once landed at 2.5:1 on the far stop. Stepping until the
  /// ratio actually measures is the only version of this that holds for every
  /// hue a cover might produce.
  static Color _ensureContrast(Color color, Color glyph, {double target = 3.2}) {
    final towardDark = glyph.computeLuminance() > 0.5;
    var hsl = HSLColor.fromColor(color);
    var result = color;

    for (var i = 0; i < 40 && _contrast(result, glyph) < target; i++) {
      final next = (hsl.lightness + (towardDark ? -0.02 : 0.02)).clamp(0.0, 1.0);
      if (next == hsl.lightness) break; // Hit black or white; nothing more to give.
      hsl = hsl.withLightness(next);
      result = hsl.toColor();
    }
    return result;
  }

  static double _contrast(Color a, Color b) {
    final la = _relativeLuminance(a);
    final lb = _relativeLuminance(b);
    return (max(la, lb) + 0.05) / (min(la, lb) + 0.05);
  }

  static double _relativeLuminance(Color c) {
    double channel(double v) => v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4).toDouble();
    return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
  }

  /// The colours offered when picking a folder's colour.
  ///
  /// Ten hues walked round the wheel at a matched lightness and chroma, so no
  /// one swatch jumps out of the set. They sit in the same mid band
  /// [ArtworkPalette.toSeed] targets, which is what lets [accentGradient] and
  /// [onAccent] treat them exactly like a sampled cover colour.
  static const folderPalette = <Color>[
    Color(0xFF3B6FF2), // blue
    Color(0xFF1BBDB6), // teal
    Color(0xFF31B36A), // green
    Color(0xFF7CB342), // lime
    Color(0xFFD9A227), // amber
    Color(0xFFE0743A), // orange
    Color(0xFFDC4F5C), // red
    Color(0xFFD14A8E), // pink
    Color(0xFF8E57D6), // violet
    // The one low-chroma option. Its hue sits near blue's, but at a sixth of
    // the saturation it reads as grey, not as a second blue.
    Color(0xFF64748B), // slate
  ];

  /// A folder's base colour: the one that was picked, or failing that one
  /// derived from its name so a folder still arrives with some identity.
  static Color folderColor(String name, int? chosen) {
    if (chosen != null) return Color(chosen);
    return folderPalette[name.hashCode.abs() % folderPalette.length];
  }

  /// The gradient painted on a folder card, from that base colour.
  static LinearGradient folderGradient(String name, int? chosen) =>
      accentGradient(folderColor(name, chosen));

  /// Shared corner radii, so tiles, sheets and artwork agree.
  static const radiusSmall = 10.0;
  static const radiusMedium = 16.0;
  static const radiusLarge = 24.0;

  /// The display family. Only the Now Playing title uses it — the design
  /// spends its boldness in exactly one place.
  static const displayFamily = 'ArchivoExpanded';
  static const uiFamily = 'Archivo';

  /// CJK ideographs, kana, hangul and the CJK punctuation block.
  static final _cjk = RegExp(
    r'[　-〿぀-ヿ㐀-䶿一-鿿가-힯豈-﫿]',
  );

  /// Whether a string contains any CJK, which decides how [displayTitle] sets
  /// it.
  static bool hasCjk(String text) => _cjk.hasMatch(text);

  /// The Now Playing title's style, chosen from the text itself.
  ///
  /// Archivo carries no CJK, so a mixed title would otherwise set its ASCII
  /// brackets and hyphens in the bundled expanded cut while the ideographs
  /// fell back to the system face — two different weights and proportions on
  /// one line. A title with any CJK in it therefore goes to the system face
  /// whole, and loses the negative tracking with it: that tracking is drawn
  /// for wide latin display type and only crowds ideographs, which already
  /// sit on a fixed em.
  static TextStyle displayTitle(TextTheme text, String title) {
    // Long titles step down a size instead of ellipsing away half the name.
    final base = (title.length > 24 ? text.displaySmall : text.displayMedium)!;
    if (!hasCjk(title)) return base;

    return TextStyle(
      fontSize: base.fontSize,
      fontWeight: FontWeight.w700,
      height: 1.25,
      letterSpacing: 0,
      color: base.color,
    );
  }

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  /// Replaces the seed scheme's tinted neutrals with the flat graphite/paper
  /// ladder. Takes the accent roles from [scheme] untouched, so this is safe
  /// to re-run with an artwork-derived scheme.
  static ColorScheme neutralize(ColorScheme scheme) {
    final isDark = scheme.brightness == Brightness.dark;
    if (isDark) {
      return scheme.copyWith(
        // Material 3 tints raised and scrolled-under surfaces with `primary`.
        // That quietly undoes the neutral ladder below — the app bar came
        // back a pale blue-violet — so the tint is pinned to the surface it
        // sits on, which is the supported way to switch it off everywhere at
        // once rather than per component.
        surfaceTint: const Color(0xFF0E0F11),
        surface: const Color(0xFF0E0F11),
        surfaceContainerLowest: const Color(0xFF0A0B0C),
        surfaceContainerLow: const Color(0xFF141619),
        surfaceContainer: const Color(0xFF181A1D),
        surfaceContainerHigh: const Color(0xFF1E2124),
        surfaceContainerHighest: const Color(0xFF26292D),
        onSurface: const Color(0xFFE7E8EA),
        onSurfaceVariant: const Color(0xFFA8ACB2),
        outline: const Color(0xFF52575D),
        outlineVariant: const Color(0xFF2E3236),
      );
    }
    return scheme.copyWith(
      surfaceTint: const Color(0xFFF7F7F8),
      surface: const Color(0xFFF7F7F8),
      surfaceContainerLowest: const Color(0xFFFFFFFF),
      surfaceContainerLow: const Color(0xFFFFFFFF),
      surfaceContainer: const Color(0xFFF1F2F3),
      surfaceContainerHigh: const Color(0xFFEAEBED),
      surfaceContainerHighest: const Color(0xFFE3E5E7),
      onSurface: const Color(0xFF15171A),
      onSurfaceVariant: const Color(0xFF5C6167),
      outline: const Color(0xFF8A9096),
      outlineVariant: const Color(0xFFDEE0E3),
    );
  }

  /// The app's type scale. Sizes step at roughly 1.2 with a deliberate jump
  /// to the display line; weights and tracking are set explicitly because the
  /// bundled Archivo cuts are static, so nothing is inferred.
  static TextTheme textTheme(ColorScheme scheme) {
    TextStyle style(
      double size,
      FontWeight weight, {
      double? height,
      double tracking = 0,
      Color? color,
      String family = uiFamily,
    }) {
      return TextStyle(
        fontFamily: family,
        fontSize: size,
        fontWeight: weight,
        height: height,
        letterSpacing: tracking,
        color: color ?? scheme.onSurface,
      );
    }

    return TextTheme(
      // Reserved for the Now Playing title. Expanded and tightly tracked:
      // at this size the extra width reads as confidence, and the negative
      // tracking stops it falling apart into separate letters.
      displayLarge: style(40, FontWeight.w800, height: 1.04, tracking: -1.4, family: displayFamily),
      displayMedium: style(34, FontWeight.w800, height: 1.06, tracking: -1.1, family: displayFamily),
      displaySmall: style(27, FontWeight.w800, height: 1.1, tracking: -0.8, family: displayFamily),

      headlineLarge: style(26, FontWeight.w700, height: 1.15, tracking: -0.5),
      headlineMedium: style(24, FontWeight.w700, height: 1.18, tracking: -0.45),
      headlineSmall: style(22, FontWeight.w700, height: 1.2, tracking: -0.4),

      titleLarge: style(20, FontWeight.w700, height: 1.25, tracking: -0.3),
      titleMedium: style(16, FontWeight.w600, height: 1.3, tracking: -0.1),
      titleSmall: style(14, FontWeight.w600, height: 1.3),

      bodyLarge: style(15, FontWeight.w400, height: 1.45),
      bodyMedium: style(14, FontWeight.w400, height: 1.45, color: scheme.onSurfaceVariant),
      bodySmall: style(12.5, FontWeight.w400, height: 1.4, color: scheme.onSurfaceVariant),

      labelLarge: style(14, FontWeight.w600, height: 1.2),
      labelMedium: style(12, FontWeight.w500, height: 1.2, tracking: 0.1),
      // Durations and counts. Tabular figures are on in the bundled cuts, so
      // a ticking position does not shuffle the layout sideways.
      labelSmall: style(11, FontWeight.w500, height: 1.2, tracking: 0.2, color: scheme.onSurfaceVariant),
    );
  }

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    // "vibrant" keeps far more of the seed's chroma than the default tonal
    // scheme, which is what makes the accents actually read as colourful.
    // Even a blue seed leaves it with violet secondary tones, and those are
    // exactly the surfaces that read as purple: selected chips, the
    // navigation indicator, badges. Pin them back to the signal hue.
    final scheme = neutralize(
      ColorScheme.fromSeed(
        seedColor: signal,
        brightness: brightness,
        dynamicSchemeVariant: DynamicSchemeVariant.vibrant,
      ).copyWith(
        secondary: isDark ? const Color(0xFF9DC0FF) : const Color(0xFF2B5CB8),
        secondaryContainer: isDark ? const Color(0xFF17376B) : const Color(0xFFD7E3FF),
        onSecondaryContainer: isDark ? const Color(0xFFD7E3FF) : const Color(0xFF0B2C63),
      ),
    );

    return themeFor(scheme);
  }

  /// Builds the full theme for an arbitrary scheme, so the playing track's
  /// artwork-derived scheme gets the identical component styling rather than
  /// a hand-patched copy.
  static ThemeData themeFor(ColorScheme scheme) {
    final isDark = scheme.brightness == Brightness.dark;
    final text = textTheme(scheme);

    return ThemeData(
      useMaterial3: true,
      brightness: scheme.brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      fontFamily: uiFamily,
      textTheme: text,
      splashFactory: InkSparkle.splashFactory,

      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 2,
        centerTitle: false,
        titleTextStyle: text.headlineSmall,
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.secondaryContainer,
        elevation: 0,
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => text.labelMedium?.copyWith(
            fontWeight: states.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),

      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMedium)),
      ),

      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusSmall)),
        selectedTileColor: scheme.secondaryContainer.withValues(alpha: 0.5),
        titleTextStyle: text.titleMedium,
        subtitleTextStyle: text.bodySmall,
      ),

      searchBarTheme: SearchBarThemeData(
        elevation: const WidgetStatePropertyAll(0),
        backgroundColor: WidgetStatePropertyAll(scheme.surfaceContainerHigh),
        textStyle: WidgetStatePropertyAll(text.bodyLarge),
        hintStyle: WidgetStatePropertyAll(text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusLarge)),
        ),
        side: WidgetStatePropertyAll(BorderSide(color: scheme.outlineVariant)),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radiusLarge)),
        ),
      ),

      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusLarge)),
        titleTextStyle: text.titleLarge,
        contentTextStyle: text.bodyMedium,
      ),

      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusSmall)),
        side: BorderSide(color: scheme.outlineVariant),
        labelStyle: text.labelLarge,
      ),

      sliderTheme: SliderThemeData(
        trackHeight: 4,
        activeTrackColor: scheme.primary,
        inactiveTrackColor: scheme.surfaceContainerHighest,
        thumbColor: scheme.primary,
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
      ),

      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: isDark ? 0.6 : 1),
        space: 1,
        thickness: 1,
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusSmall)),
        contentTextStyle: text.bodyMedium?.copyWith(color: scheme.onInverseSurface),
      ),
    );
  }
}
