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

  /// The one colour in this app that means something: what is playing, what is
  /// selected, and the single primary action on a screen. Nothing decorative
  /// gets it — that restraint is the whole reason it reads as a signal.
  ///
  /// It is also the accent the chrome is built from, and the fallback until a
  /// track's artwork supplies one of its own.
  ///
  /// Emphasis is **ink, not colour**: the far end of the greyscale from
  /// whatever it is drawn on.
  ///
  /// So the primary button is black-on-paper in light mode and white-on-ink in
  /// dark mode, and it inverts rather than tinting. This replaced an accent
  /// colour — first a chartreuse, then a green — and both had the same
  /// problem: once a hue exists, every selected thing wants to wear it, and
  /// the screen ends up highlighted rather than ordered. With no hue in the
  /// palette at all, contrast is the only tool left, which is what makes the
  /// hierarchy read.
  ///
  /// Hue survives in exactly two places, both of them content rather than
  /// chrome: a folder's own colour, which the user picks, and album art.
  static const signalDark = Color(0xFFFFFFFF);
  static const signalLight = Color(0xFF121212);

  static Color signalFor(Brightness brightness) =>
      brightness == Brightness.dark ? signalDark : signalLight;

  // The folder palette, folderColor, folderInk and folderGradient all lived
  // here. They are gone: the app draws in black and white only, so a folder
  // has no colour to be assigned and nothing to tint. A playlist is told apart
  // by its cover, which is the one place an image's own colour belongs.

  static const radiusSmall = 12.0;
  static const radiusMedium = 20.0;
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

  // Built once, lazily. `_build` runs a full `ColorScheme.fromSeed` — an HCT
  // colour-space pass that generates every tonal palette — and then assembles
  // a ThemeData carrying fifteen text styles and a dozen component themes.
  // These were being rebuilt on every `MaterialApp` build, so switching
  // appearance paid for both of them at the exact moment it was animating.
  static final ThemeData _light = _build(Brightness.light);
  static final ThemeData _dark = _build(Brightness.dark);

  static ThemeData light() => _light;
  static ThemeData dark() => _dark;

  /// Replaces the seed scheme's tinted neutrals with the flat graphite/paper
  /// ladder. Takes the accent roles from [scheme] untouched, so this is safe
  /// to re-run with an artwork-derived scheme.
  static ColorScheme neutralize(ColorScheme scheme) {
    final isDark = scheme.brightness == Brightness.dark;

    // Every accent family, pinned flat. Material derives primaryContainer,
    // tertiary, error and the fixed variants from the seed, and those come out
    // coloured no matter what the seed is — which is how the three rows at the
    // top of Playlists kept a tinted icon tile long after the palette was
    // supposed to be gone. Anything left to Material is a colour waiting to
    // appear in a corner nobody looked at.
    final ink = isDark ? const Color(0xFFFFFFFF) : const Color(0xFF121212);
    final ground = isDark ? const Color(0xFF121212) : const Color(0xFFFFFFFF);
    final container = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE7E7E7);
    final onContainer = isDark ? const Color(0xFFFFFFFF) : const Color(0xFF121212);

    scheme = scheme.copyWith(
      primary: ink,
      onPrimary: ground,
      primaryContainer: container,
      onPrimaryContainer: onContainer,
      primaryFixed: container,
      primaryFixedDim: container,
      onPrimaryFixed: onContainer,
      onPrimaryFixedVariant: onContainer,
      secondary: ink,
      onSecondary: ground,
      secondaryContainer: container,
      onSecondaryContainer: onContainer,
      secondaryFixed: container,
      secondaryFixedDim: container,
      onSecondaryFixed: onContainer,
      onSecondaryFixedVariant: onContainer,
      tertiary: ink,
      onTertiary: ground,
      tertiaryContainer: container,
      onTertiaryContainer: onContainer,
      tertiaryFixed: container,
      tertiaryFixedDim: container,
      onTertiaryFixed: onContainer,
      onTertiaryFixedVariant: onContainer,
      // Errors included. A red would be the one hue left in the app, and this
      // app's errors are sentences — "3 tracks can't be found" — that say what
      // is wrong without needing a colour to carry it.
      error: ink,
      onError: ground,
      errorContainer: container,
      onErrorContainer: onContainer,
      inverseSurface: ink,
      onInverseSurface: ground,
      inversePrimary: ground,
      // The two surfaces Material derives rather than taking from the ladder.
      surfaceDim: isDark ? const Color(0xFF0D0D0D) : const Color(0xFFDEDEDE),
      surfaceBright: isDark ? const Color(0xFF333333) : const Color(0xFFFFFFFF),
      shadow: const Color(0xFF000000),
      scrim: const Color(0xFF000000),
    );

    if (isDark) {
      return scheme.copyWith(
        // Material 3 tints raised and scrolled-under surfaces with `primary`.
        // That quietly undoes the neutral ladder below — the app bar came
        // back a pale blue-violet — so the tint is pinned to the surface it
        // sits on, which is the supported way to switch it off everywhere at
        // once rather than per component.
        // Dead neutral: every channel equal, at every step. The reference this
        // is drawn from uses a faintly blue black, and an earlier pass copied
        // it — but "black and white only" means the ground has no hue either,
        // and on a real screen the difference is a few values out of 255.
        surfaceTint: const Color(0xFF121212),
        surface: const Color(0xFF121212),
        surfaceContainerLowest: const Color(0xFF000000),
        surfaceContainerLow: const Color(0xFF1A1A1A),
        surfaceContainer: const Color(0xFF212121),
        surfaceContainerHigh: const Color(0xFF2A2A2A),
        surfaceContainerHighest: const Color(0xFF333333),
        onSurface: const Color(0xFFFFFFFF),
        onSurfaceVariant: const Color(0xFFA0A0A0),
        outline: const Color(0xFF6E6E6E),
        outlineVariant: const Color(0xFF2E2E2E),
      );
    }
    return scheme.copyWith(
      surfaceTint: const Color(0xFFF8F8F8),
      surface: const Color(0xFFF8F8F8),
      surfaceContainerLowest: const Color(0xFFFFFFFF),
      surfaceContainerLow: const Color(0xFFFFFFFF),
      surfaceContainer: const Color(0xFFF0F0F0),
      surfaceContainerHigh: const Color(0xFFE7E7E7),
      surfaceContainerHighest: const Color(0xFFDEDEDE),
      onSurface: const Color(0xFF121212),
      onSurfaceVariant: const Color(0xFF606060),
      outline: const Color(0xFF8E8E8E),
      outlineVariant: const Color(0xFFE0E0E0),
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
    // scheme, which is what makes the accents actually read as colourful. It
    // also drifts the secondary roles off the seed's hue, and those are
    // exactly the surfaces you notice: selected chips, the navigation
    // indicator, badges. So they are pinned back onto the seed.
    //
    // Derived rather than written out as hex. They used to be hand-picked
    // blues, which meant they kept their old hue when the seed changed and
    // left the chrome looking like the previous palette.
    final signal = signalFor(brightness);

    final scheme = neutralize(
      ColorScheme.fromSeed(
        seedColor: signal,
        brightness: brightness,
        dynamicSchemeVariant: DynamicSchemeVariant.vibrant,
      ).copyWith(
        // Emphasis is the far end of the greyscale, and what sits on it is the
        // ground it came from. Material would otherwise derive a tinted
        // relative of the seed for both, which is the one thing this palette
        // does not allow.
        primary: signal,
        onPrimary: isDark ? const Color(0xFF121212) : const Color(0xFFFFFFFF),
        secondary: signal,
        onSecondary: isDark ? const Color(0xFF121212) : const Color(0xFFFFFFFF),
        secondaryContainer: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE7E7E7),
        onSecondaryContainer: isDark ? const Color(0xFFFFFFFF) : const Color(0xFF121212),
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
        // No capsule, and selection is drawn in full-strength ink rather than
        // in the accent. The accent belongs to one thing — starting playback —
        // and spending it on "which tab am I on" is what made every screen
        // look highlighted.
        indicatorColor: Colors.transparent,
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 22,
            color: states.contains(WidgetState.selected) ? scheme.onSurface : scheme.onSurfaceVariant,
          ),
        ),
        elevation: 0,
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => text.labelMedium?.copyWith(
            fontWeight: states.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w500,
            color: states.contains(WidgetState.selected) ? scheme.onSurface : scheme.onSurfaceVariant,
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

      // A filled block with soft corners, not a capsule and not a bare rule.
      // The capsule is the most recognisable Material default on a screen; the
      // rule, which this briefly was, disappeared into the app bar and left
      // the field looking unfinished.
      searchBarTheme: SearchBarThemeData(
        elevation: const WidgetStatePropertyAll(0),
        backgroundColor: WidgetStatePropertyAll(scheme.surfaceContainer),
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        textStyle: WidgetStatePropertyAll(text.bodyMedium),
        hintStyle: WidgetStatePropertyAll(
          text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusSmall)),
        ),
        side: const WidgetStatePropertyAll(BorderSide.none),
        padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 12)),
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

      // Filled and quiet when off, inverted when on. An outlined pill reads as
      // a button you have not pressed yet; these are a state, and the selected
      // one should be obvious without colour doing the work.
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusSmall)),
        side: BorderSide.none,
        backgroundColor: scheme.surfaceContainerHigh,
        selectedColor: scheme.onSurface,
        labelStyle: text.labelLarge?.copyWith(color: scheme.onSurface),
        secondaryLabelStyle: text.labelLarge?.copyWith(
          color: scheme.surface,
          fontWeight: FontWeight.w600,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        showCheckmark: false,
      ),

      // Filled, square-cornered-but-soft, and inverted when it is the primary
      // action — the Play/Shuffle pair the reference puts above a track list.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.onSurface,
          foregroundColor: scheme.surface,
          elevation: 0,
          minimumSize: const Size(0, 48),
          textStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusSmall)),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.onSurface,
          backgroundColor: isDark ? scheme.surfaceContainerLow : Colors.transparent,
          side: BorderSide(color: scheme.outlineVariant),
          minimumSize: const Size(0, 48),
          textStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusSmall)),
        ),
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
