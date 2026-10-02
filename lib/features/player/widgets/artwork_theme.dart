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
class ArtworkTheme extends ConsumerWidget {
  const ArtworkTheme({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = ref.watch(currentAccentSeedProvider);
    final brightness = Theme.of(context).brightness;

    return AnimatedTheme(
      data: themeForAccent(accent, brightness),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      child: child,
    );
  }
}
