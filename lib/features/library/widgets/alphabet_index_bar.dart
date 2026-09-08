import 'package:flutter/material.dart';

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
    setState(() => _activeLetter = letter);
    widget.onLetterSelected(letter);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) => _handlePosition(details.localPosition, height),
          onVerticalDragUpdate: (details) => _handlePosition(details.localPosition, height),
          onVerticalDragEnd: (_) => setState(() => _activeLetter = null),
          onVerticalDragCancel: () => setState(() => _activeLetter = null),
          onTapUp: (_) => setState(() => _activeLetter = null),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (final letter in AlphabetIndexBar.letters)
                  Text(
                    letter,
                    style: TextStyle(
                      fontSize: 10,
                      height: 1,
                      fontWeight: letter == _activeLetter ? FontWeight.bold : FontWeight.w500,
                      color: letter == _activeLetter
                          ? scheme.primary
                          : widget.availableLetters.contains(letter)
                              ? scheme.onSurfaceVariant
                              : scheme.onSurfaceVariant.withValues(alpha: 0.3),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
