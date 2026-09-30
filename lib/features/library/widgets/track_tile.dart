import 'package:flutter/material.dart';

import '../../../core/utils/duration_format.dart';
import '../../../domain/track.dart';
import '../../../widgets/artwork_image.dart';

class TrackTile extends StatelessWidget {
  const TrackTile({
    super.key,
    required this.track,
    this.onTap,
    this.onLongPress,
    this.trailing,
    this.selectionMode = false,
    this.selected = false,
    this.isFavorite = false,
    this.onFavoriteToggle,
    this.folderNames = const [],
    this.isCurrent = false,
  });

  /// Marks the row as the track the player is on, so it stands out in a list.
  final bool isCurrent;

  /// User folders this track is filed in. Shown ahead of the artist so they
  /// survive truncation, while keeping the row at its usual fixed height
  /// (the Library's A–Z index relies on that).
  final List<String> folderNames;

  final Track track;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Widget? trailing;
  final bool selectionMode;
  final bool selected;
  final bool isFavorite;
  final VoidCallback? onFavoriteToggle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ListTile(
      leading: selectionMode
          ? CircleAvatar(
              backgroundColor: selected ? scheme.primary : scheme.surfaceContainerHighest,
              child: Icon(
                selected ? Icons.check : Icons.music_note,
                color: selected ? scheme.onPrimary : scheme.onSurfaceVariant,
              ),
            )
          : ArtworkImage(trackId: track.id, size: 50),
      title: Row(
        children: [
          if (isCurrent)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Icon(Icons.graphic_eq, size: 16, color: scheme.primary),
            ),
          Expanded(
            child: Text(
              track.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: isCurrent ? TextStyle(color: scheme.primary, fontWeight: FontWeight.w700) : null,
            ),
          ),
        ],
      ),
      subtitle: folderNames.isEmpty
          ? Text('${track.artist} · ${track.album}', maxLines: 1, overflow: TextOverflow.ellipsis)
          : Text.rich(
              TextSpan(children: [
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 3),
                    child: Icon(Icons.folder, size: 14, color: scheme.primary),
                  ),
                ),
                TextSpan(
                  text: folderNames.join(', '),
                  style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w600),
                ),
                TextSpan(text: ' · ${track.artist}'),
              ]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
      trailing: trailing ??
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (onFavoriteToggle != null)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border),
                  color: isFavorite ? scheme.primary : scheme.onSurfaceVariant,
                  onPressed: onFavoriteToggle,
                ),
              Text(formatDuration(track.duration)),
            ],
          ),
      selected: selected,
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }
}
