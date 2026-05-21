// Copyright (c) 2026 TamperMod Contributors
// Licensed under the MIT License
//
// Custom curves for fade interpolation and animation

import 'package:flutter/material.dart';

/// Custom S-Curve for fade interpolation
///
/// A [Curve] defined by a midpoint (cx, cy) and a blend factor [slope].
/// - slope=0 → pure linear
/// - slope=1 → pure easeInOut-like
///
/// Extracted from main.dart for reusability across fade animations.
class CustomSCurve extends Curve {
  final double cx;
  final double cy;
  final double slope;

  const CustomSCurve({this.cx = 0.5, this.cy = 0.5, this.slope = 1.0});

  @override
  double transformInternal(double t) {
    // Piecewise linear mid-point shifted by cx/cy
    final double linear = t < cx
        ? (cx > 0 ? (cy / cx) * t : 0.0)
        : (cx < 1 ? cy + ((1.0 - cy) / (1.0 - cx)) * (t - cx) : 1.0);
    // Blend with easeInOut using slope as the weight
    final double eased = Curves.easeInOut.transform(t);
    final double s = slope.clamp(0.0, 1.0);
    return (linear * (1 - s) + eased * s).clamp(0.0, 1.0);
  }
}
