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
  });

  final int? trackId;
  final double size;
  final double borderRadius;
  final double? iconSize;

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
      return Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: scheme.secondaryContainer,
          borderRadius: BorderRadius.circular(widget.borderRadius),
        ),
        child: Icon(
          Icons.music_note,
          size: widget.iconSize ?? widget.size * 0.5,
          color: scheme.onSecondaryContainer,
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
