// Copyright (c) 2026 TamperMod Contributors
// Licensed under the MIT License

import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// BPM controller widget with tap tempo
class BpmController extends StatelessWidget {
  final double bpm;
  final int fadeBars;
  final bool isDarkMode;
  final VoidCallback onTapTempo;
  final VoidCallback onBpmTap;
  final ValueChanged<double> onBpmChanged;
  final ValueChanged<int> onFadeBarsChanged;
  final ValueListenable<bool> isTransportRolling;
  final ValueListenable<int> transportSyncMode;
  final ValueChanged<bool> onTransportRollingChanged;
  final ValueChanged<int> onSyncModeChanged;

  const BpmController({
    super.key,
    required this.bpm,
    required this.fadeBars,
    required this.isDarkMode,
    required this.onTapTempo,
    required this.onBpmTap,
    required this.onBpmChanged,
    required this.onFadeBarsChanged,
    required this.isTransportRolling,
    required this.transportSyncMode,
    required this.onTransportRollingChanged,
    required this.onSyncModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final double seconds = (60 / bpm) * 4 * fadeBars;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDarkMode
            ? Colors.black.withOpacity(0.35)
            : Colors.grey[300]!.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color:
              (isDarkMode ? const Color(0xFF00FFCC) : const Color(0xFF00B3FF))
                  .withOpacity(0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Fuchsia Tap Tempo Button
          GestureDetector(
            onTap: onTapTempo,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFF007F).withOpacity(0.12),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: const Color(0xFFFF007F).withOpacity(0.4),
                ),
              ),
              child: const Text(
                'TAP',
                style: TextStyle(
                  color: Color(0xFFFF007F),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // BPM Rotary Knob
          BpmKnob(
            bpm: bpm,
            minBpm: 20.0,
            maxBpm: 280.0,
            isDarkMode: isDarkMode,
            onChanged: onBpmChanged,
          ),
          const SizedBox(width: 8),

          // Editable BPM readout
          GestureDetector(
            onTap: onBpmTap,
            child: Text(
              '${bpm.toStringAsFixed(1)} BPM',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
                color: isDarkMode
                    ? const Color(0xFF00FFCC)
                    : const Color(0xFF0099FF),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Dropdown selector for Fade Beats length
          DropdownButton<int>(
            value: fadeBars,
            dropdownColor: isDarkMode ? const Color(0xFF0F141C) : Colors.white,
            underline: const SizedBox(),
            icon: const Icon(
              Icons.arrow_drop_down,
              color: Colors.grey,
              size: 16,
            ),
            style: TextStyle(
              color: isDarkMode ? Colors.white : Colors.black,
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
            ),
            onChanged: (val) {
              if (val != null) {
                onFadeBarsChanged(val);
              }
            },
            items: [1, 2, 4, 8, 16].map((b) {
              return DropdownMenuItem<int>(
                value: b,
                child: Text('$b Bar${b > 1 ? "s" : ""}'),
              );
            }).toList(),
          ),
          const SizedBox(width: 4),

          // Live duration calculation text
          Text(
            '(${seconds.toStringAsFixed(1)}s)',
            style: TextStyle(
              fontSize: 10,
              color: isDarkMode ? Colors.grey[500] : Colors.grey[700],
            ),
          ),

          // Vertical divider
          Container(
            height: 20,
            width: 1,
            color: Colors.grey.withOpacity(0.4),
            margin: const EdgeInsets.symmetric(horizontal: 10),
          ),

          // Play/Stop Button
          ValueListenableBuilder<bool>(
            valueListenable: isTransportRolling,
            builder: (context, isRolling, _) {
              return IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Icon(
                  isRolling ? Icons.play_arrow : Icons.stop,
                  color: isRolling
                      ? (isDarkMode
                            ? const Color(0xFF00FFCC)
                            : const Color(0xFF00B3FF))
                      : const Color(0xFFFF0055),
                  size: 20,
                ),
                tooltip: isRolling ? 'Stop Transport' : 'Play Transport',
                onPressed: () => onTransportRollingChanged(!isRolling),
              );
            },
          ),
          const SizedBox(width: 10),

          // Sync Mode Dropdown
          ValueListenableBuilder<int>(
            valueListenable: transportSyncMode,
            builder: (context, syncMode, _) {
              return DropdownButton<int>(
                value: (syncMode >= 0 && syncMode <= 2) ? syncMode : 0,
                dropdownColor: isDarkMode
                    ? const Color(0xFF0F141C)
                    : Colors.white,
                underline: const SizedBox(),
                icon: const Icon(Icons.sync, color: Colors.grey, size: 14),
                style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
                onChanged: (val) {
                  if (val != null) {
                    onSyncModeChanged(val);
                  }
                },
                items: const [
                  DropdownMenuItem<int>(value: 0, child: Text('INTERNAL')),
                  DropdownMenuItem<int>(value: 1, child: Text('MIDI')),
                  DropdownMenuItem<int>(value: 2, child: Text('LINK')),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// A premium, stage-ready neon rotary knob for BPM control
class BpmKnob extends StatelessWidget {
  final double bpm;
  final double minBpm;
  final double maxBpm;
  final bool isDarkMode;
  final ValueChanged<double> onChanged;

  const BpmKnob({
    super.key,
    required this.bpm,
    required this.minBpm,
    required this.maxBpm,
    required this.isDarkMode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTap: () => onChanged(120.0), // Reset to 120.0 BPM on double-tap
      onPanUpdate: (details) {
        // Vertical drag adjusts BPM. Dragging up (negative dy) increases BPM.
        // Sensitivity factor of 0.6.
        const double sensitivity = 0.6;
        final double deltaBpm = -details.delta.dy * sensitivity;
        final double newBpm = (bpm + deltaBpm).clamp(minBpm, maxBpm);
        // Round to 1 decimal place to match host expectations and keep UI clean
        onChanged(double.parse(newBpm.toStringAsFixed(1)));
      },
      child: Tooltip(
        message: 'Drag Up/Down to adjust BPM (Double tap to reset to 120)',
        child: MouseRegion(
          cursor: SystemMouseCursors.resizeUpDown,
          child: CustomPaint(
            size: const Size(28, 28),
            painter: BpmKnobPainter(
              bpm: bpm,
              minBpm: minBpm,
              maxBpm: maxBpm,
              isDarkMode: isDarkMode,
            ),
          ),
        ),
      ),
    );
  }
}

class BpmKnobPainter extends CustomPainter {
  final double bpm;
  final double minBpm;
  final double maxBpm;
  final bool isDarkMode;

  BpmKnobPainter({
    required this.bpm,
    required this.minBpm,
    required this.maxBpm,
    required this.isDarkMode,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double radius = size.width / 2;
    final Offset center = Offset(radius, radius);

    final Color primaryColor = isDarkMode
        ? const Color(0xFF00FFCC)
        : const Color(0xFF0099FF);
    final Color trackColor = isDarkMode
        ? Colors.grey[800]!.withOpacity(0.5)
        : Colors.grey[300]!;

    // 1. Draw outer background track arc
    final Paint trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    // Start angle: 135 degrees (in radians)
    // Sweep angle: 270 degrees (in radians)
    const double startAngle = 135 * pi / 180;
    const double sweepAngle = 270 * pi / 180;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 2),
      startAngle,
      sweepAngle,
      false,
      trackPaint,
    );

    // 2. Draw active value arc
    final double pct = ((bpm - minBpm) / (maxBpm - minBpm)).clamp(0.0, 1.0);
    final double activeSweepAngle = sweepAngle * pct;

    final Paint activePaint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 2),
      startAngle,
      activeSweepAngle,
      false,
      activePaint,
    );

    // 3. Draw premium minimalist tick pointer
    final double pointerAngle = startAngle + activeSweepAngle;
    final double innerRadius = radius * 0.3;
    final double outerRadius = radius - 3.5;

    final Offset pointerStart = Offset(
      center.dx + innerRadius * cos(pointerAngle),
      center.dy + innerRadius * sin(pointerAngle),
    );
    final Offset pointerEnd = Offset(
      center.dx + outerRadius * cos(pointerAngle),
      center.dy + outerRadius * sin(pointerAngle),
    );

    final Paint pointerPaint = Paint()
      ..color = isDarkMode ? Colors.white : Colors.black87
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawLine(pointerStart, pointerEnd, pointerPaint);
  }

  @override
  bool shouldRepaint(covariant BpmKnobPainter oldDelegate) {
    return oldDelegate.bpm != bpm ||
        oldDelegate.isDarkMode != isDarkMode ||
        oldDelegate.minBpm != minBpm ||
        oldDelegate.maxBpm != maxBpm;
  }
}

