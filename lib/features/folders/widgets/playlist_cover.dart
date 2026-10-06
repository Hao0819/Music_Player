import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../widgets/artwork_image.dart';
import '../providers/folder_providers.dart';

/// A playlist's cover, in falling order of preference:
///
/// 1. a picture the user picked for it,
/// 2. the first track in it that actually has artwork,
/// 3. the same plain record every uncovered track gets.
///
/// Step 2 is deliberately "the first track that has one" rather than "the first
/// track". Half of a ripped library has no embedded picture, so taking track
/// one gave a lot of playlists a blank sleeve while a perfectly good cover sat
/// two rows down.
class PlaylistCover extends ConsumerStatefulWidget {
  const PlaylistCover({
    super.key,
    required this.folderId,
    required this.size,
    this.borderRadius = 8,
  });

  final String folderId;
  final double size;
  final double borderRadius;

  /// How far down the playlist to look before giving up. Bounded because each
  /// miss is a platform-channel round trip, and a playlist whose first dozen
  /// tracks have no artwork almost certainly has none at all.
  static const searchDepth = 12;

  @override
  ConsumerState<PlaylistCover> createState() => _PlaylistCoverState();
}

class _PlaylistCoverState extends ConsumerState<PlaylistCover> {
  Uint8List? _bytes;
  File? _file;
  String? _resolvedFor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final folder = ref.watch(folderByIdProvider(widget.folderId));
    final contents = ref.watch(folderTracksProvider(widget.folderId)).value;

    // Re-resolve when the chosen picture or the track list changes; the key
    // folds both into one value so this does not fire on every rebuild.
    final key = '${folder?.coverPath}|${contents?.tracks.length}|'
        '${contents?.tracks.isEmpty ?? true ? '' : contents!.tracks.first.path}';
    if (key != _resolvedFor) {
      _resolvedFor = key;
      _resolve(folder?.coverPath, contents?.tracks.map((track) => track.id).toList() ?? const []);
    }

    final file = _file;
    final bytes = _bytes;

    final Widget child;
    if (file != null) {
      child = Image.file(file, width: widget.size, height: widget.size, fit: BoxFit.cover);
    } else if (bytes != null && bytes.isNotEmpty) {
      child = Image.memory(
        bytes,
        width: widget.size,
        height: widget.size,
        fit: BoxFit.cover,
        gaplessPlayback: true,
      );
    } else {
      child = Container(
        width: widget.size,
        height: widget.size,
        color: scheme.surfaceContainerHigh,
        child: Icon(Icons.album, size: widget.size * 0.45, color: scheme.outline),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: SizedBox(width: widget.size, height: widget.size, child: child),
    );
  }

  Future<void> _resolve(String? coverPath, List<int> trackIds) async {
    if (coverPath != null) {
      final file = File(coverPath);
      if (file.existsSync()) {
        if (mounted) setState(() { _file = file; _bytes = null; });
        return;
      }
      // The picture was deleted from under us. Fall through to the artwork so
      // the playlist still shows something rather than a hole.
    }

    for (final id in trackIds.take(PlaylistCover.searchDepth)) {
      final bytes = await loadArtwork(ref, id);
      if (bytes != null && bytes.isNotEmpty) {
        if (mounted) setState(() { _bytes = bytes; _file = null; });
        return;
      }
    }

    if (mounted) setState(() { _bytes = null; _file = null; });
  }
}
