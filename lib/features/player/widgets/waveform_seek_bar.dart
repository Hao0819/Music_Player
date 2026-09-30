import 'dart:math';

import 'package:flutter/material.dart';

/// A scrubber drawn as a bar waveform: played bars are filled, the rest are
/// dimmed, and dragging seeks.
///
/// The shape is generated from a hash of the track id, not from the audio
/// itself — decoding every file to get real amplitudes would be far too slow
/// on a phone. It is stable per track, so a given song always looks the same.
class WaveformSeekBar extends StatefulWidget {
  const WaveformSeekBar({
    super.key,
    required this.seed,
    required this.position,
    required this.duration,
    required this.onSeek,
    this.barCount = 56,
    this.height = 56,
  });

  final String seed;
  final Duration position;
  final Duration duration;
  final ValueChanged<Duration> onSeek;
  final int barCount;
  final double height;

  @override
  State<WaveformSeekBar> createState() => _WaveformSeekBarState();
}

class _WaveformSeekBarState extends State<WaveformSeekBar> {
  late List<double> _bars = _buildBars(widget.seed, widget.barCount);

  /// Set while dragging so the waveform follows the finger instead of
  /// snapping back to the playhead on every position tick.
  double? _dragProgress;

  @override
  void didUpdateWidget(WaveformSeekBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.seed != widget.seed || oldWidget.barCount != widget.barCount) {
      _bars = _buildBars(widget.seed, widget.barCount);
    }
  }

  static List<double> _buildBars(String seed, int count) {
    final random = Random(seed.hashCode);
    return List.generate(count, (index) {
      // Taper the ends so it reads as a clip rather than a flat block.
      final edge = sin(pi * (index + 0.5) / count);
      return 0.18 + random.nextDouble() * 0.82 * (0.45 + 0.55 * edge);
    });
  }

  double get _progress {
    if (_dragProgress != null) return _dragProgress!;
    final total = widget.duration.inMilliseconds;
    if (total <= 0) return 0;
    return (widget.position.inMilliseconds / total).clamp(0.0, 1.0);
  }

  void _updateDrag(double dx, double width) {
    setState(() => _dragProgress = (dx / width).clamp(0.0, 1.0));
  }

  void _commitDrag() {
    final progress = _dragProgress;
    if (progress != null) {
      widget.onSeek(widget.duration * progress);
    }
    setState(() => _dragProgress = null);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) => _updateDrag(details.localPosition.dx, width),
          onTapUp: (_) => _commitDrag(),
          onHorizontalDragUpdate: (details) => _updateDrag(details.localPosition.dx, width),
          onHorizontalDragEnd: (_) => _commitDrag(),
          onHorizontalDragCancel: () => setState(() => _dragProgress = null),
          child: SizedBox(
            height: widget.height,
            width: double.infinity,
            child: CustomPaint(
              painter: _WaveformPainter(
                bars: _bars,
                progress: _progress,
                playedColor: scheme.primary,
                remainingColor: scheme.onSurfaceVariant.withValues(alpha: 0.35),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter({
    required this.bars,
    required this.progress,
    required this.playedColor,
    required this.remainingColor,
  });

  final List<double> bars;
  final double progress;
  final Color playedColor;
  final Color remainingColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (bars.isEmpty) return;

    final slot = size.width / bars.length;
    final barWidth = slot * 0.55;
    final playedUpTo = size.width * progress;
    final centerY = size.height / 2;

    for (var i = 0; i < bars.length; i++) {
      final centerX = slot * i + slot / 2;
      final barHeight = (size.height * bars[i]).clamp(3.0, size.height);
      final paint = Paint()..color = centerX <= playedUpTo ? playedColor : remainingColor;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(centerX, centerY), width: barWidth, height: barHeight),
          Radius.circular(barWidth / 2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.bars != bars ||
      oldDelegate.playedColor != playedColor ||
      oldDelegate.remainingColor != remainingColor;
}
