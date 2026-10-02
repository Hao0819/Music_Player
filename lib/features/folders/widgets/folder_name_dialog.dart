import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// What the folder dialog came back with. A null [colorValue] means the folder
/// takes the colour derived from its name.
typedef FolderEdit = ({String name, int? colorValue});

/// Asks for a folder's name and colour together.
///
/// One dialog rather than a separate "recolour" action: both are properties of
/// the folder you are already naming, and a folder's colour is worth choosing
/// at the moment you make it rather than discovering later that one was
/// assigned for you.
Future<FolderEdit?> promptForFolder(
  BuildContext context, {
  String? initialName,
  int? initialColor,
  String title = 'New folder',
}) {
  return showDialog<FolderEdit>(
    context: context,
    builder: (context) => _FolderDialog(
      initialName: initialName,
      initialColor: initialColor,
      title: title,
    ),
  );
}

class _FolderDialog extends StatefulWidget {
  const _FolderDialog({
    required this.initialName,
    required this.initialColor,
    required this.title,
  });

  final String? initialName;
  final int? initialColor;
  final String title;

  @override
  State<_FolderDialog> createState() => _FolderDialogState();
}

class _FolderDialogState extends State<_FolderDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialName);
  late int? _colorValue = widget.initialColor;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    Navigator.pop(context, (name: name, colorValue: _colorValue));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(hintText: 'Folder name'),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 24),
          Text('Colour', style: theme.textTheme.titleSmall),
          const SizedBox(height: 10),
          // Listens to the name so the "derived" swatch previews the colour
          // that choosing it would actually give.
          ValueListenableBuilder(
            valueListenable: _controller,
            builder: (context, value, _) => _Swatches(
              name: value.text,
              selected: _colorValue,
              onSelected: (color) => setState(() => _colorValue = color),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }
}

class _Swatches extends StatelessWidget {
  const _Swatches({required this.name, required this.selected, required this.onSelected});

  final String name;
  final int? selected;
  final ValueChanged<int?> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        // Leading swatch returns the folder to a name-derived colour, so the
        // automatic behaviour stays reachable after you have overridden it.
        _Swatch(
          color: AppTheme.folderColor(name, null),
          selected: selected == null,
          auto: true,
          onTap: () => onSelected(null),
        ),
        for (final color in AppTheme.folderPalette)
          _Swatch(
            color: color,
            selected: selected == color.toARGB32(),
            onTap: () => onSelected(color.toARGB32()),
          ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.selected,
    required this.onTap,
    this.auto = false,
  });

  final Color color;
  final bool selected;
  final bool auto;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      selected: selected,
      button: true,
      label: auto ? 'Colour from the name' : null,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppTheme.accentGradient(color),
            border: Border.all(
              color: selected ? scheme.onSurface : Colors.transparent,
              width: 2.5,
            ),
          ),
          child: Icon(
            // The auto swatch is marked rather than relying on position, which
            // says nothing once a colour has been chosen.
            auto ? Icons.auto_awesome : (selected ? Icons.check : null),
            size: auto ? 15 : 18,
            color: AppTheme.onAccent(color),
          ),
        ),
      ),
    );
  }
}
