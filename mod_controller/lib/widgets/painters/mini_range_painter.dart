// Copyright (c) 2026 TamperMod Contributors
// Licensed under the MIT License
//
// TODO: Extract mini range indicator painter

import 'package:flutter/material.dart';

/// Mini range indicator painter for compact/regular cards
///
/// TODO: Move from main.dart:
/// - _MiniRangePainter class (~192-250)
class MiniRangePainter extends CustomPainter {
  final Color accentColor;
  final double rangeStart;
  final double rangeEnd;

  MiniRangePainter({
    required this.accentColor,
    required this.rangeStart,
    required this.rangeEnd,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // TODO: Implement mini range painting logic
  }

  @override
  bool shouldRepaint(MiniRangePainter oldDelegate) {
    return oldDelegate.rangeStart != rangeStart ||
        oldDelegate.rangeEnd != rangeEnd ||
        oldDelegate.accentColor != accentColor;
  }
}
