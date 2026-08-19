// Copyright (c) 2026 TamperMod Contributors
// Licensed under the MIT License

import 'package:flutter/material.dart';
import '../../utils/curves.dart';

enum _ActiveDragTarget {
  none,
  startHandle,
  midpoint,
  endHandle,
}

/// Interactive Vectorized Bézier Curve Editor with separate Fade In / Fade Out tabs,
/// Undo/Redo history, visual top-to-bottom Fade Out, and user-saved custom presets.
class VectorBezierEditor extends StatefulWidget {
  final Map<String, double> paramsIn;
  final Map<String, double> paramsOut;
  final Map<String, Map<String, double>> customPresets;
  final Color accentColor;
  final bool isDarkMode;
  final ValueChanged<Map<String, double>> onParamsInChanged;
  final ValueChanged<Map<String, double>> onParamsOutChanged;
  final ValueChanged<Map<String, Map<String, double>>>? onCustomPresetsChanged;

  final double fadeProgress;
  final bool isFading;
  final bool isFadingIn;
  final bool isFadingOut;
  final bool isFadePaused;
  final double currentVolumeFraction;

  const VectorBezierEditor({
    super.key,
    required this.paramsIn,
    required this.paramsOut,
    this.customPresets = const {},
    required this.accentColor,
    required this.isDarkMode,
    required this.onParamsInChanged,
    required this.onParamsOutChanged,
    this.onCustomPresetsChanged,
    this.fadeProgress = 0.0,
    this.isFading = false,
    this.isFadingIn = false,
    this.isFadingOut = false,
    this.isFadePaused = false,
    this.currentVolumeFraction = 0.5,
  });

  @override
  State<VectorBezierEditor> createState() => _VectorBezierEditorState();
}

class _VectorBezierEditorState extends State<VectorBezierEditor> {
  bool _isEditingFadeIn = true;
  _ActiveDragTarget _dragTarget = _ActiveDragTarget.none;

  final List<Map<String, double>> _undoStackIn = [];
  final List<Map<String, double>> _undoStackOut = [];

  Map<String, double> get _activeParams =>
      _isEditingFadeIn ? widget.paramsIn : widget.paramsOut;

  ValueChanged<Map<String, double>> get _activeOnChanged =>
      _isEditingFadeIn ? widget.onParamsInChanged : widget.onParamsOutChanged;

  double get _x1 => (_activeParams['h1x'] ?? _activeParams['x1'] ?? 0.25).clamp(0.0, 1.0);
  double get _y1 => (_activeParams['h1y'] ?? _activeParams['y1'] ?? 0.10).clamp(0.0, 1.0);
  double get _x2 => (_activeParams['h2x'] ?? _activeParams['x2'] ?? 0.75).clamp(0.0, 1.0);
  double get _y2 => (_activeParams['h2y'] ?? _activeParams['y2'] ?? 0.90).clamp(0.0, 1.0);

  // Exact point on the single continuous cubic Bézier curve at t = 0.5 (X(0.5) = 3/8*(x1+x2) + 1/8, Y(0.5) = 3/8*(y1+y2) + 1/8)
  double get _mx => ((3.0 / 8.0) * (_x1 + _x2) + 0.125).clamp(0.05, 0.95);
  double get _my => ((3.0 / 8.0) * (_y1 + _y2) + 0.125).clamp(0.0, 1.0);

  void _recordHistory() {
    final copy = Map<String, double>.from(_activeParams);
    if (_isEditingFadeIn) {
      if (_undoStackIn.length >= 20) _undoStackIn.removeAt(0);
      _undoStackIn.add(copy);
    } else {
      if (_undoStackOut.length >= 20) _undoStackOut.removeAt(0);
      _undoStackOut.add(copy);
    }
  }

  void _undo() {
    final stack = _isEditingFadeIn ? _undoStackIn : _undoStackOut;
    if (stack.isNotEmpty) {
      final prev = stack.removeLast();
      setState(() {
        _activeOnChanged(prev);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reverted curve change'),
          duration: Duration(milliseconds: 800),
        ),
      );
    }
  }

  void _applyPreset(Map<String, double> preset) {
    _recordHistory();
    _activeOnChanged({
      ..._activeParams,
      ...preset,
    });
  }

  void _copyFadeInToOut() {
    if (_isEditingFadeIn) {
      if (_undoStackOut.length >= 20) _undoStackOut.removeAt(0);
      _undoStackOut.add(Map<String, double>.from(widget.paramsOut));
      widget.onParamsOutChanged(VectorBezierCurve.copy(widget.paramsIn));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Fade In curve copied to Fade Out'),
          duration: Duration(seconds: 1),
        ),
      );
    } else {
      if (_undoStackIn.length >= 20) _undoStackIn.removeAt(0);
      _undoStackIn.add(Map<String, double>.from(widget.paramsIn));
      widget.onParamsInChanged(VectorBezierCurve.copy(widget.paramsOut));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Fade Out curve copied to Fade In'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  void _mirrorFadeInToOut() {
    if (_isEditingFadeIn) {
      if (_undoStackOut.length >= 20) _undoStackOut.removeAt(0);
      _undoStackOut.add(Map<String, double>.from(widget.paramsOut));
      widget.onParamsOutChanged(VectorBezierCurve.mirror(widget.paramsIn));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Fade In curve mirrored to Fade Out'),
          duration: Duration(seconds: 1),
        ),
      );
    } else {
      if (_undoStackIn.length >= 20) _undoStackIn.removeAt(0);
      _undoStackIn.add(Map<String, double>.from(widget.paramsIn));
      widget.onParamsInChanged(VectorBezierCurve.mirror(widget.paramsOut));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Fade Out curve mirrored to Fade In'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  void _showSavePresetDialog() {
    final TextEditingController nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.isDarkMode ? const Color(0xFF141922) : Colors.white,
        title: Text(
          'Save Custom Curve Preset',
          style: TextStyle(
            color: widget.isDarkMode ? Colors.white : Colors.black,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter a name for this custom Bézier shape:',
              style: TextStyle(
                color: widget.isDarkMode ? Colors.grey[400] : Colors.grey[700],
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: nameController,
              autofocus: true,
              style: TextStyle(
                color: widget.isDarkMode ? Colors.white : Colors.black,
                fontSize: 13,
              ),
              decoration: InputDecoration(
                hintText: 'e.g. Steep Drop, Gentle Swell',
                hintStyle: TextStyle(color: Colors.grey[600], fontSize: 12),
                filled: true,
                fillColor: widget.isDarkMode ? const Color(0xFF0D1117) : const Color(0xFFF1F3F5),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.accentColor,
              foregroundColor: Colors.black,
            ),
            onPressed: () {
              final String name = nameController.text.trim();
              if (name.isNotEmpty) {
                final updated = Map<String, Map<String, double>>.from(widget.customPresets);
                updated[name] = Map<String, double>.from(_activeParams);
                widget.onCustomPresetsChanged?.call(updated);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Preset "$name" saved!'),
                    duration: const Duration(seconds: 1),
                  ),
                );
              }
            },
            child: const Text('SAVE', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final VectorBezierCurve curve = VectorBezierCurve.fromMap(_activeParams);
    final canUndo = (_isEditingFadeIn ? _undoStackIn : _undoStackOut).isNotEmpty;

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

        // Action Toolbar (Undo, Mirror, Copy, Save Preset)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                _buildActionButton(
                  icon: Icons.undo,
                  label: 'UNDO',
                  enabled: canUndo,
                  onTap: _undo,
                ),
                const SizedBox(width: 4),
                _buildActionButton(
                  icon: Icons.flip,
                  label: _isEditingFadeIn ? 'MIRROR TO FADE OUT' : 'MIRROR TO FADE IN',
                  onTap: _mirrorFadeInToOut,
                ),
                const SizedBox(width: 4),
                _buildActionButton(
                  icon: Icons.content_copy,
                  label: _isEditingFadeIn ? 'COPY TO FADE OUT' : 'COPY TO FADE IN',
                  onTap: _copyFadeInToOut,
                ),
              ],
            ),
            _buildActionButton(
              icon: Icons.bookmark_add,
              label: 'SAVE PRESET',
              onTap: _showSavePresetDialog,
            ),
          ],
        ),
        const SizedBox(height: 6),

        // Interactive Continuous Bézier Canvas
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

              // For Fade In: (0,0) is bottom-left, (1,1) is top-right
              // For Fade Out: (0,1) is top-left (100% volume), (1,0) is bottom-right (0% volume)
              Offset toScreen(double normX, double normY) {
                if (_isEditingFadeIn) {
                  return Offset(pad + normX * cw, pad + (1.0 - normY) * ch);
                } else {
                  // Top-to-bottom orientation for Fade Out
                  return Offset(pad + normX * cw, pad + normY * ch);
                }
              }

              Offset toNormalized(Offset screenPos) {
                final double nx = ((screenPos.dx - pad) / cw).clamp(0.0, 1.0);
                final double ny;
                if (_isEditingFadeIn) {
                  ny = (1.0 - (screenPos.dy - pad) / ch).clamp(0.0, 1.0);
                } else {
                  ny = ((screenPos.dy - pad) / ch).clamp(0.0, 1.0);
                }
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
                  _recordHistory();
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
                      {
                        // H1 dragged: calculate offset relative to fixed M
                        final double rawDx = (_mx - norm.dx).clamp(0.005, _mx);
                        final double rawDy = (_my - norm.dy).clamp(0.005, _my);
                        final double newH1x = _mx - rawDx;
                        final double newH1y = _my - rawDy;
                        // Symmetrically adjust the other tangent H2
                        final double newH2x = (_mx + rawDx).clamp(_mx, 1.0);
                        final double newH2y = (_my + rawDy).clamp(_my, 1.0);
                        _activeOnChanged({
                          ..._activeParams,
                          'h1x': newH1x,
                          'h1y': newH1y,
                          'h2x': newH2x,
                          'h2y': newH2y,
                          'mx': _mx,
                          'my': _my,
                        });
                      }
                      break;
                    case _ActiveDragTarget.endHandle:
                      {
                        // H2 dragged: calculate offset relative to fixed M
                        final double rawDx = (norm.dx - _mx).clamp(0.005, 1.0 - _mx);
                        final double rawDy = (norm.dy - _my).clamp(0.005, 1.0 - _my);
                        final double newH2x = _mx + rawDx;
                        final double newH2y = _my + rawDy;
                        // Symmetrically adjust the other tangent H1
                        final double newH1x = (_mx - rawDx).clamp(0.0, _mx);
                        final double newH1y = (_my - rawDy).clamp(0.0, _my);
                        _activeOnChanged({
                          ..._activeParams,
                          'h1x': newH1x,
                          'h1y': newH1y,
                          'h2x': newH2x,
                          'h2y': newH2y,
                          'mx': _mx,
                          'my': _my,
                        });
                      }
                      break;
                    case _ActiveDragTarget.midpoint:
                      {
                        // M dragged explicitly: shift M and translate H1, H2 with it
                        final double newMx = norm.dx.clamp(0.10, 0.90);
                        final double newMy = norm.dy.clamp(0.05, 0.95);
                        final double dx = _mx - _x1;
                        final double dy = _my - _y1;
                        final double newH1x = (newMx - dx).clamp(0.0, newMx);
                        final double newH1y = (newMy - dy).clamp(0.0, newMy);
                        final double newH2x = (newMx + dx).clamp(newMx, 1.0);
                        final double newH2y = (newMy + dy).clamp(newMy, 1.0);
                        _activeOnChanged({
                          ..._activeParams,
                          'h1x': newH1x,
                          'h1y': newH1y,
                          'h2x': newH2x,
                          'h2y': newH2y,
                          'mx': newMx,
                          'my': newMy,
                        });
                      }
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
                    isFadeIn: _isEditingFadeIn,
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
                    fadeProgress: widget.fadeProgress,
                    isFading: widget.isFading,
                    isFadingIn: widget.isFadingIn,
                    isFadingOut: widget.isFadingOut,
                    isFadePaused: widget.isFadePaused,
                    currentVolumeFraction: widget.currentVolumeFraction,
                  ),
                  child: const SizedBox.expand(),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 6),

        // Quick Shape Presets & Saved Curves
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              // Built-in presets
              _buildPresetButton(
                label: 'RESET',
                preset: VectorBezierCurve.balancedSPreset,
              ),
              _buildPresetButton(
                label: 'SMOOTH S',
                preset: {
                  'h1x': 0.35, 'h1y': 0.15,
                  'mx': 0.50, 'my': 0.50,
                  'h2x': 0.65, 'h2y': 0.85,
                },
              ),
              _buildPresetButton(
                label: 'SHARP S',
                preset: {
                  'h1x': 0.46, 'h1y': 0.08,
                  'mx': 0.50, 'my': 0.50,
                  'h2x': 0.54, 'h2y': 0.92,
                },
              ),
              _buildPresetButton(
                label: 'PUNCHY ATTACK',
                preset: {
                  'h1x': 0.20, 'h1y': 0.45,
                  'mx': 0.35, 'my': 0.75,
                  'h2x': 0.50, 'h2y': 0.95,
                },
              ),
              _buildPresetButton(
                label: 'LATE SWELL',
                preset: {
                  'h1x': 0.50, 'h1y': 0.05,
                  'mx': 0.65, 'my': 0.25,
                  'h2x': 0.80, 'h2y': 0.55,
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

              // User-saved custom presets
              if (widget.customPresets.isNotEmpty) ...[
                Container(
                  height: 16,
                  width: 1,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  color: Colors.grey[700],
                ),
                ...widget.customPresets.entries.map((entry) {
                  return _buildCustomPresetChip(
                    name: entry.key,
                    preset: entry.value,
                  );
                }),
              ],
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
    bool enabled = true,
  }) {
    final color = enabled ? widget.accentColor : Colors.grey[600]!;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
        decoration: BoxDecoration(
          color: enabled
              ? widget.accentColor.withValues(alpha: 0.12)
              : Colors.grey.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: enabled
                ? widget.accentColor.withValues(alpha: 0.4)
                : Colors.grey.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 10, color: color),
            const SizedBox(width: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 8.5,
                fontWeight: FontWeight.w700,
                color: color,
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

  Widget _buildCustomPresetChip({
    required String name,
    required Map<String, double> preset,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 5),
      child: Container(
        padding: const EdgeInsets.only(left: 7, right: 3, top: 2, bottom: 2),
        decoration: BoxDecoration(
          color: const Color(0xFFFF9100).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: const Color(0xFFFF9100).withValues(alpha: 0.4),
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: () => _applyPreset(preset),
              child: Text(
                name.toUpperCase(),
                style: const TextStyle(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFFFB74D),
                ),
              ),
            ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: () {
                final updated = Map<String, Map<String, double>>.from(widget.customPresets);
                updated.remove(name);
                widget.onCustomPresetsChanged?.call(updated);
              },
              child: const Icon(Icons.close, size: 10, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

class _VectorBezierCanvasPainter extends CustomPainter {
  final VectorBezierCurve curve;
  final bool isFadeIn;
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
  final double fadeProgress;
  final bool isFading;
  final bool isFadingIn;
  final bool isFadingOut;
  final bool isFadePaused;
  final double currentVolumeFraction;

  _VectorBezierCanvasPainter({
    required this.curve,
    required this.isFadeIn,
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
    this.fadeProgress = 0.0,
    this.isFading = false,
    this.isFadingIn = false,
    this.isFadingOut = false,
    this.isFadePaused = false,
    this.currentVolumeFraction = 0.5,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double cw = size.width - 2 * pad;
    final double ch = size.height - 2 * pad;

    Offset toScreen(double normX, double normY) {
      if (isFadeIn) {
        return Offset(pad + normX * cw, pad + (1.0 - normY) * ch);
      } else {
        // Fade Out descends top-to-bottom
        return Offset(pad + normX * cw, pad + normY * ch);
      }
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

    // 2. Reference diagonal
    final refPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.1)
      ..strokeWidth = 0.8;
    canvas.drawLine(toScreen(0.0, 0.0), toScreen(1.0, 1.0), refPaint);

    // 3. Collinear Tangent Line through Middle Anchor M
    final p0 = toScreen(0.0, 0.0);
    final p1 = toScreen(1.0, 1.0);
    final h1 = toScreen(h1x, h1y);
    final pm = toScreen(mx, my);
    final h2 = toScreen(h2x, h2y);

    final tangentPaint = Paint()
      ..color = const Color(0xFF00E5FF).withValues(alpha: 0.8)
      ..strokeWidth = 1.8;

    // Straight collinear tangent line passing directly through M
    canvas.drawLine(h1, pm, tangentPaint);
    canvas.drawLine(pm, h2, tangentPaint);

    // Center point subtle indicator guides
    final guidePaint = Paint()
      ..color = const Color(0xFFFF9100).withValues(alpha: 0.25)
      ..strokeWidth = 1.0;
    canvas.drawLine(Offset(pm.dx, pad), Offset(pm.dx, pad + ch), guidePaint);
    canvas.drawLine(Offset(pad, pm.dy), Offset(pad + cw, pm.dy), guidePaint);

    // 4. Main Continuous Bézier Spline with Gradient Glow
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

    // 6. Live Animation Cursor & Progress Sweep
    final bool isThisTabFading = (isFadeIn && isFadingIn) || (!isFadeIn && isFadingOut);
    if (isThisTabFading && fadeProgress > 0.0) {
      final double t = fadeProgress.clamp(0.0, 1.0);
      final double liveY = curve.transform(t);
      final Offset livePt = toScreen(t, liveY);

      // Progress filled sweep path under the curve
      final progressSweepPath = Path();
      final int activeSteps = (t * 100).round();
      if (activeSteps > 0) {
        final startPt = toScreen(0.0, curve.transform(0.0));
        progressSweepPath.moveTo(startPt.dx, startPt.dy);
        for (int i = 1; i <= activeSteps; i++) {
          final double stepT = (i / 100.0).clamp(0.0, t);
          final stepPt = toScreen(stepT, curve.transform(stepT));
          progressSweepPath.lineTo(stepPt.dx, stepPt.dy);
        }
        if (isFadeIn) {
          progressSweepPath.lineTo(livePt.dx, pad + ch);
          progressSweepPath.lineTo(pad, pad + ch);
        } else {
          progressSweepPath.lineTo(livePt.dx, pad);
          progressSweepPath.lineTo(pad, pad);
        }
        progressSweepPath.close();

        final sweepPaint = Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              accentColor.withValues(alpha: 0.35),
              accentColor.withValues(alpha: 0.05),
            ],
          ).createShader(Rect.fromLTWH(pad, pad, cw, ch))
          ..style = PaintingStyle.fill;
        canvas.drawPath(progressSweepPath, sweepPaint);
      }

      // Vertical cursor line
      final cursorPaint = Paint()
        ..color = (isFadePaused ? Colors.amber : const Color(0xFFFF007F)).withValues(alpha: 0.85)
        ..strokeWidth = 1.8;
      canvas.drawLine(
        Offset(livePt.dx, pad),
        Offset(livePt.dx, pad + ch),
        cursorPaint,
      );

      // Pulsing live head riding the curve
      final headGlowPaint = Paint()
        ..color = (isFadePaused ? Colors.amber : const Color(0xFFFF007F)).withValues(alpha: 0.45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawCircle(livePt, 11, headGlowPaint);

      final headMidPaint = Paint()
        ..color = isFadePaused ? Colors.amber : const Color(0xFFFF007F);
      canvas.drawCircle(livePt, 6, headMidPaint);

      final headCorePaint = Paint()..color = Colors.white;
      canvas.drawCircle(livePt, 3, headCorePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _VectorBezierCanvasPainter oldDelegate) {
    return true;
  }
}
