// Copyright (c) 2026 TamperMod Contributors
// Licensed under the MIT License

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../utils/curves.dart';

enum _ActiveDragTarget {
  none,
  startHandle,
  midpoint,
  endHandle,
}

/// Interactive Vectorized Bézier Curve Editor with separate Fade In / Fade Out tabs
class VectorBezierEditor extends StatefulWidget {
  final Map<String, double> paramsIn;
  final Map<String, double> paramsOut;
  final Color accentColor;
  final bool isDarkMode;
  final ValueChanged<Map<String, double>> onParamsInChanged;
  final ValueChanged<Map<String, double>> onParamsOutChanged;

  const VectorBezierEditor({
    super.key,
    required this.paramsIn,
    required this.paramsOut,
    required this.accentColor,
    required this.isDarkMode,
    required this.onParamsInChanged,
    required this.onParamsOutChanged,
  });

  @override
  State<VectorBezierEditor> createState() => _VectorBezierEditorState();
}

class _VectorBezierEditorState extends State<VectorBezierEditor> {
  bool _isEditingFadeIn = true;
  _ActiveDragTarget _dragTarget = _ActiveDragTarget.none;

  Map<String, double> get _activeParams =>
      _isEditingFadeIn ? widget.paramsIn : widget.paramsOut;

  ValueChanged<Map<String, double>> get _activeOnChanged =>
      _isEditingFadeIn ? widget.onParamsInChanged : widget.onParamsOutChanged;

  double get _x1 => _activeParams['h1x'] ?? _activeParams['x1'] ?? 0.25;
  double get _y1 => _activeParams['h1y'] ?? _activeParams['y1'] ?? 0.1;
  double get _mx => _activeParams['mx'] ?? 0.5;
  double get _my => _activeParams['my'] ?? 0.5;
  double get _x2 => _activeParams['h2x'] ?? _activeParams['x2'] ?? 0.75;
  double get _y2 => _activeParams['h2y'] ?? _activeParams['y2'] ?? 0.9;

  void _applyPreset(Map<String, double> preset) {
    _activeOnChanged({
      ..._activeParams,
      ...preset,
    });
  }

  void _copyOpposite() {
    if (_isEditingFadeIn) {
      widget.onParamsInChanged(VectorBezierCurve.copy(widget.paramsOut));
    } else {
      widget.onParamsOutChanged(VectorBezierCurve.copy(widget.paramsIn));
    }
  }

  void _mirrorOpposite() {
    if (_isEditingFadeIn) {
      widget.onParamsInChanged(VectorBezierCurve.mirror(widget.paramsOut));
    } else {
      widget.onParamsOutChanged(VectorBezierCurve.mirror(widget.paramsIn));
    }
  }

  @override
  Widget build(BuildContext context) {
    final VectorBezierCurve curve = VectorBezierCurve.fromMap(_activeParams);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tab switcher: FADE IN vs FADE OUT
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _isEditingFadeIn = true),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: _isEditingFadeIn
                        ? widget.accentColor.withValues(alpha: 0.2)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: _isEditingFadeIn
                          ? widget.accentColor
                          : Colors.grey[700]!,
                      width: _isEditingFadeIn ? 1.5 : 1.0,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.trending_up,
                        size: 13,
                        color: _isEditingFadeIn
                            ? widget.accentColor
                            : Colors.grey[500],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'FADE IN CURVE',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: _isEditingFadeIn
                              ? widget.accentColor
                              : Colors.grey[500],
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _isEditingFadeIn = false),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: !_isEditingFadeIn
                        ? widget.accentColor.withValues(alpha: 0.2)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: !_isEditingFadeIn
                          ? widget.accentColor
                          : Colors.grey[700]!,
                      width: !_isEditingFadeIn ? 1.5 : 1.0,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.trending_down,
                        size: 13,
                        color: !_isEditingFadeIn
                            ? widget.accentColor
                            : Colors.grey[500],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'FADE OUT CURVE',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: !_isEditingFadeIn
                              ? widget.accentColor
                              : Colors.grey[500],
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),

        // Action Toolbar (Mirror, Copy, Export)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                _buildActionButton(
                  icon: Icons.flip,
                  label: _isEditingFadeIn ? 'MIRROR OUT' : 'MIRROR IN',
                  onTap: _mirrorOpposite,
                ),
                const SizedBox(width: 4),
                _buildActionButton(
                  icon: Icons.content_copy,
                  label: _isEditingFadeIn ? 'COPY OUT' : 'COPY IN',
                  onTap: _copyOpposite,
                ),
              ],
            ),
            _buildActionButton(
              icon: Icons.share,
              label: 'EXPORT',
              onTap: () {
                final String json = jsonEncode({
                  'curve': _isEditingFadeIn ? 'fadeIn' : 'fadeOut',
                  ..._activeParams,
                });
                Clipboard.setData(ClipboardData(text: json));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Curve copied to clipboard'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 6),

        // Interactive 3-Point Vector Canvas (H1 -> M -> H2)
        Container(
          height: 140,
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFF090D12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: widget.accentColor.withValues(alpha: 0.3),
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
              final Offset pm = toScreen(_mx, _my);
              final Offset h2 = toScreen(_x2, _y2);

              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: (details) {
                  final pos = details.localPosition;
                  const double hitRadius = 26.0;

                  if ((pos - pm).distance <= hitRadius) {
                    setState(() => _dragTarget = _ActiveDragTarget.midpoint);
                    return;
                  }
                  if ((pos - h1).distance <= hitRadius) {
                    setState(() => _dragTarget = _ActiveDragTarget.startHandle);
                    return;
                  }
                  if ((pos - h2).distance <= hitRadius) {
                    setState(() => _dragTarget = _ActiveDragTarget.endHandle);
                    return;
                  }
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
                      _activeOnChanged({
                        ..._activeParams,
                        'h1x': norm.dx.clamp(0.0, _mx),
                        'h1y': norm.dy.clamp(0.0, 1.0),
                      });
                      break;
                    case _ActiveDragTarget.midpoint:
                      // Moving the center point adjusts the inflection point
                      // and shifts the vector handles smoothly
                      final double deltaX = norm.dx - _mx;
                      final double deltaY = norm.dy - _my;
                      _activeOnChanged({
                        ..._activeParams,
                        'mx': norm.dx.clamp(0.1, 0.9),
                        'my': norm.dy.clamp(0.05, 0.95),
                        'h1x': (_x1 + deltaX * 0.5).clamp(0.0, norm.dx),
                        'h1y': (_y1 + deltaY * 0.5).clamp(0.0, 1.0),
                        'h2x': (_x2 + deltaX * 0.5).clamp(norm.dx, 1.0),
                        'h2y': (_y2 + deltaY * 0.5).clamp(0.0, 1.0),
                      });
                      break;
                    case _ActiveDragTarget.endHandle:
                      _activeOnChanged({
                        ..._activeParams,
                        'h2x': norm.dx.clamp(_mx, 1.0),
                        'h2y': norm.dy.clamp(0.0, 1.0),
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
                    mx: _mx,
                    my: _my,
                    h2x: _x2,
                    h2y: _y2,
                    activeTarget: _dragTarget,
                  ),
                  child: const SizedBox.expand(),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 6),

        // Quick Shape Presets
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildPresetButton(
                label: 'SMOOTH S',
                preset: {
                  'h1x': 0.25, 'h1y': 0.10,
                  'mx': 0.50, 'my': 0.50,
                  'h2x': 0.75, 'h2y': 0.90,
                },
              ),
              _buildPresetButton(
                label: 'PUNCHY ATTACK',
                preset: {
                  'h1x': 0.05, 'h1y': 0.75,
                  'mx': 0.35, 'my': 0.85,
                  'h2x': 0.65, 'h2y': 0.98,
                },
              ),
              _buildPresetButton(
                label: 'LATE SWELL',
                preset: {
                  'h1x': 0.40, 'h1y': 0.05,
                  'mx': 0.70, 'my': 0.20,
                  'h2x': 0.95, 'h2y': 0.60,
                },
              ),
              _buildPresetButton(
                label: 'LINEAR',
                preset: {
                  'h1x': 0.25, 'h1y': 0.25,
                  'mx': 0.50, 'my': 0.50,
                  'h2x': 0.75, 'h2y': 0.75,
                },
              ),
              _buildPresetButton(
                label: 'RESET',
                preset: {
                  'h1x': 0.25, 'h1y': 0.10,
                  'mx': 0.50, 'my': 0.50,
                  'h2x': 0.75, 'h2y': 0.90,
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
        decoration: BoxDecoration(
          color: widget.accentColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: widget.accentColor.withValues(alpha: 0.4)),
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
              color: widget.accentColor.withValues(alpha: 0.3),
              width: 0.8,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 8.5,
              fontWeight: FontWeight.w700,
              color: widget.accentColor.withValues(alpha: 0.9),
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
  final double mx;
  final double my;
  final double h2x;
  final double h2y;
  final _ActiveDragTarget activeTarget;

  _VectorBezierCanvasPainter({
    required this.curve,
    required this.accentColor,
    required this.isDarkMode,
    required this.pad,
    required this.h1x,
    required this.h1y,
    required this.mx,
    required this.my,
    required this.h2x,
    required this.h2y,
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
      ..color = Colors.white.withValues(alpha: 0.06)
      ..strokeWidth = 0.5;

    for (int i = 0; i <= 4; i++) {
      final double y = pad + (i / 4.0) * ch;
      canvas.drawLine(Offset(pad, y), Offset(pad + cw, y), gridPaint);
      final double x = pad + (i / 4.0) * cw;
      canvas.drawLine(Offset(x, pad), Offset(x, pad + ch), gridPaint);
    }

    // 2. Diagonal helper reference
    final refPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.1)
      ..strokeWidth = 0.8;
    canvas.drawLine(toScreen(0.0, 0.0), toScreen(1.0, 1.0), refPaint);

    // 3. Tangent Vector Arms (from Ends to Handles)
    final p0 = toScreen(0.0, 0.0);
    final p1 = toScreen(1.0, 1.0);
    final h1 = toScreen(h1x, h1y);
    final pm = toScreen(mx, my);
    final h2 = toScreen(h2x, h2y);

    final armPaint = Paint()
      ..color = const Color(0xFF00E5FF).withValues(alpha: 0.6)
      ..strokeWidth = 1.5;

    // Start tangent arm
    canvas.drawLine(p0, h1, armPaint);
    // End tangent arm
    canvas.drawLine(p1, h2, armPaint);

    // Center point indicator line (subtle guide to center)
    final guidePaint = Paint()
      ..color = const Color(0xFFFF9100).withValues(alpha: 0.25)
      ..strokeWidth = 1.0;
    canvas.drawLine(Offset(pm.dx, pad), Offset(pm.dx, pad + ch), guidePaint);
    canvas.drawLine(Offset(pad, pm.dy), Offset(pad + cw, pm.dy), guidePaint);

    // 4. Main Bézier Spline with Gradient Glow
    final splinePath = Path();
    const int steps = 100;
    for (int i = 0; i <= steps; i++) {
      final double t = i / steps;
      final double y = curve.transform(t);
      if (y.isNaN) continue;
      final Offset pt = toScreen(t, y);
      if (i == 0) {
        splinePath.moveTo(pt.dx, pt.dy);
      } else {
        splinePath.lineTo(pt.dx, pt.dy);
      }
    }

    // Spline glow
    final glowPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.3)
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

      final double radius = isActive ? 7.0 : 5.5;

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

    // Draw Start Vector Handle (Cyan Diamond)
    drawHandleGrip(
      h1,
      const Color(0xFF00E5FF),
      activeTarget == _ActiveDragTarget.startHandle,
      isDiamond: true,
    );

    // Draw Center Point M (Amber Circle)
    drawHandleGrip(
      pm,
      const Color(0xFFFF9100),
      activeTarget == _ActiveDragTarget.midpoint,
      isDiamond: false,
    );

    // Draw End Vector Handle (Cyan Diamond)
    drawHandleGrip(
      h2,
      const Color(0xFF00E5FF),
      activeTarget == _ActiveDragTarget.endHandle,
      isDiamond: true,
    );
  }

  @override
  bool shouldRepaint(covariant _VectorBezierCanvasPainter oldDelegate) {
    return true;
  }
}
