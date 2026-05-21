// Copyright (c) 2026 TamperMod Contributors
// Licensed under the MIT License
//
// Mini range indicator painter for compact/regular cards

import 'package:flutter/material.dart';

/// Mini range indicator painter for compact/regular cards
///
/// Renders a vertical range indicator with triangle handles.
/// Extracted from main.dart for reusability and maintainability.
class MiniRangePainter extends CustomPainter {
  final Color accentColor;
  final double rangeStart; // 0.0–1.0
  final double rangeEnd; // 0.0–1.0

  MiniRangePainter({
    required this.accentColor,
    required this.rangeStart,
    required this.rangeEnd,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const double trackW = 4.0;
    final double cx = size.width / 2;
    const double padY = 4.0;
    final double trackH = size.height - padY * 2;

    // Background track
    final bgPaint = Paint()
      ..color = accentColor.withOpacity(0.12)
      ..strokeWidth = trackW
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(cx, padY), Offset(cx, padY + trackH), bgPaint);

    // Active range highlight
    final activePaint = Paint()
      ..color = accentColor.withOpacity(0.5)
      ..strokeWidth = trackW
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    // Note: rangeStart=0 = bottom (muted), rangeEnd=1 = top (full volume)
    // Draw from bottom (muted) upwards
    final double yStart = padY + (1.0 - rangeEnd) * trackH;
    final double yEnd = padY + (1.0 - rangeStart) * trackH;
    canvas.drawLine(Offset(cx, yStart), Offset(cx, yEnd), activePaint);

    // Triangle handles
    final triPaint = Paint()..color = accentColor;
    // Start triangle (pointing right, at rangeStart)
    final double ys = padY + (1.0 - rangeStart) * trackH;
    final path1 = Path();
    path1.moveTo(cx, ys);
    path1.lineTo(cx + 6, ys - 4);
    path1.lineTo(cx + 6, ys + 4);
    path1.close();
    canvas.drawPath(path1, triPaint);

    // End triangle (pointing right, at rangeEnd)
    final double ye = padY + (1.0 - rangeEnd) * trackH;
    final path2 = Path();
    path2.moveTo(cx, ye);
    path2.lineTo(cx + 6, ye - 4);
    path2.lineTo(cx + 6, ye + 4);
    path2.close();
    canvas.drawPath(path2, triPaint);
  }

  @override
  bool shouldRepaint(MiniRangePainter oldDelegate) {
    return oldDelegate.rangeStart != rangeStart ||
        oldDelegate.rangeEnd != rangeEnd ||
        oldDelegate.accentColor != accentColor;
  }
}
