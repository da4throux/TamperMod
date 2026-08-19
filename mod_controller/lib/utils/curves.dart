// Copyright (c) 2026 TamperMod Contributors
// Licensed under the MIT License
//
// Custom curves for fade interpolation and animation

import 'package:flutter/material.dart';

/// Vectorized Bézier Curve with Start/End vector handles and Center Point inflection
class VectorBezierCurve extends Curve {
  /// Start point tangent handle (x1, y1)
  final double x1;
  final double y1;
  /// End point tangent handle (x2, y2)
  final double x2;
  final double y2;
  
  /// Center point inflection (mx, my)
  final double mx;
  final double my;

  const VectorBezierCurve({
    this.x1 = 0.25,
    this.y1 = 0.1,
    this.mx = 0.5,
    this.my = 0.5,
    this.x2 = 0.75,
    this.y2 = 0.9,
  });

  /// Factory from parameters map with fallback to classic parameters
  factory VectorBezierCurve.fromMap(Map<String, double> map) {
    return VectorBezierCurve(
      x1: (map['h1x'] ?? map['x1'] ?? 0.25).clamp(0.0, 1.0),
      y1: (map['h1y'] ?? map['y1'] ?? 0.1).clamp(0.0, 1.0),
      mx: (map['mx'] ?? 0.5).clamp(0.05, 0.95),
      my: (map['my'] ?? 0.5).clamp(0.0, 1.0),
      x2: (map['h2x'] ?? map['x2'] ?? 0.75).clamp(0.0, 1.0),
      y2: (map['h2y'] ?? map['y2'] ?? 0.9).clamp(0.0, 1.0),
    );
  }

  Map<String, double> toMap() {
    return {
      'h1x': x1,
      'h1y': y1,
      'mx': mx,
      'my': my,
      'h2x': x2,
      'h2y': y2,
    };
  }

  /// Creates a mirrored curve (e.g. for Fade Out opposite to Fade In)
  static Map<String, double> mirror(Map<String, double> src) {
    final double inH1x = src['h1x'] ?? src['x1'] ?? 0.25;
    final double inH1y = src['h1y'] ?? src['y1'] ?? 0.1;
    final double inMx = src['mx'] ?? 0.5;
    final double inMy = src['my'] ?? 0.5;
    final double inH2x = src['h2x'] ?? src['x2'] ?? 0.75;
    final double inH2y = src['h2y'] ?? src['y2'] ?? 0.9;

    return {
      'h1x': (1.0 - inH2x).clamp(0.0, 1.0),
      'h1y': (1.0 - inH2y).clamp(0.0, 1.0),
      'mx': (1.0 - inMx).clamp(0.05, 0.95),
      'my': (1.0 - inMy).clamp(0.0, 1.0),
      'h2x': (1.0 - inH1x).clamp(0.0, 1.0),
      'h2y': (1.0 - inH1y).clamp(0.0, 1.0),
    };
  }

  /// Copies curve parameters
  static Map<String, double> copy(Map<String, double> src) {
    return Map<String, double>.from(src);
  }

  @override
  double transformInternal(double t) {
    if (t.isNaN || t <= 0.0) return 0.0;
    if (t >= 1.0) return 1.0;

    double res;
    if (t < mx) {
      final double segT = mx > 0.0 ? (t / mx).clamp(0.0, 1.0) : 0.0;
      final double normH1x = mx > 0.0 ? (x1 / mx).clamp(0.0, 1.0) : 0.0;
      // Auto-derived tangent into center point M
      const double normMinX = 0.75;
      res = _solveCubic(segT, 0.0, normH1x, normMinX, 1.0, 0.0, y1, my * 0.9, my);
    } else {
      final double segW = 1.0 - mx;
      final double segT = segW > 0.0 ? ((t - mx) / segW).clamp(0.0, 1.0) : 1.0;
      final double normH2x = segW > 0.0 ? ((x2 - mx) / segW).clamp(0.0, 1.0) : 1.0;
      // Auto-derived tangent out of center point M
      const double normMoutX = 0.25;
      res = _solveCubic(segT, 0.0, normMoutX, normH2x, 1.0, my, my + (1.0 - my) * 0.1, y2, 1.0);
    }

    if (res.isNaN) return t.clamp(0.0, 1.0);
    return res.clamp(0.0, 1.0);
  }

  /// Solves a 1D cubic Bézier for Y given target X (time t)
  double _solveCubic(
    double targetX,
    double x0, double x1, double x2, double x3,
    double y0, double y1, double y2, double y3,
  ) {
    if (targetX.isNaN) return 0.0;
    // 1. Find parametric parameter u such that BezierX(u) == targetX
    double u = targetX.clamp(0.0, 1.0);
    // Newton-Raphson iteration
    for (int i = 0; i < 8; i++) {
      final double currentX = _sampleBezier(u, x0, x1, x2, x3);
      if (currentX.isNaN) { u = targetX; break; }
      final double diff = currentX - targetX;
      if (diff.abs() < 1e-5) break;
      final double slopeX = _sampleBezierDerivative(u, x0, x1, x2, x3);
      if (slopeX.isNaN || slopeX.abs() < 1e-6) break;
      final double nextU = u - (diff / slopeX);
      if (nextU.isNaN) break;
      u = nextU.clamp(0.0, 1.0);
    }

    // Binary search fallback if Newton didn't converge
    if ((_sampleBezier(u, x0, x1, x2, x3) - targetX).abs() > 1e-3) {
      double low = 0.0;
      double high = 1.0;
      for (int i = 0; i < 12; i++) {
        u = (low + high) * 0.5;
        final double currentX = _sampleBezier(u, x0, x1, x2, x3);
        if (currentX.isNaN) break;
        if (currentX < targetX) {
          low = u;
        } else {
          high = u;
        }
      }
    }

    // 2. Evaluate BezierY(u)
    final double result = _sampleBezier(u, y0, y1, y2, y3);
    if (result.isNaN) return targetX.clamp(0.0, 1.0);
    return result.clamp(0.0, 1.0);
  }

  double _sampleBezier(double u, double p0, double p1, double p2, double p3) {
    final double oneMinusU = 1.0 - u;
    return (oneMinusU * oneMinusU * oneMinusU * p0) +
        (3.0 * oneMinusU * oneMinusU * u * p1) +
        (3.0 * oneMinusU * u * u * p2) +
        (u * u * u * p3);
  }

  double _sampleBezierDerivative(double u, double p0, double p1, double p2, double p3) {
    final double oneMinusU = 1.0 - u;
    return (3.0 * oneMinusU * oneMinusU * (p1 - p0)) +
        (6.0 * oneMinusU * u * (p2 - p1)) +
        (3.0 * u * u * (p3 - p2));
  }
}

/// Backward compatibility: CustomSCurve for legacy calls
class CustomSCurve extends VectorBezierCurve {
  final double cx;
  final double cy;
  final double slope;

  CustomSCurve({this.cx = 0.5, this.cy = 0.5, this.slope = 1.0})
      : super(
          x1: cx * 0.5,
          y1: cy * (1.0 - slope * 0.5),
          mx: cx,
          my: cy,
          x2: cx + (1.0 - cx) * (0.5 + slope * 0.5),
          y2: cy + (1.0 - cy) * (0.5 + slope * 0.5),
        );
}
