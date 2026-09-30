import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/settings_repository.dart';
import '../../../services/download/ytdlp_service.dart';
import '../../library/providers/library_providers.dart';

final ytdlpServiceProvider = Provider<YtdlpService>((ref) => YtdlpService());

/// Whether the download screen's history list is collapsed. Persisted, so it
/// stays the way the user left it.
class DownloadHistoryHiddenNotifier extends Notifier<bool> {
  @override
  bool build() => ref.read(settingsRepositoryProvider).downloadHistoryHidden;

  Future<void> toggle() async {
    state = !state;
    await ref.read(settingsRepositoryProvider).updateDownloadHistoryHidden(state);
  }
}

final downloadHistoryHiddenProvider =
    NotifierProvider<DownloadHistoryHiddenNotifier, bool>(DownloadHistoryHiddenNotifier.new);

/// Unpacks the Python runtime once per app run. Kept as a provider so the
/// download screen can show the several-second first-run cost as a normal
/// loading state instead of appearing frozen.
final ytdlpReadyProvider = FutureProvider<bool>((ref) {
  return ref.watch(ytdlpServiceProvider).init();
});

/// The yt-dlp build currently on disk, which is not the one shipped in the APK
/// once the user has updated it.
final ytdlpVersionProvider = FutureProvider<String?>((ref) async {
  await ref.watch(ytdlpReadyProvider.future);
  return ref.watch(ytdlpServiceProvider).version();
});

enum DownloadStatus { preparing, running, completed, failed, cancelled }

class DownloadTask {
  const DownloadTask({
    required this.id,
    required this.url,
    required this.title,
    this.status = DownloadStatus.preparing,
    this.percent = 0,
    this.eta = Duration.zero,
    this.detail = '',
    this.path,
  });

  final String id;
  final String url;
  final String title;
  final DownloadStatus status;
  final double percent;
  final Duration eta;

  /// Last yt-dlp output line, or the failure message once it has one.
  final String detail;
  final String? path;

  bool get isFinished => status != DownloadStatus.preparing && status != DownloadStatus.running;

  DownloadTask copyWith({
    String? title,
    DownloadStatus? status,
    double? percent,
    Duration? eta,
    String? detail,
    String? path,
  }) {
    return DownloadTask(
      id: id,
      url: url,
      title: title ?? this.title,
      status: status ?? this.status,
      percent: percent ?? this.percent,
      eta: eta ?? this.eta,
      detail: detail ?? this.detail,
      path: path ?? this.path,
    );
  }
}

/// Every download this app run has started, newest first.
class DownloadQueueNotifier extends Notifier<List<DownloadTask>> {
  StreamSubscription<YtdlpEvent>? _subscription;

  @override
  List<DownloadTask> build() {
    final service = ref.watch(ytdlpServiceProvider);

    try {
      _subscription = service.events.listen(_apply);
      ref.onDispose(() => _subscription?.cancel());
    } on YtdlpUnavailable {
      // Nothing to listen to off Android; the screen reports that itself.
    }

    return const [];
  }

  Future<String?> start(String url, {String format = 'mp3'}) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return 'Paste a link first';

    try {
      final id = await ref.read(ytdlpServiceProvider).startDownload(trimmed, format: format);
      if (id == null) return 'Could not start the download';

      state = [
        DownloadTask(id: id, url: trimmed, title: trimmed),
        ...state,
      ];
      return null;
    } on YtdlpUnavailable catch (error) {
      return error.toString();
    } on Object catch (error) {
      return error.toString();
    }
  }

  Future<void> cancel(String id) async {
    try {
      await ref.read(ytdlpServiceProvider).cancel(id);
    } on Object {
      // The event stream still reports how it actually ended.
    }
  }

  /// Drops finished rows; running downloads are left alone, since removing
  /// one would orphan a process that is still writing a file.
  void clearFinished() {
    state = state.where((task) => !task.isFinished).toList();
  }

  /// Drops a single finished row. Running downloads have to be cancelled
  /// first, for the same reason [clearFinished] leaves them in place.
  void remove(String id) {
    state = state.where((task) => task.id != id || !task.isFinished).toList();
  }

  void _apply(YtdlpEvent event) {
    final index = state.indexWhere((task) => task.id == event.id);
    if (index < 0) return;

    final task = state[index];
    final updated = switch (event) {
      YtdlpProgress(:final percent, :final eta, :final line) => task.copyWith(
          status: DownloadStatus.running,
          percent: percent,
          eta: eta,
          detail: line,
        ),
      YtdlpDone(:final path, :final title) => task.copyWith(
          status: DownloadStatus.completed,
          percent: 100,
          title: title.isEmpty ? task.title : title,
          path: path,
          detail: path ?? '',
        ),
      YtdlpFailed(:final message) =>
        task.copyWith(status: DownloadStatus.failed, detail: message),
      YtdlpCancelled() =>
        task.copyWith(status: DownloadStatus.cancelled, detail: 'Cancelled'),
    };

    state = [...state]..[index] = updated;

    // A finished file is now in MediaStore, so pull it into the library
    // without making the user hit rescan.
    if (event is YtdlpDone) {
      ref.read(libraryScanProvider.notifier).refresh();
    }
  }
}

final downloadQueueProvider =
    NotifierProvider<DownloadQueueNotifier, List<DownloadTask>>(DownloadQueueNotifier.new);
