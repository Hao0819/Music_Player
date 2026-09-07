import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/hive/models/folder_model.dart';
import '../../../widgets/empty_state.dart';
import '../providers/folder_providers.dart';
import '../widgets/folder_name_dialog.dart';
import 'folder_detail_screen.dart';

class FoldersScreen extends ConsumerWidget {
  const FoldersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final folders = ref.watch(folderListProvider);
    final systemFolders = folders.where((folder) => folder.isSystem).toList();
    final userFolders = folders.where((folder) => !folder.isSystem).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Folders'),
        actions: [
          IconButton(
            tooltip: 'New folder',
            icon: const Icon(Icons.create_new_folder_outlined),
            onPressed: () async {
              final name = await promptForFolderName(context);
              if (name == null || name.trim().isEmpty) return;
              await ref.read(folderActionsProvider).createFolder(name);
            },
          ),
        ],
      ),
      body: ListView(
        children: [
          for (final folder in systemFolders) _FolderListTile(folder: folder),
          if (userFolders.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 80),
              child: EmptyState(
                icon: Icons.folder_outlined,
                title: 'No folders yet',
                message: 'Tap the folder+ icon to create one — folders organize tracks without touching the files.',
              ),
            )
          else ...[
            const Divider(height: 1),
            for (final folder in userFolders) _FolderListTile(folder: folder),
          ],
        ],
      ),
    );
  }
}

class _FolderListTile extends ConsumerWidget {
  const _FolderListTile({required this.folder});

  final FolderModel folder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracksAsync = ref.watch(folderTracksProvider(folder.id));
    final count = tracksAsync.value?.length;

    return ListTile(
      leading: Icon(folder.isSystem ? Icons.favorite : Icons.folder),
      title: Text(folder.name),
      subtitle: count == null ? null : Text('$count track${count == 1 ? '' : 's'}'),
      trailing: folder.isSystem
          ? null
          : PopupMenuButton<String>(
              onSelected: (action) => _handleAction(context, ref, action),
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'rename', child: Text('Rename')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => FolderDetailScreen(folderId: folder.id)),
      ),
    );
  }

  Future<void> _handleAction(BuildContext context, WidgetRef ref, String action) async {
    if (action == 'rename') {
      final name = await promptForFolderName(context, initialValue: folder.name, title: 'Rename folder');
      if (name != null && name.trim().isNotEmpty) {
        await ref.read(folderActionsProvider).renameFolder(folder.id, name);
      }
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete folder?'),
        content: Text('This only removes "${folder.name}" — your audio files are not affected.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(folderActionsProvider).deleteFolder(folder.id);
    }
  }
}
