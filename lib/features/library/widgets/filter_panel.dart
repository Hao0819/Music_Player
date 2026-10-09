import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/library_filter_notifier.dart';
import '../../../core/utils/duration_format.dart';
import '../../../domain/library_filter_state.dart';
import '../providers/library_providers.dart';

/// [provider] decides whose filters are being edited. Only the Library tab
/// has filters now, but the panel is still passed the provider rather than
/// reaching for one, so a second filtered list costs nothing to add.
Future<void> showFilterPanel(BuildContext context, LibraryFilterProvider provider) {
  return showModalBottomSheet(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => _FilterPanel(provider: provider),
  );
}

class _FilterPanel extends ConsumerWidget {
  const _FilterPanel({required this.provider});

  final LibraryFilterProvider provider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(provider);
    final notifier = ref.read(provider.notifier);
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
              Text('Playlists', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              // Chips, not a SegmentedButton. This is where the Library's
              // three standalone chips moved to, and they had to look like the
              // filters they always were rather than like a third control.
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final option in const [
                    (CategorizedFilter.any, 'All'),
                    (CategorizedFilter.categorized, 'In a playlist'),
                    (CategorizedFilter.uncategorized, 'Not in a playlist'),
                  ])
                    ChoiceChip(
                      label: Text(option.$2),
                      selected: filter.categorized == option.$1,
                      showCheckmark: false,
                      onSelected: (_) => notifier.setCategorized(option.$1),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Text('Recent', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final option in const [
                    (RecencyFilter.any, 'Any'),
                    (RecencyFilter.recentlyAdded, 'Added'),
                    (RecencyFilter.recentlyPlayed, 'Played'),
                  ])
                    ChoiceChip(
                      label: Text(option.$2),
                      selected: filter.recency == option.$1,
                      showCheckmark: false,
                      onSelected: (_) => notifier.setRecency(option.$1),
                    ),
                ],
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
