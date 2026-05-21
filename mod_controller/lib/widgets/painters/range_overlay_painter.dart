// Copyright (c) 2026 TamperMod Contributors
// Licensed under the MIT License
//
// Range cursor overlay painter drawn on the volume slider

import 'package:flutter/material.dart';

/// Range cursor overlay painter drawn on the volume slider
///
/// Renders downward-pointing triangular cursors with stems and highlighted zone.
/// Extracted from main.dart for reusability and maintainability.
class RangeOverlayPainter extends CustomPainter {
  final Color accentColor;
  final double rangeStart;
  final double rangeEnd;
  final double thumbPadding;
  final double trackHeight;
  final bool isDarkMode;

  RangeOverlayPainter({
    required this.accentColor,
    required this.rangeStart,
    required this.rangeEnd,
    required this.thumbPadding,
    required this.trackHeight,
    required this.isDarkMode,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double trackW = size.width - 2 * thumbPadding;
    if (trackW <= 0) return;
    final double cy = size.height / 2;
    final double tipY = cy - (trackHeight / 2);
    final double x1 = thumbPadding + rangeStart * trackW;
    final double x2 = thumbPadding + rangeEnd * trackW;

    // Highlighted zone between cursors (over the track)
    canvas.drawRect(
      Rect.fromLTRB(x1, tipY, x2, tipY + trackHeight),
      Paint()
        ..color = accentColor.withOpacity(0.18)
        ..style = PaintingStyle.fill,
    );

    // Downward-pointing triangle (tip at top edge of track)
    void drawCursor(double x) {
      final double h = (size.height * 0.38).clamp(6.0, 14.0);
      final double w = h * 0.75;
      
      final path = Path()
        ..moveTo(x, tipY) // tip
        ..lineTo(x - w, tipY - h) // upper-left
        ..lineTo(x + w, tipY - h) // upper-right
        ..close();

      // Fill
      canvas.drawPath(
        path,
        Paint()
          ..color = accentColor
          ..style = PaintingStyle.fill,
      );

      // Outline (contrasting color)
      canvas.drawPath(
        path,
        Paint()
          ..color = isDarkMode ? Colors.white : Colors.black87
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0,
      );

      // Thin stem to top of widget
      canvas.drawLine(
        Offset(x, tipY - h),
        Offset(x, 0),
        Paint()
          ..color = accentColor.withOpacity(0.35)
          ..strokeWidth = 1.0,
      );
    }

    drawCursor(x1);
    drawCursor(x2);
  }

  @override
  bool shouldRepaint(RangeOverlayPainter oldDelegate) {
    return oldDelegate.rangeStart != rangeStart ||
        oldDelegate.rangeEnd != rangeEnd ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.thumbPadding != thumbPadding ||
        oldDelegate.trackHeight != trackHeight ||
        oldDelegate.isDarkMode != isDarkMode;
  }
}
