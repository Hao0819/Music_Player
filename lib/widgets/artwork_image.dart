import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:on_audio_query/on_audio_query.dart' show ArtworkType;

import '../features/library/providers/library_providers.dart';

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

class _ArtworkImageState extends ConsumerState<ArtworkImage> {
  static const _maxCacheEntries = 150;
  static final Map<int, Uint8List?> _cache = {};

  Uint8List? _bytes;

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
      _load();
    }
  }

  Future<void> _load() async {
    final id = widget.trackId;
    if (id == null) return;

    if (_cache.containsKey(id)) {
      setState(() => _bytes = _cache[id]);
      return;
    }

    final bytes = await ref.read(onAudioQueryProvider).queryArtwork(id, ArtworkType.AUDIO, size: 400);
    if (_cache.length >= _maxCacheEntries) {
      _cache.remove(_cache.keys.first);
    }
    _cache[id] = bytes;

    if (!mounted) return;
    setState(() => _bytes = bytes);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bytes = _bytes;

    if (bytes == null || bytes.isEmpty) {
      // Still reads as "this track has no cover" — outlined and muted, not a
      // stand-in picture. The faint tint only keeps a screenful of them from
      // being a wall of flat grey.
      return Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          border: Border.all(color: scheme.outlineVariant),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              // Strength comes from the caller — see [placeholderTint]. The
              // second stop is a fraction of the first so the block has some
              // internal shape instead of being one flat fill.
              Color.alphaBlend(
                scheme.primary.withValues(alpha: widget.placeholderTint),
                scheme.surfaceContainerHighest,
              ),
              Color.alphaBlend(
                scheme.primary.withValues(alpha: widget.placeholderTint * 0.3),
                scheme.surfaceContainerHighest,
              ),
            ],
          ),
        ),
        // Not `music_off`: a struck-through note means "muted" or "cannot
        // play" to anyone reading it, which is actively wrong — and at Now
        // Playing size it filled half the screen with a stop sign for a track
        // that was playing fine. A plain record says "no cover" instead.
        child: Icon(
          Icons.album_outlined,
          size: widget.iconSize ?? widget.size * 0.4,
          color: scheme.onSurfaceVariant.withValues(alpha: 0.55),
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
