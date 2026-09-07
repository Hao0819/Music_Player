import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/duration_format.dart';
import '../../../domain/library_filter_state.dart';
import '../providers/search_providers.dart';

Future<void> showFilterPanel(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => const _FilterPanel(),
  );
}

class _FilterPanel extends ConsumerWidget {
  const _FilterPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(libraryFilterProvider);
    final notifier = ref.read(libraryFilterProvider.notifier);
    final formats = ref.watch(availableFormatsProvider);
    final theme = Theme.of(context);

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('Filters', style: theme.textTheme.titleLarge),
                  const Spacer(),
                  TextButton(onPressed: notifier.reset, child: const Text('Reset')),
                ],
              ),
              const SizedBox(height: 8),
              if (formats.isNotEmpty) ...[
                Text('Format', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final format in formats)
                      FilterChip(
                        label: Text(format),
                        selected: filter.formats.contains(format),
                        onSelected: (_) => notifier.toggleFormat(format),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
              Text('Duration', style: theme.textTheme.titleSmall),
              Text(
                _durationRangeLabel(filter),
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              RangeSlider(
                min: 0,
                max: LibraryFilterState.maxDurationBound.inSeconds.toDouble(),
                divisions: 40,
                values: RangeValues(
                  filter.minDuration.inSeconds.toDouble(),
                  filter.maxDuration.inSeconds.toDouble(),
                ),
                labels: RangeLabels(
                  formatDuration(filter.minDuration),
                  filter.hasUpperDurationLimit ? formatDuration(filter.maxDuration) : '20:00+',
                ),
                onChanged: (values) => notifier.setDurationRange(
                  Duration(seconds: values.start.round()),
                  Duration(seconds: values.end.round()),
                ),
              ),
              const SizedBox(height: 12),
              Text('Organization', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              SegmentedButton<CategorizedFilter>(
                segments: const [
                  ButtonSegment(value: CategorizedFilter.any, label: Text('Any')),
                  ButtonSegment(value: CategorizedFilter.categorized, label: Text('In a folder')),
                  ButtonSegment(value: CategorizedFilter.uncategorized, label: Text('Unfiled')),
                ],
                selected: {filter.categorized},
                onSelectionChanged: (selection) => notifier.setCategorized(selection.first),
              ),
              const SizedBox(height: 20),
              Text('Recent', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              SegmentedButton<RecencyFilter>(
                segments: const [
                  ButtonSegment(value: RecencyFilter.any, label: Text('Any')),
                  ButtonSegment(value: RecencyFilter.recentlyAdded, label: Text('Added')),
                  ButtonSegment(value: RecencyFilter.recentlyPlayed, label: Text('Played')),
                ],
                selected: {filter.recency},
                onSelectionChanged: (selection) => notifier.setRecency(selection.first),
              ),
              const SizedBox(height: 8),
              Text(
                'Recent covers the last ${LibraryFilterState.recencyWindow.inDays} days.',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _durationRangeLabel(LibraryFilterState filter) {
    final upper = filter.hasUpperDurationLimit ? formatDuration(filter.maxDuration) : '20:00+';
    return '${formatDuration(filter.minDuration)} – $upper';
  }
}
