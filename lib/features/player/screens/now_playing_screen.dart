import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/duration_format.dart';
import '../../../widgets/artwork_image.dart';
import '../../../widgets/empty_state.dart';
import '../../folders/providers/folder_providers.dart';
import '../../library/providers/library_providers.dart';
import '../providers/artwork_theme_provider.dart';
import '../providers/player_providers.dart';
import '../widgets/artwork_theme.dart';
import '../widgets/queue_sheet.dart';
import '../widgets/waveform_seek_bar.dart';

/// Raises Now Playing as a sheet from the bottom.
///
/// The screen is a detail view of the bar you tapped, directly above it — a
/// horizontal push would imply you had moved sideways in a hierarchy.
///
/// [heroTag] is supplied by the mini player that opened this screen rather
/// than being a constant, because a mini player sits on four different routes
/// and two of them are alive at once whenever one is pushed over another. A
/// shared tag would make Flutter fly the thumbnail between those two bars —
/// which sit at different heights, since only the bottom-most one pads itself
/// past the gesture area — on every unrelated push.
Route<void> nowPlayingRoute({required Object heroTag}) {
  return PageRouteBuilder<void>(
    transitionDuration: const Duration(milliseconds: 420),
    reverseTransitionDuration: const Duration(milliseconds: 320),
    pageBuilder: (context, animation, secondaryAnimation) => NowPlayingScreen(heroTag: heroTag),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return SlideTransition(
        position: Tween(begin: const Offset(0, 1), end: Offset.zero).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic),
        ),
        child: child,
      );
    },
  );
}

class NowPlayingScreen extends ConsumerWidget {
  const NowPlayingScreen({super.key, this.heroTag});

  /// Matches the tag of the mini player that opened this screen. Null when
  /// the screen is reached some other way, which simply means no hero flight.
  final Object? heroTag;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = ref.watch(currentMediaItemProvider).value;

    if (item == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState(
          icon: Icons.music_note_outlined,
          title: 'Nothing playing',
          message: 'Pick a track from your library to start.',
        ),
      );
    }

    // Everything below reads its colour from the theme, so re-theming here is
    // what makes the whole screen follow the cover art.
    return ArtworkTheme(child: _NowPlayingBody(item: item, heroTag: heroTag));
  }
}

class _NowPlayingBody extends ConsumerWidget {
  const _NowPlayingBody({required this.item, required this.heroTag});

  final MediaItem item;
  final Object? heroTag;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final state = ref.watch(playbackStateProvider).value;
    final playing = state?.playing ?? false;
    final repeatMode = state?.repeatMode ?? AudioServiceRepeatMode.all;
    final shuffleOn = (state?.shuffleMode ?? AudioServiceShuffleMode.none) != AudioServiceShuffleMode.none;
    final position = ref.watch(playbackPositionProvider).value ?? Duration.zero;
    final duration = item.duration ?? Duration.zero;
    final track = ref.watch(trackByPathProvider(item.id));
    final isFavorite = ref.watch(isFavoriteProvider(item.id));
    final artwork = ref.watch(currentArtworkBytesProvider);
    // The transport is painted in the sampled accent rather than in
    // scheme.primary — see AppTheme.accentGradient for why.
    final accent = ref.watch(currentAccentSeedProvider) ?? AppTheme.signal;
    final controller = ref.read(playerControllerProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
        leading: IconButton(
          tooltip: 'Close',
          icon: const Icon(Icons.keyboard_arrow_down),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Now playing', style: theme.textTheme.labelLarge),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Queue',
            icon: const Icon(Icons.queue_music),
            onPressed: () => showQueueSheet(context),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          _Backdrop(bytes: artwork, trackId: track?.id),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Artwork takes what's left after the controls, so short
                // screens shrink the cover instead of overflowing.
                final artworkSize = (constraints.maxHeight - 356).clamp(140.0, constraints.maxWidth - 48);

                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: _MaybeHero(
                          tag: heroTag,
                          // The thumbnail and the cover have different corner
                          // radii, so interpolate the shape across the flight
                          // rather than letting Flutter swap it at the end.
                          flightShuttleBuilder: (context, animation, direction, from, to) {
                            return AnimatedBuilder(
                              animation: animation,
                              builder: (context, _) {
                                final t = Curves.easeOutCubic.transform(animation.value);
                                final radius = direction == HeroFlightDirection.push
                                    ? ui.lerpDouble(14, AppTheme.radiusLarge, t)!
                                    : ui.lerpDouble(AppTheme.radiusLarge, 14, t)!;
                                // The shuttle must take its size from the
                                // flight rect, not from a constant: ArtworkImage
                                // needs an explicit size, and passing the final
                                // one made the cover paint full size for the
                                // whole flight — it overflowed the rect and the
                                // cover simply appeared already-large instead of
                                // growing out of the mini player.
                                return LayoutBuilder(
                                  builder: (context, constraints) {
                                    final side = constraints.biggest.shortestSide;
                                    return ArtworkImage(
                                      trackId: track?.id,
                                      size: side,
                                      borderRadius: radius,
                                      iconSize: side * 0.3,
                                    );
                                  },
                                );
                              },
                            );
                          },
                          child: _ArtworkCard(
                            trackId: track?.id,
                            size: artworkSize,
                            glow: scheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.title,
                                  style: AppTheme.displayTitle(theme.textTheme, item.title),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  item.artist ?? 'Unknown artist',
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Sits on the title's baseline rather than centred
                          // under it: it acts on this track, so it belongs
                          // beside the track's name.
                          IconButton(
                            tooltip: isFavorite ? 'Remove from Favorites' : 'Add to Favorites',
                            icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border),
                            iconSize: 26,
                            color: isFavorite ? scheme.primary : scheme.onSurfaceVariant,
                            onPressed: () => ref.read(folderActionsProvider).toggleFavorite(item.id),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      WaveformSeekBar(
                        seed: item.id,
                        position: position,
                        duration: duration,
                        onSeek: controller.seek,
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(formatDuration(position), style: theme.textTheme.labelSmall),
                          Text(formatDuration(duration), style: theme.textTheme.labelSmall),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          IconButton(
                            tooltip: shuffleOn ? 'Shuffle on' : 'Shuffle off',
                            icon: const Icon(Icons.shuffle),
                            color: shuffleOn ? scheme.primary : scheme.onSurfaceVariant,
                            onPressed: controller.toggleShuffle,
                          ),
                          IconButton(
                            iconSize: 38,
                            icon: const Icon(Icons.skip_previous),
                            onPressed: controller.previous,
                          ),
                          _PlayButton(
                            playing: playing,
                            accent: accent,
                            onPressed: controller.togglePlayPause,
                          ),
                          IconButton(
                            iconSize: 38,
                            icon: const Icon(Icons.skip_next),
                            onPressed: controller.next,
                          ),
                          IconButton(
                            tooltip: switch (repeatMode) {
                              AudioServiceRepeatMode.one => 'Repeat one',
                              AudioServiceRepeatMode.none => 'Repeat off',
                              _ => 'Repeat all',
                            },
                            icon: Icon(
                              repeatMode == AudioServiceRepeatMode.one ? Icons.repeat_one : Icons.repeat,
                            ),
                            color: repeatMode == AudioServiceRepeatMode.none
                                ? scheme.onSurfaceVariant
                                : scheme.primary,
                            onPressed: controller.cycleRepeatMode,
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// A [Hero] when there is a tag to fly to, and the bare child otherwise —
/// a Hero with no counterpart on the route below would still lift its child
/// into the overlay for the length of the transition.
class _MaybeHero extends StatelessWidget {
  const _MaybeHero({
    required this.tag,
    required this.flightShuttleBuilder,
    required this.child,
  });

  final Object? tag;
  final HeroFlightShuttleBuilder flightShuttleBuilder;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tag = this.tag;
    if (tag == null) return child;

    return Hero(
      tag: tag,
      flightShuttleBuilder: flightShuttleBuilder,
      child: child,
    );
  }
}

/// The cover art's own colours, blurred far past recognition and sunk into the
/// scaffold. It is the reason the screen looks like this track rather than
/// like the app: the accent is sampled from the same image, so backdrop and
/// controls are guaranteed to agree.
class _Backdrop extends StatelessWidget {
  const _Backdrop({required this.bytes, required this.trackId});

  final Uint8List? bytes;

  /// Identity for the cross-fade. Keyed on the track rather than on the bytes,
  /// because two different covers can easily encode to the same length and
  /// the switcher would then skip the transition entirely.
  final int? trackId;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;

    return Stack(
      fit: StackFit.expand,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 600),
          child: bytes == null
              // Tracks with no art fall back to a flat surface, so the layout
              // does not shift when art is missing.
              ? Container(key: const ValueKey('flat'), color: scheme.surface)
              : Stack(
                  key: ValueKey(trackId),
                  fit: StackFit.expand,
                  children: [
                    Container(color: scheme.surface),
                    ImageFiltered(
                      imageFilter:
                          ui.ImageFilter.blur(sigmaX: 64, sigmaY: 64, tileMode: TileMode.decal),
                      child: Opacity(
                        opacity: isDark ? 0.55 : 0.38,
                        child: Image.memory(bytes!, fit: BoxFit.cover, gaplessPlayback: true),
                      ),
                    ),
                    // Pulls contrast back under the type. Without it, a bright
                    // cover leaves the title sitting on its own mid-tones.
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            scheme.surface.withValues(alpha: isDark ? 0.45 : 0.30),
                            scheme.surface.withValues(alpha: isDark ? 0.82 : 0.80),
                            scheme.surface.withValues(alpha: isDark ? 0.96 : 0.94),
                          ],
                          stops: const [0, 0.55, 1],
                        ),
                      ),
                    ),
                  ],
                ),
        ),
        // Sits above the scrim rather than under it, because the scrim is what
        // would otherwise erase it. Plenty of covers are black-on-black
        // artwork; blurred, those give a flat black field and the screen stops
        // showing the track's colour at all. This wash is drawn from the same
        // sampled accent, so it reinforces the cover instead of fighting it.
        IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  scheme.primary.withValues(alpha: isDark ? 0.17 : 0.11),
                  scheme.primary.withValues(alpha: 0),
                ],
                stops: const [0, 0.62],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Artwork plus the glow beneath it. Split out so the [Hero] has a single
/// child whose shape the flight builder can mirror.
class _ArtworkCard extends StatelessWidget {
  const _ArtworkCard({required this.trackId, required this.size, required this.glow});

  final int? trackId;
  final double size;
  final Color glow;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        boxShadow: [
          BoxShadow(
            color: glow.withValues(alpha: 0.30),
            blurRadius: 44,
            spreadRadius: -10,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: ArtworkImage(
        trackId: trackId,
        size: size,
        borderRadius: AppTheme.radiusLarge,
        iconSize: size * 0.3,
        placeholderTint: 0.20,
      ),
    );
  }
}

class _PlayButton extends StatelessWidget {
  const _PlayButton({required this.playing, required this.accent, required this.onPressed});

  final bool playing;
  final Color accent;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 76,
        height: 76,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: AppTheme.accentGradient(accent),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.42),
              blurRadius: 26,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
          child: Icon(
            playing ? Icons.pause : Icons.play_arrow,
            key: ValueKey(playing),
            size: 40,
            color: AppTheme.onAccent(accent),
          ),
        ),
      ),
    );
  }
}
