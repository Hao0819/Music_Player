import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/player_providers.dart';

/// Three bars that rise and fall while the track is playing, and settle flat
/// when it is paused.
///
/// This is the one piece of motion in the app that nobody asked for by
/// tapping something, and it earns that by reporting state: it is the only
/// place in a long list that distinguishes "this is the track you are on" from
/// "this is the track you are on, and it is running". The static `graphic_eq`
/// glyph it replaces implied the former but looked like the latter.
class PlayingIndicator extends ConsumerStatefulWidget {
  const PlayingIndicator({super.key, this.size = 16});

  final double size;

  @override
  ConsumerState<PlayingIndicator> createState() => _PlayingIndicatorState();
}

class _PlayingIndicatorState extends ConsumerState<PlayingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    duration: const Duration(milliseconds: 900),
    vsync: this,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    final playing = ref.watch(playbackStateProvider).value?.playing ?? false;
    // Honour the system's reduce-motion setting: the bars still show which
    // row is current, they just hold still.
    final animate = playing && !MediaQuery.disableAnimationsOf(context);

    if (animate && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!animate && _controller.isAnimating) {
      _controller.stop();
    }

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          painter: _BarsPainter(
            progress: _controller.value,
            color: color,
            // Paused bars sit low and even, so the row reads as "stopped here"
            // rather than as a frozen frame of the animation.
            idle: !animate,
          ),
        ),
      ),
    );
  }
}

class _BarsPainter extends CustomPainter {
  _BarsPainter({required this.progress, required this.color, required this.idle});

  final double progress;
  final Color color;
  final bool idle;

  static const _barCount = 3;
  // Offsets so the bars do not move as one block.
  static const _phases = [0.0, 0.33, 0.66];

  @override
  void paint(Canvas canvas, Size size) {
    final slot = size.width / _barCount;
    final barWidth = slot * 0.55;
    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeWidth = barWidth;

    for (var i = 0; i < _barCount; i++) {
      final fraction = idle
          ? 0.35
          : 0.25 + 0.75 * (0.5 + 0.5 * sin(2 * pi * (progress + _phases[i])));
      final height = size.height * fraction;
      final x = slot * i + slot / 2;
      canvas.drawLine(
        Offset(x, size.height - barWidth / 2),
        Offset(x, size.height - height + barWidth / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_BarsPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color || oldDelegate.idle != idle;
}
