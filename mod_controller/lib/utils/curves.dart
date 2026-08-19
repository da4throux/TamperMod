// Copyright (c) 2026 TamperMod Contributors
// Licensed under the MIT License
//
// Custom curves for fade interpolation and animation

import 'package:flutter/material.dart';

/// Vectorized Bézier Curve with Start/End vector handles and Center Point inflection
/// Formulated as a single continuous cubic Bézier with guaranteed monotonic smoothness.
class VectorBezierCurve extends Curve {
  /// Start point tangent handle (x1, y1)
  final double x1;
  final double y1;

  /// Center point inflection (mx, my)
  final double mx;
  final double my;

  /// End point tangent handle (x2, y2)
  final double x2;
  final double y2;

  const VectorBezierCurve({
    this.x1 = 0.25,
    this.y1 = 0.10,
    this.mx = 0.50,
    this.my = 0.50,
    this.x2 = 0.75,
    this.y2 = 0.90,
  });

  /// Standard balanced S-curve preset
  static const Map<String, double> balancedSPreset = {
    'h1x': 0.35,
    'h1y': 0.15,
    'mx': 0.50,
    'my': 0.50,
    'h2x': 0.65,
    'h2y': 0.85,
  };

  /// Factory from parameters map with fallback to classic parameters
  factory VectorBezierCurve.fromMap(Map<String, double> map) {
    final double mx = (map['mx'] ?? 0.50).clamp(0.05, 0.95);
    final double my = (map['my'] ?? 0.50).clamp(0.0, 1.0);
    final double h1x = (map['h1x'] ?? map['x1'] ?? (mx - 0.15)).clamp(0.0, mx);
    final double h1y = (map['h1y'] ?? map['y1'] ?? (my - 0.35)).clamp(0.0, my);
    final double h2x = (map['h2x'] ?? map['x2'] ?? (mx + 0.15)).clamp(mx, 1.0);
    final double h2y = (map['h2y'] ?? map['y2'] ?? (my + 0.35)).clamp(my, 1.0);

    return VectorBezierCurve(
      x1: h1x,
      y1: h1y,
      mx: mx,
      my: my,
      x2: h2x,
      y2: h2y,
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
    final double inMx = src['mx'] ?? 0.50;
    final double inMy = src['my'] ?? 0.50;
    final double inH1x = src['h1x'] ?? src['x1'] ?? (inMx - 0.15);
    final double inH1y = src['h1y'] ?? src['y1'] ?? (inMy - 0.35);
    final double inH2x = src['h2x'] ?? src['x2'] ?? (inMx + 0.15);
    final double inH2y = src['h2y'] ?? src['y2'] ?? (inMy + 0.35);

    final double outMx = (1.0 - inMx).clamp(0.05, 0.95);
    final double outMy = (1.0 - inMy).clamp(0.0, 1.0);
    final double outH1x = (1.0 - inH2x).clamp(0.0, outMx);
    final double outH1y = (1.0 - inH2y).clamp(0.0, outMy);
    final double outH2x = (1.0 - inH1x).clamp(outMx, 1.0);
    final double outH2y = (1.0 - inH1y).clamp(outMy, 1.0);

    return {
      'h1x': outH1x,
      'h1y': outH1y,
      'mx': outMx,
      'my': outMy,
      'h2x': outH2x,
      'h2y': outH2y,
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

    final double vmx = mx.clamp(0.05, 0.95);
    final double vmy = my.clamp(0.0, 1.0);

    // Incoming handle H1 is before M
    final double vh1x = x1.clamp(0.0, vmx);
    final double vh1y = y1.clamp(0.0, vmy);

    // Outgoing handle H2 is after M
    final double vh2x = x2.clamp(vmx, 1.0);
    final double vh2y = y2.clamp(vmy, 1.0);

    // Segment 1: from (0,0) to M
    // Start control point is horizontal from 0 for smooth attack
    final double c01x = vh1x * 0.5;
    final double c01y = 0.0;

    // Segment 2: from M to (1,1)
    // End control point is horizontal into 1 for smooth release
    final double c12x = vh2x + (1.0 - vh2x) * 0.5;
    final double c12y = 1.0;

    double res;
    if (t <= vmx) {
      // Solve segment 1
      res = _solveCubic(
        t,
        0.0, c01x, vh1x, vmx,
        0.0, c01y, vh1y, vmy,
      );
    } else {
      // Solve segment 2
      res = _solveCubic(
        t,
        vmx, vh2x, c12x, 1.0,
        vmy, vh2y, c12y, 1.0,
      );
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
      for (int i = 0; i < 16; i++) {
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
