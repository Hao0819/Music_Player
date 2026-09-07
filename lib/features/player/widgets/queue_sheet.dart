import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/duration_format.dart';
import '../providers/player_providers.dart';

Future<void> showQueueSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => const _QueueSheet(),
  );
}

class _QueueSheet extends ConsumerWidget {
  const _QueueSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue = ref.watch(queueProvider).value ?? const [];
    final currentIndex = ref.watch(playbackStateProvider).value?.queueIndex;
    final controller = ref.read(playerControllerProvider);
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Queue · ${queue.length}', style: Theme.of(context).textTheme.titleMedium),
              ),
            ),
            Flexible(
              child: ReorderableListView.builder(
                shrinkWrap: true,
                itemCount: queue.length,
                onReorderItem: controller.moveQueueItem,
                itemBuilder: (context, index) {
                  final item = queue[index];
                  final isCurrent = index == currentIndex;

                  return ListTile(
                    key: ValueKey('${item.id}#$index'),
                    leading: Icon(
                      isCurrent ? Icons.equalizer : Icons.drag_handle,
                      color: isCurrent ? scheme.primary : scheme.onSurfaceVariant,
                    ),
                    title: Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: isCurrent ? TextStyle(color: scheme.primary) : null,
                    ),
                    subtitle: Text(item.artist ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(formatDuration(item.duration ?? Duration.zero)),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => controller.removeQueueItemAt(index),
                        ),
                      ],
                    ),
                    onTap: () => controller.skipToQueueItem(index),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
