// Copyright (c) 2026 TamperMod Contributors
// Licensed under the MIT License
//
// Custom curves for fade interpolation and animation

import 'package:flutter/material.dart';

/// Vectorized Bézier Curve with Blender-style tangent handle vectors
class VectorBezierCurve extends Curve {
  /// Start point tangent handle (x1, y1) relative to (0, 0)
  final double x1;
  final double y1;
  /// End point tangent handle (x2, y2) relative to (1, 1)
  final double x2;
  final double y2;
  
  /// Optional intermediate midpoint (mx, my) and its tangent handles
  final bool hasMidpoint;
  final double mx;
  final double my;
  final double mhlx;
  final double mhly;
  final double mhrx;
  final double mhry;

  const VectorBezierCurve({
    this.x1 = 0.25,
    this.y1 = 0.1,
    this.x2 = 0.25,
    this.y2 = 1.0,
    this.hasMidpoint = false,
    this.mx = 0.5,
    this.my = 0.5,
    this.mhlx = 0.35,
    this.mhly = 0.5,
    this.mhrx = 0.65,
    this.mhry = 0.5,
  });

  /// Factory from parameters map with fallback to classic S-Curve parameters
  factory VectorBezierCurve.fromMap(Map<String, double> map) {
    if (map.containsKey('h1x') || map.containsKey('x1')) {
      return VectorBezierCurve(
        x1: map['h1x'] ?? map['x1'] ?? 0.25,
        y1: map['h1y'] ?? map['y1'] ?? 0.1,
        x2: map['h2x'] ?? map['x2'] ?? 0.75,
        y2: map['h2y'] ?? map['y2'] ?? 0.9,
        hasMidpoint: (map['hasMidpoint'] ?? 0.0) > 0.5,
        mx: map['mx'] ?? 0.5,
        my: map['my'] ?? 0.5,
        mhlx: map['mhlx'] ?? 0.35,
        mhly: map['mhly'] ?? 0.5,
        mhrx: map['mhrx'] ?? 0.65,
        mhry: map['mhry'] ?? 0.5,
      );
    }
    // Backward compatibility with older cx/cy/slope
    final double cx = map['cx'] ?? 0.5;
    final double cy = map['cy'] ?? 0.5;
    return VectorBezierCurve(
      x1: cx * 0.5,
      y1: cy * 0.2,
      x2: cx + (1.0 - cx) * 0.5,
      y2: cy + (1.0 - cy) * 0.8,
    );
  }

  Map<String, double> toMap() {
    return {
      'h1x': x1,
      'h1y': y1,
      'h2x': x2,
      'h2y': y2,
      'hasMidpoint': hasMidpoint ? 1.0 : 0.0,
      'mx': mx,
      'my': my,
      'mhlx': mhlx,
      'mhly': mhly,
      'mhrx': mhrx,
      'mhry': mhry,
    };
  }

  @override
  double transformInternal(double t) {
    if (t.isNaN || t <= 0.0) return 0.0;
    if (t >= 1.0) return 1.0;

    double res;
    if (!hasMidpoint) {
      res = _solveCubic(t, 0.0, x1, x2, 1.0, 0.0, y1, y2, 1.0);
    } else if (t < mx) {
      final double segT = mx > 0.0 ? t / mx : 0.0;
      final double normH1x = mx > 0.0 ? (x1 / mx).clamp(0.0, 1.0) : 0.0;
      final double normMhlx = mx > 0.0 ? (mhlx / mx).clamp(0.0, 1.0) : 1.0;
      res = _solveCubic(segT, 0.0, normH1x, normMhlx, 1.0, 0.0, y1, mhly, my);
    } else {
      final double segW = 1.0 - mx;
      final double segT = segW > 0.0 ? (t - mx) / segW : 1.0;
      final double normMhrx = segW > 0.0 ? ((mhrx - mx) / segW).clamp(0.0, 1.0) : 0.0;
      final double normH2x = segW > 0.0 ? ((x2 - mx) / segW).clamp(0.0, 1.0) : 1.0;
      res = _solveCubic(segT, 0.0, normMhrx, normH2x, 1.0, my, mhry, y2, 1.0);
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
          x2: cx + (1.0 - cx) * (0.5 + slope * 0.5),
          y2: cy + (1.0 - cy) * (0.5 + slope * 0.5),
        );
}
