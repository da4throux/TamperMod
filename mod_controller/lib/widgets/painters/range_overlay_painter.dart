// Copyright (c) 2026 TamperMod Contributors
// Licensed under the MIT License
//
// TODO: Extract range cursor overlay painter

import 'package:flutter/material.dart';

/// Range cursor overlay painter drawn on the volume slider
///
/// TODO: Move from main.dart:
/// - _RangeOverlayPainter class (~252-310)
class RangeOverlayPainter extends CustomPainter {
  final Color accentColor;
  final double rangeStart;
  final double rangeEnd;
  final double thumbPadding;

  RangeOverlayPainter({
    required this.accentColor,
    required this.rangeStart,
    required this.rangeEnd,
    required this.thumbPadding,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // TODO: Implement range overlay painting logic
  }

  @override
  bool shouldRepaint(RangeOverlayPainter oldDelegate) {
    return oldDelegate.rangeStart != rangeStart ||
        oldDelegate.rangeEnd != rangeEnd ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.thumbPadding != thumbPadding;
  }
}
