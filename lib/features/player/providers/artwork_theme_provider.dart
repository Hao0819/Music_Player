import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:on_audio_query/on_audio_query.dart' show ArtworkType;

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/artwork_palette.dart';
import '../../library/providers/library_providers.dart';
import 'player_providers.dart';

/// Low-resolution cover art, shared by the colour sampler and the Now Playing
/// backdrop so one platform-channel call serves both.
///
/// 200px is plenty for a 32×32 histogram and for an image that gets blurred
/// to within an inch of its life, and it decodes far faster than the 400px
/// the on-screen artwork asks for. Riverpod's cache is what keeps this to one
/// call per track — the same reason `ArtworkImage` keeps its own map rather
/// than building a future inside `build`.
final artworkBytesProvider = FutureProvider.family<Uint8List?, int>((ref, trackId) async {
  final bytes = await ref.read(onAudioQueryProvider).queryArtwork(
        trackId,
        ArtworkType.AUDIO,
        size: 200,
      );
  return (bytes == null || bytes.isEmpty) ? null : bytes;
});

/// Accent sampled from one track's cover art, or null when it has none to
/// sample.
final artworkSeedProvider = FutureProvider.family<Color?, int>((ref, trackId) async {
  final bytes = await ref.watch(artworkBytesProvider(trackId).future);
  if (bytes == null) return null;

  final sampled = await ArtworkPalette.dominantColor(bytes);
  return sampled == null ? null : ArtworkPalette.toSeed(sampled);
});

/// MediaStore id of the playing track.
///
/// The queue carries file paths, not MediaStore ids, and artwork lookup needs
/// the id — so it is resolved through the library, the same way the artwork
/// widgets do.
final currentTrackIdProvider = Provider<int?>((ref) {
  final item = ref.watch(currentMediaItemProvider).value;
  if (item == null) return null;
  return ref.watch(trackByPathProvider(item.id))?.id;
});

/// The accent for whatever is playing right now, or null before a track is
/// loaded or while its art is still being sampled.
final currentAccentSeedProvider = Provider<Color?>((ref) {
  final id = ref.watch(currentTrackIdProvider);
  if (id == null) return null;
  return ref.watch(artworkSeedProvider(id)).value;
});

/// Cover art for the playing track, for the Now Playing backdrop.
final currentArtworkBytesProvider = Provider<Uint8List?>((ref) {
  final id = ref.watch(currentTrackIdProvider);
  if (id == null) return null;
  return ref.watch(artworkBytesProvider(id)).value;
});

/// Builds the full theme for an accent, falling back to the app's own signal
/// blue so a track without art still gets a coherent screen rather than a
/// colourless one.
ThemeData themeForAccent(Color? accent, Brightness brightness) {
  final scheme = AppTheme.neutralize(
    ColorScheme.fromSeed(
      seedColor: accent ?? AppTheme.signal,
      brightness: brightness,
      dynamicSchemeVariant: DynamicSchemeVariant.vibrant,
    ),
  );
  return AppTheme.themeFor(scheme);
}
