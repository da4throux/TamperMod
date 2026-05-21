// Copyright (c) 2026 TamperMod Contributors
// Licensed under the MIT License
//
// Live fade curve visualizer painter

import 'package:flutter/material.dart';

/// Live fade curve visualizer painter
///
/// Renders fade curve with grid, range lines, and moving dot.
/// Extracted from main.dart for reusability and maintainability.
class FadeCurvePainter extends CustomPainter {
  final Color accentColor;
  final Curve curve;
  final double progress; // 0.0–1.0, where the moving dot is
  final int bars;
  final double rangeStart; // 0.0–1.0 fractional
  final double rangeEnd; // 0.0–1.0 fractional
  final bool isFadeOut;

  FadeCurvePainter({
    required this.accentColor,
    required this.curve,
    required this.progress,
    required this.bars,
    required this.rangeStart,
    required this.rangeEnd,
    this.isFadeOut = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const double padL = 28, padR = 12, padT = 8, padB = 24;
    final double w = size.width - padL - padR;
    final double h = size.height - padT - padB;

    // Background
    final bgPaint = Paint()..color = const Color(0xFF0A0D12);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        const Radius.circular(10),
      ),
      bgPaint,
    );

    // Grid lines (subtle horizontal)
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.06)
      ..strokeWidth = 0.5;
    for (int i = 0; i <= 4; i++) {
      final double y = padT + (i / 4) * h;
      canvas.drawLine(Offset(padL, y), Offset(padL + w, y), gridPaint);
    }

    // Beat bar separators (prominent vertical lines for each bar)
    final beatBarPaint = Paint()
      ..color = accentColor.withOpacity(0.25)
      ..strokeWidth = 1.5;
    for (int i = 0; i <= bars; i++) {
      final double x = padL + (i / bars) * w;
      canvas.drawLine(Offset(x, padT), Offset(x, padT + h), beatBarPaint);
    }

    // Range dashed lines
    final rangePaint = Paint()
      ..color = accentColor.withOpacity(0.35)
      ..strokeWidth = 1.0;
    final double yStart = padT + (1.0 - rangeStart) * h;
    final double yEnd = padT + (1.0 - rangeEnd) * h;
    _drawDashed(
      canvas,
      Offset(padL, yStart),
      Offset(padL + w, yStart),
      rangePaint,
    );
    _drawDashed(canvas, Offset(padL, yEnd), Offset(padL + w, yEnd), rangePaint);

    // Curve line
    final curvePaint = Paint()
      ..color = accentColor
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final path = Path();
    const int steps = 120;
    for (int i = 0; i <= steps; i++) {
      final double t = i / steps;
      final double ct = isFadeOut
          ? 1.0 - curve.transform(t)
          : curve.transform(t);
      // ct=0 → bottom (muted), ct=1 → top (full)
      final double px = padL + t * w;
      final double py = padT + (1.0 - ct) * h;
      if (i == 0) {
        path.moveTo(px, py);
      } else {
        path.lineTo(px, py);
      }
    }
    canvas.drawPath(path, curvePaint);

    // Moving dot
    if (progress > 0.0 && progress < 1.0) {
      final double ct = isFadeOut
          ? 1.0 - curve.transform(progress)
          : curve.transform(progress);
      final double dotX = padL + progress * w;
      final double dotY = padT + (1.0 - ct) * h;
      // Glow
      canvas.drawCircle(
        Offset(dotX, dotY),
        9,
        Paint()..color = accentColor.withOpacity(0.3),
      );
      // Core dot
      canvas.drawCircle(Offset(dotX, dotY), 5, Paint()..color = accentColor);
    }

    // Axis labels
    final labelStyle = TextStyle(color: Colors.grey[600], fontSize: 9);
    // Bar ticks on X
    for (int i = 0; i <= bars; i++) {
      final double x = padL + (i / bars) * w;
      _drawText(canvas, '$i', Offset(x - 4, padT + h + 4), labelStyle);
    }
    // Y labels
    _drawText(canvas, '100%', Offset(0, padT - 2), labelStyle);
    _drawText(canvas, '0%', Offset(4, padT + h - 6), labelStyle);
  }

  void _drawDashed(Canvas canvas, Offset start, Offset end, Paint paint) {
    const double dashLen = 4, gapLen = 4;
    final double dx = end.dx - start.dx;
    final double dy = end.dy - start.dy;
    final double len = (end - start).distance;
    final double stepX = dx / len * (dashLen + gapLen);
    final double stepY = dy / len * (dashLen + gapLen);
    double drawn = 0;
    double ox = start.dx, oy = start.dy;
    while (drawn < len) {
      final double dashEnd = (drawn + dashLen).clamp(0, len);
      final double ratio = dashEnd / len;
      canvas.drawLine(
        Offset(ox, oy),
        Offset(start.dx + dx * ratio, start.dy + dy * ratio),
        paint,
      );
      drawn += dashLen + gapLen;
      ox += stepX;
      oy += stepY;
    }
  }

  void _drawText(Canvas canvas, String text, Offset offset, TextStyle style) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(FadeCurvePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.rangeStart != rangeStart ||
        oldDelegate.rangeEnd != rangeEnd ||
        oldDelegate.curve != curve ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.isFadeOut != isFadeOut;
  }
}
