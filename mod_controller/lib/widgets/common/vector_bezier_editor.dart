// Copyright (c) 2026 TamperMod Contributors
// Licensed under the MIT License

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../utils/curves.dart';

enum _ActiveDragTarget {
  none,
  startHandle,
  endHandle,
  midpoint,
  midpointLeftHandle,
  midpointRightHandle,
}

/// Interactive Vectorized Bézier Curve Editor inspired by Blender's F-Curve Graph Editor
class VectorBezierEditor extends StatefulWidget {
  final Map<String, double> params;
  final Color accentColor;
  final bool isDarkMode;
  final ValueChanged<Map<String, double>> onParamsChanged;

  const VectorBezierEditor({
    super.key,
    required this.params,
    required this.accentColor,
    required this.isDarkMode,
    required this.onParamsChanged,
  });

  @override
  State<VectorBezierEditor> createState() => _VectorBezierEditorState();
}

class _VectorBezierEditorState extends State<VectorBezierEditor> {
  _ActiveDragTarget _dragTarget = _ActiveDragTarget.none;

  // Handle coordinates (0.0 to 1.0)
  double get _x1 => widget.params['h1x'] ?? widget.params['x1'] ?? 0.25;
  double get _y1 => widget.params['h1y'] ?? widget.params['y1'] ?? 0.1;
  double get _x2 => widget.params['h2x'] ?? widget.params['x2'] ?? 0.75;
  double get _y2 => widget.params['h2y'] ?? widget.params['y2'] ?? 0.9;

  bool get _hasMidpoint => (widget.params['hasMidpoint'] ?? 0.0) > 0.5;
  double get _mx => widget.params['mx'] ?? 0.5;
  double get _my => widget.params['my'] ?? 0.5;
  double get _mhlx => widget.params['mhlx'] ?? 0.35;
  double get _mhly => widget.params['mhly'] ?? 0.5;
  double get _mhrx => widget.params['mhrx'] ?? 0.65;
  double get _mhry => widget.params['mhry'] ?? 0.5;

  void _applyPreset(Map<String, double> preset) {
    widget.onParamsChanged({
      ...widget.params,
      ...preset,
    });
  }

  @override
  Widget build(BuildContext context) {
    final VectorBezierCurve curve = VectorBezierCurve.fromMap(widget.params);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header & Quick Presets
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  Icons.gesture,
                  size: 13,
                  color: widget.accentColor.withOpacity(0.9),
                ),
                const SizedBox(width: 4),
                Text(
                  'VECTOR CURVE EDITOR',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: widget.accentColor.withOpacity(0.9),
                    letterSpacing: 1.1,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                _buildMiniActionButton(
                  icon: _hasMidpoint ? Icons.linear_scale : Icons.add_circle_outline,
                  label: _hasMidpoint ? '2-POINT' : '+ MIDPOINT',
                  onTap: () {
                    widget.onParamsChanged({
                      ...widget.params,
                      'hasMidpoint': _hasMidpoint ? 0.0 : 1.0,
                    });
                  },
                ),
                const SizedBox(width: 4),
                _buildMiniActionButton(
                  icon: Icons.copy,
                  label: 'EXPORT',
                  onTap: () {
                    final String json = jsonEncode({
                      'shape': 'custom_vector',
                      ...widget.params,
                    });
                    Clipboard.setData(ClipboardData(text: json));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Vector curve copied to clipboard'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 6),

        // Interactive Vector Canvas
        Container(
          height: 140,
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFF090D12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: widget.accentColor.withOpacity(0.3),
              width: 1.0,
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              const double pad = 24.0;
              final double cw = constraints.maxWidth - 2 * pad;
              final double ch = constraints.maxHeight - 2 * pad;

              Offset toScreen(double normX, double normY) {
                return Offset(pad + normX * cw, pad + (1.0 - normY) * ch);
              }

              Offset toNormalized(Offset screenPos) {
                final double nx = ((screenPos.dx - pad) / cw).clamp(0.0, 1.0);
                final double ny = (1.0 - (screenPos.dy - pad) / ch).clamp(0.0, 1.0);
                return Offset(nx, ny);
              }

              final Offset p0 = toScreen(0.0, 0.0);
              final Offset p1 = toScreen(1.0, 1.0);
              final Offset h1 = toScreen(_x1, _y1);
              final Offset h2 = toScreen(_x2, _y2);

              final Offset pm = toScreen(_mx, _my);
              final Offset pmhl = toScreen(_mhlx, _mhly);
              final Offset pmhr = toScreen(_mhrx, _mhry);

              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: (details) {
                  final pos = details.localPosition;
                  const double hitRadius = 24.0;

                  if (_hasMidpoint) {
                    if ((pos - pmhl).distance <= hitRadius) {
                      setState(() => _dragTarget = _ActiveDragTarget.midpointLeftHandle);
                      return;
                    }
                    if ((pos - pmhr).distance <= hitRadius) {
                      setState(() => _dragTarget = _ActiveDragTarget.midpointRightHandle);
                      return;
                    }
                    if ((pos - pm).distance <= hitRadius) {
                      setState(() => _dragTarget = _ActiveDragTarget.midpoint);
                      return;
                    }
                  }

                  if ((pos - h1).distance <= hitRadius) {
                    setState(() => _dragTarget = _ActiveDragTarget.startHandle);
                    return;
                  }
                  if ((pos - h2).distance <= hitRadius) {
                    setState(() => _dragTarget = _ActiveDragTarget.endHandle);
                    return;
                  }

                  // If user tapped directly near Start or End, jump handle
                  if ((pos - p0).distance <= hitRadius) {
                    setState(() => _dragTarget = _ActiveDragTarget.startHandle);
                    return;
                  }
                  if ((pos - p1).distance <= hitRadius) {
                    setState(() => _dragTarget = _ActiveDragTarget.endHandle);
                    return;
                  }
                },
                onPanUpdate: (details) {
                  final norm = toNormalized(details.localPosition);
                  switch (_dragTarget) {
                    case _ActiveDragTarget.startHandle:
                      widget.onParamsChanged({
                        ...widget.params,
                        'h1x': norm.dx.clamp(0.0, _hasMidpoint ? _mx : 1.0),
                        'h1y': norm.dy.clamp(0.0, 1.0),
                      });
                      break;
                    case _ActiveDragTarget.endHandle:
                      widget.onParamsChanged({
                        ...widget.params,
                        'h2x': norm.dx.clamp(_hasMidpoint ? _mx : 0.0, 1.0),
                        'h2y': norm.dy.clamp(0.0, 1.0),
                      });
                      break;
                    case _ActiveDragTarget.midpoint:
                      final double dx = norm.dx - _mx;
                      final double dy = norm.dy - _my;
                      widget.onParamsChanged({
                        ...widget.params,
                        'mx': norm.dx.clamp(0.1, 0.9),
                        'my': norm.dy.clamp(0.0, 1.0),
                        'mhlx': (_mhlx + dx).clamp(0.0, norm.dx),
                        'mhly': (_mhly + dy).clamp(0.0, 1.0),
                        'mhrx': (_mhrx + dx).clamp(norm.dx, 1.0),
                        'mhry': (_mhry + dy).clamp(0.0, 1.0),
                      });
                      break;
                    case _ActiveDragTarget.midpointLeftHandle:
                      widget.onParamsChanged({
                        ...widget.params,
                        'mhlx': norm.dx.clamp(0.0, _mx),
                        'mhly': norm.dy.clamp(0.0, 1.0),
                        // Mirror opposite handle angle if aligned
                        'mhrx': (_mx + (_mx - norm.dx)).clamp(_mx, 1.0),
                        'mhry': (_my - (norm.dy - _my)).clamp(0.0, 1.0),
                      });
                      break;
                    case _ActiveDragTarget.midpointRightHandle:
                      widget.onParamsChanged({
                        ...widget.params,
                        'mhrx': norm.dx.clamp(_mx, 1.0),
                        'mhry': norm.dy.clamp(0.0, 1.0),
                        // Mirror opposite handle
                        'mhlx': (_mx - (norm.dx - _mx)).clamp(0.0, _mx),
                        'mhly': (_my - (norm.dy - _my)).clamp(0.0, 1.0),
                      });
                      break;
                    case _ActiveDragTarget.none:
                      break;
                  }
                },
                onPanEnd: (_) => setState(() => _dragTarget = _ActiveDragTarget.none),
                onPanCancel: () => setState(() => _dragTarget = _ActiveDragTarget.none),
                child: CustomPaint(
                  painter: _VectorBezierCanvasPainter(
                    curve: curve,
                    accentColor: widget.accentColor,
                    isDarkMode: widget.isDarkMode,
                    pad: pad,
                    h1x: _x1,
                    h1y: _y1,
                    h2x: _x2,
                    h2y: _y2,
                    hasMidpoint: _hasMidpoint,
                    mx: _mx,
                    my: _my,
                    mhlx: _mhlx,
                    mhly: _mhly,
                    mhrx: _mhrx,
                    mhry: _mhry,
                    activeTarget: _dragTarget,
                  ),
                  child: const SizedBox.expand(),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 6),

        // Quick Vector Presets (Blender Style)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildPresetButton(
                label: 'SMOOTH S',
                preset: {
                  'h1x': 0.25, 'h1y': 0.10,
                  'h2x': 0.75, 'h2y': 0.90,
                  'hasMidpoint': 0.0,
                },
              ),
              _buildPresetButton(
                label: 'PUNCHY ATTACK',
                preset: {
                  'h1x': 0.05, 'h1y': 0.75,
                  'h2x': 0.40, 'h2y': 0.98,
                  'hasMidpoint': 0.0,
                },
              ),
              _buildPresetButton(
                label: 'LATE SWELL',
                preset: {
                  'h1x': 0.60, 'h1y': 0.02,
                  'h2x': 0.95, 'h2y': 0.25,
                  'hasMidpoint': 0.0,
                },
              ),
              _buildPresetButton(
                label: 'LINEAR',
                preset: {
                  'h1x': 0.33, 'h1y': 0.33,
                  'h2x': 0.66, 'h2y': 0.66,
                  'hasMidpoint': 0.0,
                },
              ),
              _buildPresetButton(
                label: 'S-MIDPOINT',
                preset: {
                  'hasMidpoint': 1.0,
                  'h1x': 0.15, 'h1y': 0.05,
                  'mx': 0.50, 'my': 0.50,
                  'mhlx': 0.35, 'mhly': 0.50,
                  'mhrx': 0.65, 'mhry': 0.50,
                  'h2x': 0.85, 'h2y': 0.95,
                },
              ),
              _buildPresetButton(
                label: 'RESET',
                preset: {
                  'h1x': 0.30, 'h1y': 0.10,
                  'h2x': 0.70, 'h2y': 0.90,
                  'hasMidpoint': 0.0,
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMiniActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: widget.accentColor.withOpacity(0.12),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: widget.accentColor.withOpacity(0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 10, color: widget.accentColor),
            const SizedBox(width: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 8.5,
                fontWeight: FontWeight.w700,
                color: widget.accentColor,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetButton({
    required String label,
    required Map<String, double> preset,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 5),
      child: GestureDetector(
        onTap: () => _applyPreset(preset),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: widget.isDarkMode
                ? const Color(0xFF141922)
                : const Color(0xFFE5E9F0),
            borderRadius: BorderRadius.circular(5),
            border: Border.all(
              color: widget.accentColor.withOpacity(0.3),
              width: 0.8,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 8.5,
              fontWeight: FontWeight.w700,
              color: widget.accentColor.withOpacity(0.9),
            ),
          ),
        ),
      ),
    );
  }
}

class _VectorBezierCanvasPainter extends CustomPainter {
  final VectorBezierCurve curve;
  final Color accentColor;
  final bool isDarkMode;
  final double pad;
  final double h1x;
  final double h1y;
  final double h2x;
  final double h2y;
  final bool hasMidpoint;
  final double mx;
  final double my;
  final double mhlx;
  final double mhly;
  final double mhrx;
  final double mhry;
  final _ActiveDragTarget activeTarget;

  _VectorBezierCanvasPainter({
    required this.curve,
    required this.accentColor,
    required this.isDarkMode,
    required this.pad,
    required this.h1x,
    required this.h1y,
    required this.h2x,
    required this.h2y,
    required this.hasMidpoint,
    required this.mx,
    required this.my,
    required this.mhlx,
    required this.mhly,
    required this.mhrx,
    required this.mhry,
    required this.activeTarget,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double cw = size.width - 2 * pad;
    final double ch = size.height - 2 * pad;

    Offset toScreen(double normX, double normY) {
      return Offset(pad + normX * cw, pad + (1.0 - normY) * ch);
    }

    // 1. Grid lines
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.06)
      ..strokeWidth = 0.5;

    for (int i = 0; i <= 4; i++) {
      final double y = pad + (i / 4.0) * ch;
      canvas.drawLine(Offset(pad, y), Offset(pad + cw, y), gridPaint);
      final double x = pad + (i / 4.0) * cw;
      canvas.drawLine(Offset(x, pad), Offset(x, pad + ch), gridPaint);
    }

    // 2. Diagonal helper reference
    final refPaint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..strokeWidth = 0.8;
    canvas.drawLine(toScreen(0.0, 0.0), toScreen(1.0, 1.0), refPaint);

    // 3. Tangent Vector Arms (Blender style colored vector handles)
    final p0 = toScreen(0.0, 0.0);
    final p1 = toScreen(1.0, 1.0);
    final h1 = toScreen(h1x, h1y);
    final h2 = toScreen(h2x, h2y);

    final armPaint = Paint()
      ..color = const Color(0xFF00E5FF).withOpacity(0.6)
      ..strokeWidth = 1.5;

    // Start tangent arm
    canvas.drawLine(p0, h1, armPaint);
    // End tangent arm
    canvas.drawLine(p1, h2, armPaint);

    if (hasMidpoint) {
      final pm = toScreen(mx, my);
      final pmhl = toScreen(mhlx, mhly);
      final pmhr = toScreen(mhrx, mhry);

      final midArmPaint = Paint()
        ..color = const Color(0xFFFF9100).withOpacity(0.6)
        ..strokeWidth = 1.5;
      canvas.drawLine(pm, pmhl, midArmPaint);
      canvas.drawLine(pm, pmhr, midArmPaint);
    }

    // 4. Main Bézier Spline with Gradient Glow
    final splinePath = Path();
    const int steps = 100;
    for (int i = 0; i <= steps; i++) {
      final double t = i / steps;
      final double y = curve.transform(t);
      final Offset pt = toScreen(t, y);
      if (i == 0) {
        splinePath.moveTo(pt.dx, pt.dy);
      } else {
        splinePath.lineTo(pt.dx, pt.dy);
      }
    }

    // Spline glow
    final glowPaint = Paint()
      ..color = accentColor.withOpacity(0.3)
      ..strokeWidth = 5.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawPath(splinePath, glowPaint);

    // Spline core
    final corePaint = Paint()
      ..color = accentColor
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(splinePath, corePaint);

    // 5. Control Points & Handle Grips
    void drawHandleGrip(Offset pos, Color color, bool isActive, {bool isDiamond = false}) {
      final fillPaint = Paint()..color = color;
      final borderPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = isActive ? 2.0 : 1.2;

      final double radius = isActive ? 6.5 : 5.0;

      if (isDiamond) {
        final path = Path()
          ..moveTo(pos.dx, pos.dy - radius)
          ..lineTo(pos.dx + radius, pos.dy)
          ..lineTo(pos.dx, pos.dy + radius)
          ..lineTo(pos.dx - radius, pos.dy)
          ..close();
        canvas.drawPath(path, fillPaint);
        canvas.drawPath(path, borderPaint);
      } else {
        canvas.drawCircle(pos, radius, fillPaint);
        canvas.drawCircle(pos, radius, borderPaint);
      }
    }

    // Draw Endpoints
    drawHandleGrip(p0, Colors.white, false);
    drawHandleGrip(p1, Colors.white, false);

    // Draw Tangent Handles
    drawHandleGrip(
      h1,
      const Color(0xFF00E5FF),
      activeTarget == _ActiveDragTarget.startHandle,
      isDiamond: true,
    );
    drawHandleGrip(
      h2,
      const Color(0xFF00E5FF),
      activeTarget == _ActiveDragTarget.endHandle,
      isDiamond: true,
    );

    if (hasMidpoint) {
      final pm = toScreen(mx, my);
      final pmhl = toScreen(mhlx, mhly);
      final pmhr = toScreen(mhrx, mhry);

      drawHandleGrip(
        pm,
        const Color(0xFFFF9100),
        activeTarget == _ActiveDragTarget.midpoint,
      );
      drawHandleGrip(
        pmhl,
        const Color(0xFFFFD54F),
        activeTarget == _ActiveDragTarget.midpointLeftHandle,
        isDiamond: true,
      );
      drawHandleGrip(
        pmhr,
        const Color(0xFFFFD54F),
        activeTarget == _ActiveDragTarget.midpointRightHandle,
        isDiamond: true,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _VectorBezierCanvasPainter oldDelegate) {
    return true;
  }
}
