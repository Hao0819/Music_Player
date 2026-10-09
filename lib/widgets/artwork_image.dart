import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:on_audio_query/on_audio_query.dart' show ArtworkType;

import '../features/library/providers/library_providers.dart';
import 'fallback_cover.dart';

/// Artwork loader that fetches once per track and caches the result.
///
/// Deliberately *not* `QueryArtworkWidget`: that builds its `FutureBuilder`
/// future inside `build()`, so it re-queries the platform channel on every
/// rebuild. Widgets that rebuild on the playback position tick (the mini
/// player) flooded the channel badly enough to freeze the UI thread.
class ArtworkImage extends ConsumerStatefulWidget {
  const ArtworkImage({
    super.key,
    required this.trackId,
    required this.size,
    this.borderRadius = 8,
    this.iconSize,
    this.placeholderTint = 0.07,
  });

  final int? trackId;
  final double size;
  final double borderRadius;
  final double? iconSize;

  /// How much accent to blend into the no-cover placeholder.
  ///
  /// Scales with how the placeholder is used rather than being one constant:
  /// in a list these blocks appear a dozen at a time and any real colour reads
  /// as noise, while on Now Playing a single one fills a third of the screen
  /// and at list strength it reads as a hole rather than as an object.
  final double placeholderTint;

  @override
  ConsumerState<ArtworkImage> createState() => _ArtworkImageState();
}

/// Artwork for one track, fetched once per id and kept.
///
/// Public and cache-backed because more than one thing needs the answer now: a
/// row draws it, and a playlist cover has to ask several tracks in turn which
/// of them actually has a picture. Going through the widget for that would
/// mean building one per candidate.
Future<Uint8List?> loadArtwork(WidgetRef ref, int id) => _ArtworkCache.load(ref, id);

class _ArtworkCache {
  static const _maxEntries = 150;
  static final Map<int, Uint8List?> _cache = {};

  static bool contains(int id) => _cache.containsKey(id);
  static Uint8List? peek(int id) => _cache[id];

  static Future<Uint8List?> load(WidgetRef ref, int id) async {
    if (_cache.containsKey(id)) return _cache[id];

    final bytes = await ref.read(onAudioQueryProvider).queryArtwork(id, ArtworkType.AUDIO, size: 400);

    if (_cache.length >= _maxEntries) _cache.remove(_cache.keys.first);
    return _cache[id] = bytes;
  }
}

class _ArtworkImageState extends ConsumerState<ArtworkImage> {
  Uint8List? _bytes;

  /// Whether the artwork query has answered for the current track.
  ///
  /// The stand-in cover waits on this. Drawn before the answer is in, it would
  /// put a photo in front of every track that does have a picture for as long
  /// as the platform channel took to reply — a flash of the wrong sleeve,
  /// which is a worse first frame than the plain block it replaced.
  bool _resolved = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(ArtworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trackId != widget.trackId) {
      _bytes = null;
      _resolved = false;
      _load();
    }
  }

  Future<void> _load() async {
    final id = widget.trackId;
    if (id == null) return;

    if (_ArtworkCache.contains(id)) {
      setState(() {
        _bytes = _ArtworkCache.peek(id);
        _resolved = true;
      });
      return;
    }

    final bytes = await _ArtworkCache.load(ref, id);
    if (!mounted) return;
    setState(() {
      _bytes = bytes;
      _resolved = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bytes = _bytes;

    if (bytes == null || bytes.isEmpty) {
      final id = widget.trackId;

      // A track the scan knows about but that carries no picture gets one of
      // the bundled sleeves instead of a blank. Half a ripped library has no
      // embedded artwork, and a screen of identical grey squares tells the
      // user nothing about which row is which.
      if (_resolved && id != null) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          child: FallbackCover(seed: id, size: widget.size),
        );
      }

      // Still waiting, or there is no track at all — the mini player draws
      // this before anything has been played. A plain record, not
      // `music_off`: a struck-through note reads as "muted" or "cannot play",
      // which is wrong for a track that plays perfectly well.
      return Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          color: scheme.surfaceContainerHigh,
        ),
        child: Icon(
          Icons.album,
          size: widget.iconSize ?? widget.size * 0.45,
          color: scheme.outline,
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: Image.memory(
        bytes,
        width: widget.size,
        height: widget.size,
        fit: BoxFit.cover,
        gaplessPlayback: true,
      ),
    );
  }
}
