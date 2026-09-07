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
  });

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
      title: Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text('${track.artist} · ${track.album}', maxLines: 1, overflow: TextOverflow.ellipsis),
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
