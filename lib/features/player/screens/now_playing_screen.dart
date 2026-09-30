import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/duration_format.dart';
import '../../../widgets/artwork_image.dart';
import '../../../widgets/empty_state.dart';
import '../../folders/providers/folder_providers.dart';
import '../../library/providers/library_providers.dart';
import '../providers/player_providers.dart';
import '../widgets/queue_sheet.dart';
import '../widgets/waveform_seek_bar.dart';

class NowPlayingScreen extends ConsumerWidget {
  const NowPlayingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = ref.watch(currentMediaItemProvider).value;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

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

    final state = ref.watch(playbackStateProvider).value;
    final playing = state?.playing ?? false;
    final repeatMode = state?.repeatMode ?? AudioServiceRepeatMode.all;
    final shuffleOn = (state?.shuffleMode ?? AudioServiceShuffleMode.none) != AudioServiceShuffleMode.none;
    final position = ref.watch(playbackPositionProvider).value ?? Duration.zero;
    final duration = item.duration ?? Duration.zero;
    final track = ref.watch(trackByPathProvider(item.id));
    final isFavorite = ref.watch(isFavoriteProvider(item.id));
    final controller = ref.read(playerControllerProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Now playing'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Queue',
            icon: const Icon(Icons.queue_music),
            onPressed: () => showQueueSheet(context),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Artwork takes what's left after the controls, so short screens
            // shrink the cover instead of overflowing.
            final artworkSize = (constraints.maxHeight - 330).clamp(140.0, constraints.maxWidth - 48);

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                      boxShadow: [
                        BoxShadow(
                          color: scheme.primary.withValues(alpha: 0.28),
                          blurRadius: 40,
                          spreadRadius: -8,
                          offset: const Offset(0, 18),
                        ),
                      ],
                    ),
                    child: ArtworkImage(
                      trackId: track?.id,
                      size: artworkSize,
                      borderRadius: AppTheme.radiusLarge,
                      iconSize: artworkSize * 0.3,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      const SizedBox(width: 40),
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              item.title,
                              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              item.artist ?? 'Unknown artist',
                              style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: isFavorite ? 'Remove from Favorites' : 'Add to Favorites',
                        icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border),
                        color: isFavorite ? scheme.primary : scheme.onSurfaceVariant,
                        onPressed: () => ref.read(folderActionsProvider).toggleFavorite(item.id),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  WaveformSeekBar(
                    seed: item.id,
                    position: position,
                    duration: duration,
                    onSeek: controller.seek,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(formatDuration(position), style: theme.textTheme.bodySmall),
                      Text(formatDuration(duration), style: theme.textTheme.bodySmall),
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
                      _PlayButton(playing: playing, onPressed: controller.togglePlayPause),
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
    );
  }
}

class _PlayButton extends StatelessWidget {
  const _PlayButton({required this.playing, required this.onPressed});

  final bool playing;
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
          gradient: const LinearGradient(
            colors: [AppTheme.gradientStart, AppTheme.gradientEnd],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.gradientEnd.withValues(alpha: 0.4),
              blurRadius: 24,
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
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
