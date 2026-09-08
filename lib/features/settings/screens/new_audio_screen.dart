import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/selection_notifier.dart';
import '../../../widgets/empty_state.dart';
import '../../folders/providers/folder_providers.dart';
import '../../folders/widgets/add_to_folder_sheet.dart';
import '../../library/widgets/track_tile.dart';
import '../../player/providers/player_providers.dart';
import '../providers/maintenance_providers.dart';

final _newAudioSelectionProvider = NotifierProvider<SelectionNotifier, Set<String>>(SelectionNotifier.new);

/// Tracks that showed up since the user last looked. The point of this screen
/// is filing them, so multi-select and "add to folder" are front and centre.
class NewAudioScreen extends ConsumerStatefulWidget {
  const NewAudioScreen({super.key});

  @override
  ConsumerState<NewAudioScreen> createState() => _NewAudioScreenState();
}

class _NewAudioScreenState extends ConsumerState<NewAudioScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(_newAudioSelectionProvider.notifier).clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final tracks = ref.watch(newTracksProvider);
    final selection = ref.watch(_newAudioSelectionProvider);
    final inSelectionMode = selection.isNotEmpty;
    final selectionNotifier = ref.read(_newAudioSelectionProvider.notifier);
    final folderActions = ref.read(folderActionsProvider);
    final maintenance = ref.read(maintenanceActionsProvider);

    return Scaffold(
      appBar: inSelectionMode
          ? AppBar(
              leading: IconButton(icon: const Icon(Icons.close), onPressed: selectionNotifier.clear),
              title: Text('${selection.length} selected'),
              actions: [
                IconButton(
                  tooltip: 'Add to folder',
                  icon: const Icon(Icons.create_new_folder_outlined),
                  onPressed: () async {
                    final paths = selection.toList();
                    await showAddToFolderSheet(context, ref, paths);
                    // Filing a track counts as having dealt with it.
                    await maintenance.acknowledgeNewTracks(paths);
                    selectionNotifier.clear();
                  },
                ),
              ],
            )
          : AppBar(
              title: const Text('New audio'),
              actions: [
                if (tracks.isNotEmpty)
                  TextButton(
                    onPressed: () async {
                      await maintenance.acknowledgeAllNewTracks();
                      if (context.mounted) Navigator.pop(context);
                    },
                    child: const Text('Mark all seen'),
                  ),
              ],
            ),
      body: tracks.isEmpty
          ? const EmptyState(
              icon: Icons.done_all,
              title: 'Nothing new',
              message: 'Audio added to your device since the last scan shows up here.',
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Long-press to select several, then file them into a folder.',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: tracks.length,
                    itemBuilder: (context, index) {
                      final track = tracks[index];

                      return TrackTile(
                        track: track,
                        selectionMode: inSelectionMode,
                        selected: selection.contains(track.path),
                        isFavorite: ref.watch(isFavoriteProvider(track.path)),
                        onFavoriteToggle: () => folderActions.toggleFavorite(track.path),
                        onLongPress: () => selectionNotifier.toggle(track.path),
                        onTap: inSelectionMode
                            ? () => selectionNotifier.toggle(track.path)
                            : () => ref
                                .read(playerControllerProvider)
                                .playTracks(tracks, initialIndex: index),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
