import 'package:flutter/material.dart';

import '../../../core/utils/duration_format.dart';
import '../../../domain/track.dart';
import '../../../widgets/artwork_image.dart';
import '../../player/widgets/playing_indicator.dart';

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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

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
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: PlayingIndicator(),
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
      // Artist and album are separated by a real tonal step, not just a gap.
      // Spacing alone was tried and does not survive contact with real data:
      // these fields routinely contain spaces of their own ("HK Fans Club"),
      // so without a contrast break the two run together into one phrase.
      subtitle: Text.rich(
        TextSpan(
          children: [
            if (folderNames.isNotEmpty) ...[
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
              _gap,
              TextSpan(
                text: track.artist,
                style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.80)),
              ),
            ] else ...[
              TextSpan(
                text: track.artist,
                style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.80)),
              ),
              _gap,
              TextSpan(
                text: track.album,
                style: TextStyle(color: scheme.onSurfaceVariant.withValues(alpha: 0.62)),
              ),
            ],
          ],
        ),
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
                  tooltip: isFavorite ? 'Remove from Favorites' : 'Add to Favorites',
                  icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border, size: 20),
                  color: isFavorite ? scheme.primary : scheme.onSurfaceVariant,
                  onPressed: onFavoriteToggle,
                ),
              Text(formatDuration(track.duration), style: theme.textTheme.labelSmall),
            ],
          ),
      selected: selected,
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }
}

/// Wide enough to be unmistakably a field break rather than a word space,
/// which matters because the fields on either side contain word spaces.
const _gap = WidgetSpan(child: SizedBox(width: 13));
