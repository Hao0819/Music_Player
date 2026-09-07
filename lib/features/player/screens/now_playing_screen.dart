import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/duration_format.dart';
import '../../../widgets/artwork_image.dart';
import '../../../widgets/empty_state.dart';
import '../../folders/providers/folder_providers.dart';
import '../../library/providers/library_providers.dart';
import '../providers/player_providers.dart';
import '../widgets/queue_sheet.dart';

class NowPlayingScreen extends ConsumerWidget {
  const NowPlayingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = ref.watch(currentMediaItemProvider).value;
    final scheme = Theme.of(context).colorScheme;

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
    final repeatMode = state?.repeatMode ?? AudioServiceRepeatMode.none;
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
        actions: [
          IconButton(
            tooltip: 'Queue',
            icon: const Icon(Icons.queue_music),
            onPressed: () => showQueueSheet(context),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Spacer(),
              LayoutBuilder(
                builder: (context, constraints) => ArtworkImage(
                  trackId: track?.id,
                  size: constraints.maxWidth,
                  borderRadius: 20,
                  iconSize: 96,
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: Theme.of(context).textTheme.titleLarge,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${item.artist ?? 'Unknown artist'} · ${item.album ?? 'Unknown album'}',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: scheme.onSurfaceVariant),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border),
                    color: isFavorite ? scheme.primary : scheme.onSurfaceVariant,
                    onPressed: () => ref.read(folderActionsProvider).toggleFavorite(item.id),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Slider(
                min: 0,
                max: duration.inMilliseconds.toDouble().clamp(1, double.infinity),
                value: position.inMilliseconds.toDouble().clamp(0, duration.inMilliseconds.toDouble()),
                onChanged: (value) => controller.seek(Duration(milliseconds: value.round())),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(formatDuration(position), style: Theme.of(context).textTheme.bodySmall),
                    Text(formatDuration(duration), style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              const SizedBox(height: 8),
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
                    iconSize: 40,
                    icon: const Icon(Icons.skip_previous),
                    onPressed: controller.previous,
                  ),
                  IconButton.filled(
                    iconSize: 40,
                    icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                    onPressed: controller.togglePlayPause,
                  ),
                  IconButton(
                    iconSize: 40,
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
                    color: repeatMode == AudioServiceRepeatMode.none ? scheme.onSurfaceVariant : scheme.primary,
                    onPressed: controller.cycleRepeatMode,
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

