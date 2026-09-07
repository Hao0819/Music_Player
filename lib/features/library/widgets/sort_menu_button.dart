import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/track.dart';
import '../providers/library_providers.dart';

class SortMenuButton extends ConsumerWidget {
  const SortMenuButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sort = ref.watch(librarySortProvider);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: sort.ascending ? 'Ascending' : 'Descending',
          icon: Icon(sort.ascending ? Icons.arrow_upward : Icons.arrow_downward),
          onPressed: () => ref.read(librarySortProvider.notifier).toggleDirection(),
        ),
        PopupMenuButton<LibrarySortField>(
          tooltip: 'Sort by',
          icon: const Icon(Icons.sort),
          initialValue: sort.field,
          onSelected: (field) => ref.read(librarySortProvider.notifier).setField(field),
          itemBuilder: (context) => [
            for (final field in LibrarySortField.values)
              CheckedPopupMenuItem(
                value: field,
                checked: field == sort.field,
                child: Text(_label(field)),
              ),
          ],
        ),
      ],
    );
  }

  String _label(LibrarySortField field) => switch (field) {
        LibrarySortField.title => 'Title',
        LibrarySortField.artist => 'Artist',
        LibrarySortField.album => 'Album',
        LibrarySortField.dateAdded => 'Date added',
        LibrarySortField.duration => 'Duration',
      };
}
