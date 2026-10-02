import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/artwork_theme_provider.dart';

/// Re-themes its subtree around the playing track's cover art.
///
/// Uses [AnimatedTheme] rather than animating the accent colour directly:
/// `ColorScheme.fromSeed` runs a full tonal-palette computation, which is too
/// expensive to repeat every frame, whereas `AnimatedTheme` lerps between two
/// already-built themes. The seed therefore changes once per track and the
/// colour still travels rather than snapping.
class ArtworkTheme extends ConsumerStatefulWidget {
  const ArtworkTheme({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<ArtworkTheme> createState() => _ArtworkThemeState();
}

class _ArtworkThemeState extends ConsumerState<ArtworkTheme> {
  Brightness? _lastBrightness;

  @override
  Widget build(BuildContext context) {
    final accent = ref.watch(currentAccentSeedProvider);
    final brightness = Theme.of(context).brightness;

    // Light/dark is already being animated by the MaterialApp above, and
    // `ThemeData.lerp` interpolates every colour, text style and component
    // theme it holds. Running a second pass of that in here just doubled the
    // per-frame cost of switching appearance, which was visible as a stutter.
    // A track change still animates — that is the one this widget exists for.
    final switchingAppearance = _lastBrightness != null && _lastBrightness != brightness;
    _lastBrightness = brightness;

    return AnimatedTheme(
      data: themeForAccent(accent, brightness),
      duration: switchingAppearance ? Duration.zero : const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      child: widget.child,
    );
  }
}
