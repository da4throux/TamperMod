// Copyright (c) 2026 TamperMod Contributors
// Licensed under the MIT License

import 'package:flutter_test/flutter_test.dart';
import 'package:mod_controller/utils/curves.dart';

void main() {
  group('VectorBezierCurve mathematical stability & monotonicity tests', () {
    test('Standard balanced S-preset evaluates smoothly from 0 to 1', () {
      final curve = VectorBezierCurve.fromMap(VectorBezierCurve.balancedSPreset);
      expect(curve.transform(0.0), 0.0);
      expect(curve.transform(1.0), 1.0);

      double prev = 0.0;
      for (int i = 0; i <= 100; i++) {
        final double t = i / 100.0;
        final double y = curve.transform(t);
        expect(y.isNaN, false);
        expect(y.isInfinite, false);
        expect(y >= prev - 1e-4, true, reason: 'Curve must be monotonically non-decreasing at t=$t (y=$y, prev=$prev)');
        expect(y >= 0.0 && y <= 1.0, true);
        prev = y;
      }
    });

    test('100% pure vertical tangent handle across M evaluates smoothly and monotonically', () {
      final curve = VectorBezierCurve.fromMap({
        'h1x': 0.50,
        'h1y': 0.05,
        'mx': 0.50,
        'my': 0.50,
        'h2x': 0.50,
        'h2y': 0.95,
      });

      expect(curve.transform(0.0), 0.0);
      expect(curve.transform(1.0), 1.0);

      double prev = 0.0;
      for (int i = 0; i <= 200; i++) {
        final double t = i / 200.0;
        final double y = curve.transform(t);
        expect(y.isNaN, false);
        expect(y.isInfinite, false);
        expect(y >= prev - 1e-4, true);
        expect(y >= 0.0 && y <= 1.0, true);
        prev = y;
      }
    });

    test('Sharp near-vertical S-curve preset evaluates smoothly without NaN or stalls', () {
      final curve = VectorBezierCurve.fromMap({
        'h1x': 0.49,
        'h1y': 0.02,
        'mx': 0.50,
        'my': 0.50,
        'h2x': 0.51,
        'h2y': 0.98,
      });

      expect(curve.transform(0.0), 0.0);
      expect(curve.transform(1.0), 1.0);

      double prev = 0.0;
      for (int i = 0; i <= 200; i++) {
        final double t = i / 200.0;
        final double y = curve.transform(t);
        expect(y.isNaN, false);
        expect(y.isInfinite, false);
        expect(y >= prev - 1e-4, true);
        expect(y >= 0.0 && y <= 1.0, true);
        prev = y;
      }
    });

    test('Mirroring preserves validity and monotonicity for fade out', () {
      final src = {
        'h1x': 0.35,
        'h1y': 0.15,
        'mx': 0.50,
        'my': 0.50,
        'h2x': 0.65,
        'h2y': 0.85,
      };
      final mirrored = VectorBezierCurve.mirror(src);
      final curve = VectorBezierCurve.fromMap(mirrored);

      double prev = 0.0;
      for (int i = 0; i <= 100; i++) {
        final double t = i / 100.0;
        final double y = curve.transform(t);
        expect(y.isNaN, false);
        expect(y.isInfinite, false);
        expect(y >= prev - 1e-4, true);
        prev = y;
      }
    });

    test('Legacy CustomSCurve evaluates without NaN', () {
      final legacy = CustomSCurve(cx: 0.5, cy: 0.5, slope: 4.0);
      for (int i = 0; i <= 50; i++) {
        final double t = i / 50.0;
        final double y = legacy.transform(t);
        expect(y.isNaN, false);
        expect(y.isInfinite, false);
      }
    });
  });
}
