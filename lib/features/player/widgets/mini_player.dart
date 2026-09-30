import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../widgets/artwork_image.dart';
import '../../library/providers/library_providers.dart';
import '../providers/player_providers.dart';
import '../screens/now_playing_screen.dart';

/// Rounded card floating above the bottom navigation. Renders nothing until
/// something is actually playing.
class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key, this.isBottomMost = false});

  /// True where the bar is the last thing on screen (folder, history and
  /// new-audio pages). In the tab shell the navigation bar sits below it and
  /// already clears the system bar; on its own, the bar must pad itself or its
  /// buttons land inside Android's gesture area and taps get swallowed.
  final bool isBottomMost;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = ref.watch(currentMediaItemProvider).value;
    if (item == null) return const SizedBox.shrink();

    final bar = _buildBar(context, ref, item);
    // The card floats, so nothing is painted behind the gesture area — only
    // the inset needs to grow when the bar is the bottom-most thing.
    return isBottomMost ? SafeArea(top: false, child: bar) : bar;
  }

  Widget _buildBar(BuildContext context, WidgetRef ref, MediaItem item) {
    final state = ref.watch(playbackStateProvider).value;
    final playing = state?.playing ?? false;
    final position = ref.watch(playbackPositionProvider).value ?? Duration.zero;
    final duration = item.duration ?? Duration.zero;
    final progress = duration.inMilliseconds == 0
        ? 0.0
        : (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final controller = ref.read(playerControllerProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          color: scheme.surfaceContainerHighest,
          boxShadow: [
            BoxShadow(
              color: scheme.primary.withValues(alpha: 0.18),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const NowPlayingScreen()),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 12, 6),
                  child: Row(
                    children: [
                      _MiniArtwork(mediaItemId: item.id),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall,
                            ),
                            Text(
                              item.artist ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      _GradientPlayButton(playing: playing, onTap: controller.togglePlayPause),
                      IconButton(
                        icon: const Icon(Icons.skip_next_rounded),
                        onPressed: controller.next,
                      ),
                    ],
                  ),
                ),
                // Progress lives at the bottom edge of the card, inset so it
                // follows the rounded corners instead of being clipped by them.
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 3,
                      backgroundColor: scheme.onSurface.withValues(alpha: 0.10),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The mini player's only bright element, matching the big button on the
/// Now Playing screen so the two read as the same control.
class _GradientPlayButton extends StatelessWidget {
  const _GradientPlayButton({required this.playing, required this.onTap});

  final bool playing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [AppTheme.gradientStart, AppTheme.gradientEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(
              playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}

/// Artwork lookup needs the MediaStore id, which the queue doesn't carry, so
/// resolve it from the library by path.
class _MiniArtwork extends ConsumerWidget {
  const _MiniArtwork({required this.mediaItemId});

  final String mediaItemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final track = ref.watch(trackByPathProvider(mediaItemId));
    return ArtworkImage(trackId: track?.id, size: 48, borderRadius: 14, iconSize: 22);
  }
}
