import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../widgets/artwork_image.dart';
import '../../library/providers/library_providers.dart';
import '../providers/player_providers.dart';
import '../screens/now_playing_screen.dart';

/// Slim bar docked above the bottom navigation. Renders nothing until
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
    if (!isBottomMost) return bar;

    // Paint the bar colour under the system gesture area too, so the padding
    // reads as part of the bar rather than a gap.
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: SafeArea(top: false, child: bar),
    );
  }

  Widget _buildBar(BuildContext context, WidgetRef ref, MediaItem item) {

    final state = ref.watch(playbackStateProvider).value;
    final playing = state?.playing ?? false;
    final position = ref.watch(playbackPositionProvider).value ?? Duration.zero;
    final duration = item.duration ?? Duration.zero;
    final progress = duration.inMilliseconds == 0
        ? 0.0
        : (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
    final scheme = Theme.of(context).colorScheme;
    final controller = ref.read(playerControllerProvider);

    return Material(
      color: scheme.surfaceContainerHigh,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const NowPlayingScreen()),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LinearProgressIndicator(
              value: progress,
              minHeight: 2,
              backgroundColor: scheme.surfaceContainerHighest,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  _MiniArtwork(mediaItemId: item.id),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text(
                          item.artist ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                    onPressed: controller.togglePlayPause,
                  ),
                  IconButton(
                    icon: const Icon(Icons.skip_next),
                    onPressed: controller.next,
                  ),
                ],
              ),
            ),
          ],
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
    return ArtworkImage(trackId: track?.id, size: 40, borderRadius: 6, iconSize: 20);
  }
}
