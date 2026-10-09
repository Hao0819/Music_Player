import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../widgets/empty_state.dart';
import '../../library/providers/library_providers.dart';
import '../../library/widgets/track_tile.dart';
import '../../player/widgets/mini_player.dart';

/// The way back out of hiding something.
///
/// Hiding a track is reversible by design, which only means anything if there
/// is somewhere to reverse it from. Without this screen the button in the
/// Library would put files somewhere the user cannot get them back — exactly
/// the outcome hiding exists to avoid.
class HiddenTracksScreen extends ConsumerWidget {
  const HiddenTracksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracks = ref.watch(hiddenLibraryProvider);
    final hiddenCount = ref.watch(hiddenTracksProvider).length;
    final notifier = ref.read(hiddenTracksProvider.notifier);

    // Hidden paths the current scan cannot resolve: files hidden here and then
    // removed from the device elsewhere. They are counted rather than listed
    // because there is no track left to draw a row from, and saying nothing
    // would make the count above disagree with the list for no visible reason.
    final unresolved = hiddenCount - tracks.length;

    return Scaffold(
      bottomNavigationBar: const MiniPlayer(isBottomMost: true),
      appBar: AppBar(
        title: const Text('Hidden tracks'),
        actions: [
          if (hiddenCount > 0)
            TextButton(
              onPressed: () async {
                await notifier.unhideAll();
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Restore all'),
            ),
        ],
      ),
      body: hiddenCount == 0
          ? const EmptyState(
              icon: Icons.visibility_outlined,
              title: 'Nothing hidden',
              message: 'Hold a track in your Library to select it, then use the '
                  'hide button to keep it out of the list.',
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: tracks.length + (unresolved > 0 ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == tracks.length) return _UnresolvedNote(count: unresolved);

                final track = tracks[index];
                return TrackTile(
                  track: track,
                  // Restoring is the only thing this row does. Tapping it does
                  // not play the track: a list of things the user asked not to
                  // see is a poor place to start playback from by accident.
                  trailing: IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Restore to Library',
                    icon: const Icon(Icons.visibility_outlined, size: 19),
                    onPressed: () => notifier.unhide([track.path]),
                  ),
                );
              },
            ),
    );
  }
}

class _UnresolvedNote extends StatelessWidget {
  const _UnresolvedNote({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Text(
        '$count more hidden file${count == 1 ? '' : 's'} '
        '${count == 1 ? 'is' : 'are'} no longer on this device. '
        'Restore all clears those too.',
        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
    );
  }
}
