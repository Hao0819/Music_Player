import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/duration_format.dart';
import '../../../services/download/ytdlp_service.dart';
import '../providers/download_providers.dart';

/// Pulls audio off a link with the embedded yt-dlp and files it into the
/// library. Android only — see [YtdlpService].
class DownloadScreen extends ConsumerStatefulWidget {
  const DownloadScreen({super.key});

  @override
  ConsumerState<DownloadScreen> createState() => _DownloadScreenState();
}

class _DownloadScreenState extends ConsumerState<DownloadScreen> {
  final _urlController = TextEditingController();
  String _format = 'mp3';

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ready = ref.watch(ytdlpReadyProvider);
    final tasks = ref.watch(downloadQueueProvider);
    final historyHidden = ref.watch(downloadHistoryHiddenProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Download audio'),
        actions: [
          if (tasks.isNotEmpty)
            PopupMenuButton<_HistoryAction>(
              onSelected: (action) => _onHistoryAction(action, tasks),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: _HistoryAction.toggleVisibility,
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(historyHidden ? Icons.visibility : Icons.visibility_off),
                    title: Text(historyHidden ? 'Show history' : 'Hide history'),
                  ),
                ),
                PopupMenuItem(
                  value: _HistoryAction.clear,
                  // Running downloads stay put — clearing one would leave a
                  // process writing a file nothing is tracking any more.
                  enabled: tasks.any((task) => task.isFinished),
                  child: const ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.delete_sweep_outlined),
                    title: Text('Clear history'),
                  ),
                ),
              ],
            ),
        ],
      ),
      body: ready.when(
        loading: () => const _Centered(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Unpacking the downloader…'),
              SizedBox(height: 4),
              Text('Only takes this long the first time.'),
            ],
          ),
        ),
        error: (error, _) => _Centered(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('$error', textAlign: TextAlign.center),
          ),
        ),
        data: (_) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            TextField(
              controller: _urlController,
              keyboardType: TextInputType.text,
              autocorrect: false,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                labelText: 'Search or paste a link',
                hintText: 'Song name, or a link you copied',
                prefixIcon: Icon(_isLink ? Icons.link : Icons.search),
                border: const OutlineInputBorder(),
                suffixIcon: _urlController.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear',
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _urlController.clear();
                          ref.read(ytdlpSearchProvider.notifier).clear();
                          setState(() {});
                        },
                      ),
              ),
              // Typing is what flips the button between Search and Download,
              // so the field has to rebuild as it changes.
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'mp3', label: Text('MP3')),
                ButtonSegment(value: 'm4a', label: Text('M4A')),
                ButtonSegment(value: 'opus', label: Text('Opus')),
              ],
              selected: {_format},
              onSelectionChanged: (selection) => setState(() => _format = selection.first),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _submit,
              icon: Icon(_isLink ? Icons.download : Icons.search),
              label: Text(_isLink ? 'Download audio' : 'Search'),
            ),
            const SizedBox(height: 8),
            const _VersionRow(),
            _RecentSearches(onSelected: _useRecent),
            _SearchResults(onDownload: _start),
            const Divider(height: 32),
            if (tasks.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Text(
                  'Downloads you start will show up here, then appear in your library.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else if (historyHidden)
              // Anything still running stays visible even when the history is
              // collapsed, so a download in flight can't be hidden by accident.
              ...[
                for (final task in tasks.where((task) => !task.isFinished))
                  _DownloadTile(task: task),
                _HiddenHistoryRow(
                  count: tasks.where((task) => task.isFinished).length,
                  onShow: () => ref.read(downloadHistoryHiddenProvider.notifier).toggle(),
                ),
              ]
            else
              for (final task in tasks) _DownloadTile(task: task),
          ],
        ),
      ),
    );
  }

  void _onHistoryAction(_HistoryAction action, List<DownloadTask> tasks) {
    switch (action) {
      case _HistoryAction.toggleVisibility:
        ref.read(downloadHistoryHiddenProvider.notifier).toggle();
      case _HistoryAction.clear:
        final cleared = tasks.where((task) => task.isFinished).length;
        ref.read(downloadQueueProvider.notifier).clearFinished();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cleared $cleared download${cleared == 1 ? '' : 's'}')),
        );
    }
  }

  /// Anything that parses as an http(s) URL is treated as something to
  /// download; everything else is search terms. Keeping both on one field
  /// means a link you copied from YouTube still works when search comes up
  /// short.
  bool get _isLink {
    final text = _urlController.text.trim();
    if (text.isEmpty || text.contains(' ')) return false;
    final uri = Uri.tryParse(text);
    return uri != null && uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
  }

  Future<void> _submit() async {
    if (_isLink) {
      await _start(_urlController.text);
      return;
    }

    FocusScope.of(context).unfocus();
    await ref.read(ytdlpSearchProvider.notifier).run(_urlController.text);
  }

  /// Re-runs a search from the recent list.
  Future<void> _useRecent(String query) async {
    _urlController.text = query;
    // The field owns the Search/Download button and its own clear icon, so
    // filling it from outside still has to rebuild it.
    setState(() {});
    await _submit();
  }

  Future<void> _start(String url) async {
    final error = await ref.read(downloadQueueProvider.notifier).start(url, format: _format);
    if (!mounted) return;

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    // The query and its results stay exactly where they are. Taking two or
    // three songs out of one search is how this screen actually gets used,
    // and clearing the field on the first download meant retyping the same
    // thing for every one after it — the X in the field is what clears them.
    //
    // Which does mean the new row is below the results rather than in view,
    // so the snack bar is the confirmation that anything happened at all.
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Download started'), duration: Duration(seconds: 2)),
    );
  }
}

/// The last few search terms, offered under the field so a query can be run
/// again without retyping it.
class _RecentSearches extends ConsumerWidget {
  const _RecentSearches({required this.onSelected});

  final Future<void> Function(String query) onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recent = ref.watch(recentDownloadSearchesProvider);
    final results = ref.watch(ytdlpSearchProvider);
    final theme = Theme.of(context);

    // Stood down while a search is in flight or its results are on screen:
    // otherwise the list you just asked for and the list of things you asked
    // for earlier are stacked in the same place under the field.
    final hidden = switch (results) {
      AsyncLoading() => true,
      AsyncData(:final value) => value.isNotEmpty,
      _ => false,
    };
    if (recent.isEmpty || hidden) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: Text('Recent searches', style: theme.textTheme.titleSmall)),
            TextButton(
              onPressed: ref.read(recentDownloadSearchesProvider.notifier).clear,
              child: const Text('Clear'),
            ),
          ],
        ),
        for (final query in recent)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            leading: Icon(Icons.history, size: 20, color: theme.colorScheme.onSurfaceVariant),
            title: Text(query, maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: IconButton(
              tooltip: 'Remove',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.close, size: 18),
              onPressed: () => ref.read(recentDownloadSearchesProvider.notifier).forget(query),
            ),
            onTap: () => onSelected(query),
          ),
      ],
    );
  }
}

class _VersionRow extends ConsumerWidget {
  const _VersionRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final version = ref.watch(ytdlpVersionProvider);
    final theme = Theme.of(context);

    return Row(
      children: [
        Expanded(
          child: Text(
            switch (version) {
              AsyncData(:final value) => 'yt-dlp ${value ?? 'unknown'}',
              AsyncError() => 'yt-dlp unavailable',
              _ => 'Checking yt-dlp…',
            },
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
        TextButton(
          // Sites change how they serve media often enough to break the
          // extractor between app releases; this updates it without one.
          onPressed: () async {
            final messenger = ScaffoldMessenger.of(context);
            messenger.showSnackBar(const SnackBar(content: Text('Updating yt-dlp…')));
            try {
              final status = await ref.read(ytdlpServiceProvider).updateYtdlp();
              ref.invalidate(ytdlpVersionProvider);
              messenger.showSnackBar(SnackBar(content: Text('yt-dlp: ${status ?? 'updated'}')));
            } on Object catch (error) {
              messenger.showSnackBar(SnackBar(content: Text('Update failed: $error')));
            }
          },
          child: const Text('Update'),
        ),
      ],
    );
  }
}

class _DownloadTile extends ConsumerWidget {
  const _DownloadTile({required this.task});

  final DownloadTask task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    final (icon, color) = switch (task.status) {
      DownloadStatus.completed => (Icons.check_circle, theme.colorScheme.primary),
      DownloadStatus.failed => (Icons.error_outline, theme.colorScheme.error),
      DownloadStatus.cancelled => (Icons.cancel_outlined, theme.colorScheme.onSurfaceVariant),
      _ => (Icons.downloading, theme.colorScheme.onSurfaceVariant),
    };

    final card = Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    task.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                if (!task.isFinished)
                  IconButton(
                    tooltip: 'Cancel',
                    icon: const Icon(Icons.close),
                    onPressed: () => ref.read(downloadQueueProvider.notifier).cancel(task.id),
                  ),
              ],
            ),
            if (!task.isFinished) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(
                // yt-dlp reports -1 until it has a total size to divide by.
                value: task.percent <= 0 ? null : task.percent / 100,
              ),
              const SizedBox(height: 6),
              Text(
                task.eta > Duration.zero
                    ? '${task.percent.toStringAsFixed(0)}% · ${formatDuration(task.eta)} left'
                    : task.detail,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ] else if (task.detail.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                task.status == DownloadStatus.completed ? 'Added to your library' : task.detail,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: task.status == DownloadStatus.failed
                      ? theme.colorScheme.error
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );

    // A running download isn't dismissable — losing the row would leave its
    // process writing a file with nothing tracking it. Cancel it first.
    if (!task.isFinished) return card;

    return Dismissible(
      key: ValueKey(task.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => ref.read(downloadQueueProvider.notifier).remove(task.id),
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.delete_outline, color: theme.colorScheme.onErrorContainer),
      ),
      child: card,
    );
  }
}

enum _HistoryAction { toggleVisibility, clear }

/// Results from the search box, each one tappable to download straight away.
class _SearchResults extends ConsumerWidget {
  const _SearchResults({required this.onDownload});

  final Future<void> Function(String url) onDownload;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final results = ref.watch(ytdlpSearchProvider);
    final theme = Theme.of(context);

    return switch (results) {
      AsyncLoading() => const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Column(
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 12),
              // Searching scrapes rather than calling an API, so it is slower
              // than a search box usually feels.
              Text('Searching…'),
            ],
          ),
        ),
      AsyncError(:final error) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            children: [
              Text(
                'Search failed',
                style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.error),
              ),
              const SizedBox(height: 4),
              Text(
                '$error',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Text(
                'You can still paste a link from YouTube instead.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      AsyncData(:final value) when value.isEmpty => const SizedBox.shrink(),
      AsyncData(:final value) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            Text('${value.length} results', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            for (final result in value)
              _SearchResultTile(result: result, onDownload: () => onDownload(result.url)),
          ],
        ),
    };
  }
}

class _SearchResultTile extends StatelessWidget {
  const _SearchResultTile({required this.result, required this.onDownload});

  final YtdlpSearchResult result;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          width: 64,
          height: 48,
          child: result.thumbnail.isEmpty
              ? ColoredBox(color: theme.colorScheme.surfaceContainerHighest)
              : Image.network(
                  result.thumbnail,
                  fit: BoxFit.cover,
                  // A dead thumbnail URL must not take the row with it.
                  errorBuilder: (_, _, _) =>
                      ColoredBox(color: theme.colorScheme.surfaceContainerHighest),
                ),
        ),
      ),
      title: Text(result.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        [
          if (result.uploader.isNotEmpty) result.uploader,
          if (result.duration > Duration.zero) formatDuration(result.duration),
        ].join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: IconButton(
        tooltip: 'Download',
        icon: const Icon(Icons.download),
        onPressed: onDownload,
      ),
      onTap: onDownload,
    );
  }
}

/// Stands in for the collapsed history so it's obvious something is hidden
/// rather than simply gone.
class _HiddenHistoryRow extends StatelessWidget {
  const _HiddenHistoryRow({required this.count, required this.onShow});

  final int count;
  final VoidCallback onShow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.visibility_off_outlined, size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Text(
            '$count download${count == 1 ? '' : 's'} hidden',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          TextButton(onPressed: onShow, child: const Text('Show')),
        ],
      ),
    );
  }
}

class _Centered extends StatelessWidget {
  const _Centered({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Center(child: child);
}
