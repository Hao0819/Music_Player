import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/selection_notifier.dart';
import '../../../widgets/empty_state.dart';
import '../../folders/providers/folder_providers.dart';
import '../../folders/widgets/add_to_folder_sheet.dart';
import '../../library/widgets/track_tile.dart';
import '../../player/providers/player_providers.dart';
import '../providers/history_providers.dart';

final _historySelectionProvider = NotifierProvider<SelectionNotifier, Set<String>>(SelectionNotifier.new);

/// Renders either auto-collection — they differ only in ordering, title and
/// whether play counts are shown.
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key, required this.view});

  final HistoryView view;

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(_historySelectionProvider.notifier).clear();
    });
  }

  String get _title => switch (widget.view) {
        HistoryView.recentlyPlayed => 'Recently played',
        HistoryView.mostPlayed => 'Most played',
      };

  @override
  Widget build(BuildContext context) {
    final tracks = ref.watch(historyTracksProvider(widget.view));
    final selection = ref.watch(_historySelectionProvider);
    final inSelectionMode = selection.isNotEmpty;
    final selectionNotifier = ref.read(_historySelectionProvider.notifier);
    final folderActions = ref.read(folderActionsProvider);
    final playCounts = ref.watch(playCountsProvider);

    return Scaffold(
      appBar: inSelectionMode
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: selectionNotifier.clear,
              ),
              title: Text('${selection.length} selected'),
              actions: [
                IconButton(
                  tooltip: 'Add to folder',
                  icon: const Icon(Icons.create_new_folder_outlined),
                  onPressed: () async {
                    await showAddToFolderSheet(context, ref, selection.toList());
                    selectionNotifier.clear();
                  },
                ),
              ],
            )
          : AppBar(
              title: Text(_title),
              actions: [
                if (tracks.isNotEmpty)
                  IconButton(
                    tooltip: 'Clear history',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: _confirmClear,
                  ),
              ],
            ),
      body: tracks.isEmpty
          ? EmptyState(
              icon: widget.view == HistoryView.recentlyPlayed ? Icons.history : Icons.trending_up,
              title: 'Nothing played yet',
              message: 'Play something and it will show up here.',
            )
          : ListView.builder(
              itemCount: tracks.length,
              itemBuilder: (context, index) {
                final track = tracks[index];
                final count = playCounts[track.path] ?? 0;

                return TrackTile(
                  track: track,
                  selectionMode: inSelectionMode,
                  selected: selection.contains(track.path),
                  isFavorite: ref.watch(isFavoriteProvider(track.path)),
                  onFavoriteToggle: () => folderActions.toggleFavorite(track.path),
                  onLongPress: () => selectionNotifier.toggle(track.path),
                  onTap: inSelectionMode
                      ? () => selectionNotifier.toggle(track.path)
                      : () => ref.read(playerControllerProvider).playTracks(tracks, initialIndex: index),
                  trailing: widget.view == HistoryView.mostPlayed
                      ? _PlayCountBadge(count: count)
                      : null,
                );
              },
            ),
    );
  }

  Future<void> _confirmClear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear play history?'),
        content: const Text(
          'This only clears what you have played — your folders, favorites and '
          'audio files are not affected.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Clear')),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(clearHistoryProvider)();
    }
  }
}

class _PlayCountBadge extends StatelessWidget {
  const _PlayCountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$count×',
        style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSecondaryContainer),
      ),
    );
  }
}
