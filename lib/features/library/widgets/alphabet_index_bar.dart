import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Fixed A–Z strip down the right edge. Dragging or tapping a letter jumps
/// the list straight to that section, so a long library doesn't need endless
/// scrolling. Letters with no tracks are dimmed but still snap to the
/// nearest following section.
class AlphabetIndexBar extends StatefulWidget {
  const AlphabetIndexBar({
    super.key,
    required this.availableLetters,
    required this.onLetterSelected,
  });

  final Set<String> availableLetters;
  final ValueChanged<String> onLetterSelected;

  static const letters = [
    '#', 'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', //
    'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z',
  ];

  /// Width of the strip's hit area.
  ///
  /// Wider than the letters look: 27 rows down a phone screen leaves each one
  /// roughly 20dp tall, so the horizontal target has to carry the slack if a
  /// thumb is to land on the row it was aimed at. The letters stay right-
  /// aligned inside it, so the extra width is invisible.
  static const hitWidth = 44.0;

  @override
  State<AlphabetIndexBar> createState() => _AlphabetIndexBarState();
}

class _AlphabetIndexBarState extends State<AlphabetIndexBar> {
  String? _activeLetter;

  void _handlePosition(Offset localPosition, double height) {
    final rowHeight = height / AlphabetIndexBar.letters.length;
    final index = (localPosition.dy / rowHeight).floor().clamp(0, AlphabetIndexBar.letters.length - 1);
    final letter = AlphabetIndexBar.letters[index];

    if (letter == _activeLetter) return;
    // One tick per letter crossed, so a drag can be steered without watching
    // the list — the whole point of the strip is that you are not reading it.
    HapticFeedback.selectionClick();
    setState(() => _activeLetter = letter);
    widget.onLetterSelected(letter);
  }

  void _end() => setState(() => _activeLetter = null);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final active = _activeLetter;

    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;

        return Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.centerRight,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (details) => _handlePosition(details.localPosition, height),
              onVerticalDragStart: (details) => _handlePosition(details.localPosition, height),
              onVerticalDragUpdate: (details) => _handlePosition(details.localPosition, height),
              onVerticalDragEnd: (_) => _end(),
              onVerticalDragCancel: _end,
              onTapUp: (_) => _end(),
              onTapCancel: _end,
              child: SizedBox(
                width: AlphabetIndexBar.hitWidth,
                child: Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (final letter in AlphabetIndexBar.letters)
                        SizedBox(
                          width: 18,
                          child: Text(
                            letter,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              height: 1,
                              fontWeight:
                                  letter == active ? FontWeight.w700 : FontWeight.w500,
                              color: letter == active
                                  ? scheme.primary
                                  : widget.availableLetters.contains(letter)
                                      ? scheme.onSurfaceVariant
                                      : scheme.onSurfaceVariant.withValues(alpha: 0.3),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            // The letter under the thumb, repeated large and to the left where
            // the thumb is not covering it. Without this the strip gives no
            // feedback at all about where a drag has got to.
            if (active != null)
              Positioned(
                right: AlphabetIndexBar.hitWidth + 4,
                top: _bubbleTop(active, height),
                child: IgnorePointer(
                  child: Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: scheme.primary.withValues(alpha: 0.35),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Text(
                      active,
                      style: TextStyle(
                        color: scheme.onPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  /// Centres the bubble on the active letter's row, clamped to the strip.
  double _bubbleTop(String letter, double height) {
    final rowHeight = height / AlphabetIndexBar.letters.length;
    final centre = (AlphabetIndexBar.letters.indexOf(letter) + 0.5) * rowHeight;
    return (centre - 24).clamp(0.0, height - 48);
  }
}
