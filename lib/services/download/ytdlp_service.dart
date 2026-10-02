import 'package:flutter/services.dart';

/// Talks to the embedded yt-dlp (see `YtdlpBridge.kt`).
///
/// Android only — the runtime it drives is a Python build packaged in the APK,
/// so every call reports [unavailable] rather than throwing on other
/// platforms.
class YtdlpService {
  static const _methods = MethodChannel('music_player/ytdlp');
  static const _events = EventChannel('music_player/ytdlp/events');

  Stream<YtdlpEvent>? _eventStream;

  /// Progress, completion and failure for every running download, keyed by the
  /// id [startDownload] returned. Broadcast, so several listeners can watch.
  Stream<YtdlpEvent> get events {
    return _eventStream ??= _events
        .receiveBroadcastStream()
        .map((event) => YtdlpEvent.fromMap(event as Map<Object?, Object?>))
        .where((event) => event != null)
        .cast<YtdlpEvent>();
  }

  /// Unpacks the Python runtime and FFmpeg. Slow on first run and a no-op
  /// afterwards, so it's safe to call whenever the download UI opens.
  Future<bool> init() => _call<bool>('init').then((value) => value ?? false);

  Future<String?> version() => _call<String>('version');

  /// Fetches a newer yt-dlp than the one shipped in the APK. Returns the
  /// update status string the native side reported.
  Future<String?> updateYtdlp() => _call<String>('updateYtdlp');

  Future<YtdlpMediaInfo?> fetchInfo(String url) async {
    final map = await _call<Map<Object?, Object?>>('fetchInfo', {'url': url});
    return map == null ? null : YtdlpMediaInfo.fromMap(map);
  }

  /// Searches through yt-dlp's own `ytsearch` prefix — no API key, no quota.
  /// Takes a few seconds, since it is scraping rather than hitting an API.
  Future<List<YtdlpSearchResult>> search(String query, {int limit = 20}) async {
    final rows = await _call<List<Object?>>('search', {'query': query, 'limit': limit});
    if (rows == null) return const [];

    return rows
        .whereType<Map<Object?, Object?>>()
        .map(YtdlpSearchResult.fromMap)
        .where((result) => result.url.isNotEmpty)
        .toList();
  }

  /// Starts a download and returns its id straight away; watch [events] for
  /// what happens next.
  Future<String?> startDownload(String url, {String format = 'mp3'}) {
    return _call<String>('startDownload', {'url': url, 'format': format});
  }

  Future<void> cancel(String id) => _call<bool>('cancel', {'id': id});

  Future<T?> _call<T>(String method, [Map<String, Object?>? arguments]) async {
    try {
      return await _methods.invokeMethod<T>(method, arguments);
    } on MissingPluginException {
      throw const YtdlpUnavailable();
    }
  }
}

/// Thrown when the native side isn't there at all — every platform but
/// Android, where no Python runtime is packaged.
class YtdlpUnavailable implements Exception {
  const YtdlpUnavailable();

  @override
  String toString() => 'Downloading is only available on Android.';
}

class YtdlpMediaInfo {
  const YtdlpMediaInfo({
    required this.id,
    required this.title,
    required this.uploader,
    required this.duration,
    required this.thumbnail,
  });

  factory YtdlpMediaInfo.fromMap(Map<Object?, Object?> map) {
    return YtdlpMediaInfo(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? 'Unknown title',
      uploader: map['uploader'] as String? ?? '',
      duration: Duration(seconds: (map['duration'] as num?)?.toInt() ?? 0),
      thumbnail: map['thumbnail'] as String? ?? '',
    );
  }

  final String id;
  final String title;
  final String uploader;
  final Duration duration;
  final String thumbnail;
}

/// One hit from a `ytsearch` query.
class YtdlpSearchResult {
  const YtdlpSearchResult({
    required this.id,
    required this.title,
    required this.uploader,
    required this.duration,
    required this.thumbnail,
    required this.url,
  });

  factory YtdlpSearchResult.fromMap(Map<Object?, Object?> map) {
    return YtdlpSearchResult(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? 'Untitled',
      uploader: map['uploader'] as String? ?? '',
      duration: Duration(seconds: (map['duration'] as num?)?.toInt() ?? 0),
      thumbnail: map['thumbnail'] as String? ?? '',
      url: map['url'] as String? ?? '',
    );
  }

  final String id;
  final String title;
  final String uploader;
  final Duration duration;
  final String thumbnail;
  final String url;
}

/// One message from a running download.
sealed class YtdlpEvent {
  const YtdlpEvent(this.id);

  /// Returns null for an event shape this build doesn't know, so an older
  /// Dart side can't be broken by a newer native one.
  static YtdlpEvent? fromMap(Map<Object?, Object?> map) {
    final id = map['id'] as String? ?? '';
    return switch (map['type'] as String?) {
      'progress' => YtdlpProgress(
          id,
          percent: (map['progress'] as num?)?.toDouble() ?? 0,
          eta: Duration(seconds: (map['eta'] as num?)?.toInt() ?? 0),
          line: map['line'] as String? ?? '',
        ),
      'done' => YtdlpDone(
          id,
          path: map['path'] as String?,
          title: map['title'] as String? ?? '',
        ),
      'error' => YtdlpFailed(id, message: map['message'] as String? ?? 'Download failed'),
      'cancelled' => YtdlpCancelled(id),
      _ => null,
    };
  }

  final String id;
}

class YtdlpProgress extends YtdlpEvent {
  const YtdlpProgress(super.id, {required this.percent, required this.eta, required this.line});

  /// 0–100, as yt-dlp reports it.
  final double percent;
  final Duration eta;

  /// The raw yt-dlp output line, useful when a download stalls.
  final String line;
}

class YtdlpDone extends YtdlpEvent {
  const YtdlpDone(super.id, {required this.path, required this.title});

  /// Where the finished file landed, once published to MediaStore.
  final String? path;
  final String title;
}

class YtdlpFailed extends YtdlpEvent {
  const YtdlpFailed(super.id, {required this.message});

  final String message;
}

class YtdlpCancelled extends YtdlpEvent {
  const YtdlpCancelled(super.id);
}
