import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/folder_repository.dart';
import '../providers/folder_providers.dart';
import 'folder_name_dialog.dart';

Future<void> showAddToFolderSheet(BuildContext context, WidgetRef ref, List<String> trackPaths) {
  return showModalBottomSheet(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => _AddToFolderSheet(trackPaths: trackPaths),
  );
}

class _AddToFolderSheet extends ConsumerWidget {
  const _AddToFolderSheet({required this.trackPaths});

  final List<String> trackPaths;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final folders = ref.watch(folderListProvider);
    final userFolders = folders.where((folder) => !folder.isSystem).toList();
    final count = trackPaths.length;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Add $count track${count == 1 ? '' : 's'} to',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.favorite),
              title: const Text('Favorites'),
              onTap: () async {
                await ref.read(folderActionsProvider).addTracks(favoritesFolderId, trackPaths);
                if (context.mounted) Navigator.pop(context);
              },
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final folder in userFolders)
                    ListTile(
                      leading: const Icon(Icons.folder_outlined),
                      title: Text(folder.name),
                      onTap: () async {
                        await ref.read(folderActionsProvider).addTracks(folder.id, trackPaths);
                        if (context.mounted) Navigator.pop(context);
                      },
                    ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.create_new_folder_outlined),
              title: const Text('New folder'),
              onTap: () async {
                final name = await promptForFolderName(context);
                if (name == null || name.trim().isEmpty) return;
                final actions = ref.read(folderActionsProvider);
                final folder = await actions.createFolder(name);
                await actions.addTracks(folder.id, trackPaths);
                if (context.mounted) Navigator.pop(context);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
