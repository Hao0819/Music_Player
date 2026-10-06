import 'package:flutter/material.dart';

/// Asks for a playlist's name.
///
/// This used to pick a colour too. The app has no colour of its own any more —
/// everything is drawn in black and white, and the only hue on screen is album
/// art — so a swatch grid had nothing left to tint. A playlist is identified
/// by its cover instead.
Future<String?> promptForFolder(
  BuildContext context, {
  String? initialName,
  String title = 'New playlist',
}) {
  return showDialog<String>(
    context: context,
    builder: (context) => _FolderDialog(initialName: initialName, title: title),
  );
}

class _FolderDialog extends StatefulWidget {
  const _FolderDialog({required this.initialName, required this.title});

  final String? initialName;
  final String title;

  @override
  State<_FolderDialog> createState() => _FolderDialogState();
}

class _FolderDialogState extends State<_FolderDialog> {
  late final _controller = TextEditingController(text: widget.initialName ?? '');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    Navigator.pop(context, name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(hintText: 'Playlist name'),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }
}
