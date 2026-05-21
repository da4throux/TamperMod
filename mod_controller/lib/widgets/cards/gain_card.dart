// Copyright (c) 2026 TamperMod Contributors
// Licensed under the MIT License

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/plugin_instance.dart';
import '../../utils/curves.dart';
import '../common/fade_button.dart';
import '../common/module_help_sheet.dart';
import '../common/size_toggle_button.dart';
import '../painters/fade_curve_painter.dart';
import '../painters/range_overlay_painter.dart';
import 'base_card.dart';

/// Gain/volume controller card widget
class GainCard extends StatefulWidget {
  final PluginInstance pedal;
  final String size;
  final bool isDarkMode;
  final Color glowColor;
  final String displayName;
  final double currentValue;
  final bool isMuted;
  final bool isFading;
  final bool isFadingIn;
  final bool isFadingOut;
  final double fadeProgress;
  final double rangeStart;
  final double rangeEnd;
  final String fadeShape;
  final Map<String, double> customParams;
  final int fadeBars;

  final ValueChanged<double> onVolumeChanged;
  final VoidCallback onMuteToggled;
  final VoidCallback onRenamePressed;
  final VoidCallback onColorPickerPressed;
  final VoidCallback onHighlightPressed;
  final VoidCallback onSizeToggled;
  final ValueChanged<bool> onBypassToggle;
  final void Function(double start, double end) onFadeRangeChanged;
  final ValueChanged<String> onFadeShapeChanged;
  final void Function(Map<String, double> params) onCustomCurveParamsChanged;
  final void Function(bool fadeIn) onTriggerFade;
  final ValueChanged<String> onOpenUri;

  const GainCard({
    super.key,
    required this.pedal,
    required this.size,
    required this.isDarkMode,
    required this.glowColor,
    required this.displayName,
    required this.currentValue,
    required this.isMuted,
    required this.isFading,
    required this.isFadingIn,
    required this.isFadingOut,
    required this.fadeProgress,
    required this.rangeStart,
    required this.rangeEnd,
    required this.fadeShape,
    required this.customParams,
    this.fadeBars = 4,
    required this.onVolumeChanged,
    required this.onMuteToggled,
    required this.onRenamePressed,
    required this.onColorPickerPressed,
    required this.onHighlightPressed,
    required this.onSizeToggled,
    required this.onBypassToggle,
    required this.onFadeRangeChanged,
    required this.onFadeShapeChanged,
    required this.onCustomCurveParamsChanged,
    required this.onTriggerFade,
    required this.onOpenUri,
  });

  @override
  State<GainCard> createState() => _GainCardState();
}

class _GainCardState extends State<GainCard> {
  @override
  Widget build(BuildContext context) {
    final double minRange = widget.pedal.minGain;
    final double maxRange = widget.pedal.maxGain;
    final double clampedValue = widget.currentValue.clamp(minRange, maxRange);
    final bool isBypassed = widget.pedal.isBypassed;
    final Color accentColor = isBypassed ? Colors.grey[600]! : widget.glowColor;

    // ── Volume slider (bare) ───────────────────────────────────────────
    Widget buildVolumeSlider({bool compact = false}) {
      return SliderTheme(
        data: SliderTheme.of(context).copyWith(
          activeTrackColor: accentColor,
          inactiveTrackColor: widget.isDarkMode
              ? Colors.grey[850]
              : Colors.grey[300],
          trackHeight: compact ? 4.0 : 12.0,
          thumbColor: isBypassed
              ? Colors.grey[400]
              : (widget.isDarkMode ? Colors.white : Colors.grey[100]),
          thumbShape: RoundSliderThumbShape(
            enabledThumbRadius: compact ? 6.0 : 15.0,
          ),
          overlayColor: accentColor.withOpacity(0.2),
          overlayShape: RoundSliderOverlayShape(
            overlayRadius: compact ? 12.0 : 28.0,
          ),
        ),
        child: Slider(
          value: clampedValue,
          min: minRange,
          max: maxRange,
          onChanged: isBypassed ? null : widget.onVolumeChanged,
        ),
      );
    }

    // ── Slider + range overlay triangles ───────────────────────────────
    Widget buildSliderWithRangeOverlay({bool compact = false}) {
      final double thumbPad = compact ? 12.0 : 28.0;
      final double trackHeight = compact ? 4.0 : 12.0;

      Widget content = Stack(
        clipBehavior: Clip.none,
        children: [
          buildVolumeSlider(compact: compact),
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: RangeOverlayPainter(
                  accentColor: accentColor,
                  rangeStart: widget.rangeStart,
                  rangeEnd: widget.rangeEnd,
                  thumbPadding: thumbPad,
                  trackHeight: trackHeight,
                  isDarkMode: widget.isDarkMode,
                ),
              ),
            ),
          ),
        ],
      );

      if (widget.size == 'expanded') {
        return LayoutBuilder(
          builder: (context, constraints) {
            final double trackW = constraints.maxWidth - 2 * thumbPad;
            if (trackW <= 0) return content;

            final double xStart = thumbPad + widget.rangeStart * trackW;
            final double xEnd = thumbPad + widget.rangeEnd * trackW;

            return Stack(
              clipBehavior: Clip.none,
              children: [
                content,
                // Left triangle drag handle
                Positioned(
                  left: xStart - 20,
                  top: 0,
                  bottom: 0,
                  width: 40,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onHorizontalDragUpdate: (details) {
                      final double delta = details.primaryDelta! / trackW;
                      final double newStart = (widget.rangeStart + delta).clamp(
                        0.0,
                        widget.rangeEnd - 0.05,
                      );
                      widget.onFadeRangeChanged(newStart, widget.rangeEnd);
                    },
                    onDoubleTap: () {
                      // B1: Double-tap sets gain to this level (start of fade range)
                      widget.onVolumeChanged(
                        widget.pedal.minGain +
                            widget.rangeStart *
                                (widget.pedal.maxGain - widget.pedal.minGain),
                      );
                    },
                    child: Container(color: Colors.transparent),
                  ),
                ),
                // Right triangle drag handle
                Positioned(
                  left: xEnd - 20,
                  top: 0,
                  bottom: 0,
                  width: 40,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onHorizontalDragUpdate: (details) {
                      final double delta = details.primaryDelta! / trackW;
                      final double newEnd = (widget.rangeEnd + delta).clamp(
                        widget.rangeStart + 0.05,
                        1.0,
                      );
                      widget.onFadeRangeChanged(widget.rangeStart, newEnd);
                    },
                    onDoubleTap: () {
                      // B1: Double-tap sets gain to this level (end of fade range)
                      widget.onVolumeChanged(
                        widget.pedal.minGain +
                            widget.rangeEnd *
                                (widget.pedal.maxGain - widget.pedal.minGain),
                      );
                    },
                    child: Container(color: Colors.transparent),
                  ),
                ),
              ],
            );
          },
        );
      }

      return content;
    }

    // ── Mute speaker icon ────────────────────────────────────────────
    Widget buildMuteIcon({double size = 22}) {
      return GestureDetector(
        onTap: widget.onMuteToggled,
        child: Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Icon(
            widget.isMuted ? Icons.volume_off : Icons.volume_up,
            color: widget.isMuted ? const Color(0xFFFF007F) : accentColor,
            size: size,
          ),
        ),
      );
    }

    // ── Fixed-width dB value box ─────────────────────────────────────
    Widget buildDbBox({double fontSize = 14}) {
      return SizedBox(
        width: 72,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
          decoration: BoxDecoration(
            color: widget.isDarkMode ? Colors.black : Colors.grey[900],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: accentColor.withOpacity(0.5)),
          ),
          child: Text(
            '${clampedValue >= 0 ? "+" : ""}${clampedValue.toStringAsFixed(1)} dB',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w900,
              color: accentColor,
              fontFamily: 'monospace',
            ),
          ),
        ),
      );
    }

    // ── Size-toggle icon ─────────────────────────────────────────────
    Widget buildSizeToggle() {
      return SizeToggleButton(
        instanceId: widget.pedal.instance,
        currentSize: widget.size,
        accentColor: accentColor,
        isDarkMode: widget.isDarkMode,
        onTap: widget.onSizeToggled,
      );
    }

    return BaseCard(
      glowColor: widget.glowColor,
      isBypassed: isBypassed,
      isDarkMode: widget.isDarkMode,
      onLongPress: widget.onColorPickerPressed,
      child: Padding(
        padding: EdgeInsets.all(widget.size == 'compact' ? 10.0 : 16.0),
        child: widget.size == 'compact'
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row 1: size-toggle | Name | dB | mute
                  Row(
                    children: [
                      buildSizeToggle(),
                      const SizedBox(width: 4),
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: widget.onHighlightPressed,
                          onLongPress: widget.onRenamePressed,
                          child: Text(
                            widget.displayName.toUpperCase(),
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w900,
                              color: accentColor,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${clampedValue >= 0 ? "+" : ""}${clampedValue.toStringAsFixed(1)} dB',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: accentColor,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(width: 4),
                      buildMuteIcon(size: 18),
                    ],
                  ),
                  const Spacer(),
                  // Row 2: Slider with overlay
                  Row(
                    children: [
                      Icon(
                        Icons.volume_mute,
                        color: widget.isDarkMode
                            ? Colors.grey[isBypassed ? 700 : 600]
                            : Colors.grey[isBypassed ? 600 : 700],
                        size: 18,
                      ),
                      Expanded(
                        child: buildSliderWithRangeOverlay(compact: true),
                      ),
                      Icon(Icons.volume_up, color: accentColor, size: 18),
                    ],
                  ),
                  // Range % + min/max labels
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${minRange.toStringAsFixed(1)} dB',
                        style: TextStyle(fontSize: 9, color: Colors.grey[600]),
                      ),
                      Text(
                        '${(widget.rangeStart * 100).round()}–${(widget.rangeEnd * 100).round()}%',
                        style: TextStyle(
                          fontSize: 9,
                          color: accentColor.withOpacity(0.7),
                          fontFamily: 'monospace',
                        ),
                      ),
                      Text(
                        '${maxRange >= 0 ? "+" : ""}${maxRange.toStringAsFixed(1)} dB',
                        style: TextStyle(fontSize: 9, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Row 3: FADE IN | FADE OUT (stacked vertically)
                  Column(
                    children: [
                      FadeButton(
                        label: 'FADE IN',
                        icon: Icons.trending_up,
                        isBypassed: isBypassed,
                        onTap: () => widget.onTriggerFade(true),
                        accentColor: accentColor,
                        isFading: widget.isFadingIn,
                      ),
                      const SizedBox(height: 4),
                      FadeButton(
                        label: 'FADE OUT',
                        icon: Icons.trending_down,
                        isBypassed: isBypassed,
                        onTap: () => widget.onTriggerFade(false),
                        accentColor: accentColor,
                        isFading: widget.isFadingOut,
                      ),
                    ],
                  ),
                ],
              )
            : widget.size == 'regular'
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row 1 header
                  Row(
                    children: [
                      buildSizeToggle(),
                      const SizedBox(width: 4),
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: widget.onHighlightPressed,
                          onLongPress: widget.onRenamePressed,
                          child: Text(
                            widget.displayName.toUpperCase(),
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: accentColor,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => ModuleHelpSheet.show(
                          context,
                          'gain',
                          widget.isDarkMode,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(
                            Icons.help_outline,
                            size: 14,
                            color: accentColor.withOpacity(0.7),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      buildDbBox(),
                      const SizedBox(width: 4),
                      buildMuteIcon(),
                    ],
                  ),
                  const Spacer(),
                  // URI
                  GestureDetector(
                    onTap: () => widget.onOpenUri(widget.pedal.uri),
                    child: Text(
                      widget.pedal.uri,
                      style: TextStyle(
                        fontSize: 8.5,
                        color: widget.isDarkMode
                            ? const Color(0xFF00FFCC)
                            : const Color(0xFF00B3FF),
                        decoration: TextDecoration.underline,
                        fontFamily: 'monospace',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Slider Row
                  Row(
                    children: [
                      Icon(
                        Icons.volume_mute,
                        color: widget.isDarkMode
                            ? Colors.grey[isBypassed ? 700 : 600]
                            : Colors.grey[isBypassed ? 600 : 700],
                        size: 20,
                      ),
                      Expanded(
                        child: buildSliderWithRangeOverlay(compact: false),
                      ),
                      Icon(Icons.volume_up, color: accentColor, size: 20),
                    ],
                  ),
                  const SizedBox(height: 2),
                  // Labels
                  Row(
                    children: [
                      Text(
                        '${minRange.toStringAsFixed(1)} dB',
                        style: TextStyle(
                          fontSize: 10,
                          color: widget.isDarkMode
                              ? Colors.grey[isBypassed ? 700 : 600]
                              : Colors.grey[isBypassed ? 600 : 700],
                        ),
                      ),
                      Expanded(
                        child: Text(
                          '${(widget.rangeStart * 100).round()}–${(widget.rangeEnd * 100).round()}%',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 9,
                            color: accentColor.withOpacity(0.7),
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                      Text(
                        '${maxRange >= 0 ? "+" : ""}${maxRange.toStringAsFixed(1)} dB',
                        style: TextStyle(
                          fontSize: 10,
                          color: widget.isDarkMode
                              ? Colors.grey[isBypassed ? 700 : 600]
                              : Colors.grey[isBypassed ? 600 : 700],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Fade buttons
                  Row(
                    children: [
                      FadeButton(
                        label: 'FADE IN',
                        icon: Icons.trending_up,
                        isBypassed: isBypassed,
                        onTap: () => widget.onTriggerFade(true),
                        accentColor: accentColor,
                        isFading: widget.isFadingIn,
                      ),
                      FadeButton(
                        label: 'FADE OUT',
                        icon: Icons.trending_down,
                        isBypassed: isBypassed,
                        onTap: () => widget.onTriggerFade(false),
                        accentColor: accentColor,
                        isFading: widget.isFadingOut,
                      ),
                    ],
                  ),
                ],
              )
            : _buildExpandedView(
                minRange: minRange,
                maxRange: maxRange,
                clampedValue: clampedValue,
                isBypassed: isBypassed,
                accentColor: accentColor,
                buildVolumeSlider: buildVolumeSlider,
                buildSliderWithRangeOverlay: buildSliderWithRangeOverlay,
                buildMuteIcon: buildMuteIcon,
                buildDbBox: buildDbBox,
                buildSizeToggle: buildSizeToggle,
              ),
      ),
    );
  }

  Widget _buildExpandedView({
    required double minRange,
    required double maxRange,
    required double clampedValue,
    required bool isBypassed,
    required Color accentColor,
    required Widget Function({bool compact}) buildVolumeSlider,
    required Widget Function({bool compact}) buildSliderWithRangeOverlay,
    required Widget Function({double size}) buildMuteIcon,
    required Widget Function({double fontSize}) buildDbBox,
    required Widget Function() buildSizeToggle,
  }) {
    // Resolve display curve
    final String shapeName = widget.fadeShape;
    final Curve displayCurve;
    switch (shapeName) {
      case 'linear':
        displayCurve = Curves.linear;
        break;
      case 'easeIn':
        displayCurve = Curves.easeIn;
        break;
      case 'easeOut':
        displayCurve = Curves.easeOut;
        break;
      case 'custom':
        displayCurve = CustomSCurve(
          cx: widget.customParams['cx'] ?? 0.5,
          cy: widget.customParams['cy'] ?? 0.5,
          slope: widget.customParams['slope'] ?? 1.0,
        );
        break;
      default:
        displayCurve = Curves.easeInOut;
    }

    final double startDb = minRange + widget.rangeStart * (maxRange - minRange);
    final double endDb = minRange + widget.rangeEnd * (maxRange - minRange);

    const List<Map<String, String>> shapeOptions = [
      {'key': 'linear', 'label': 'LINEAR'},
      {'key': 'easeInOut', 'label': 'S1'},
      {'key': 'easeIn', 'label': 'S2'},
      {'key': 'easeOut', 'label': 'S3'},
      {'key': 'custom', 'label': 'CUSTOM'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header
        Row(
          children: [
            buildSizeToggle(),
            const SizedBox(width: 4),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onHighlightPressed,
                onLongPress: widget.onRenamePressed,
                child: Text(
                  widget.displayName.toUpperCase(),
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: accentColor,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
            GestureDetector(
              onTap: () =>
                  ModuleHelpSheet.show(context, 'gain', widget.isDarkMode),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Icon(
                  Icons.help_outline,
                  size: 14,
                  color: accentColor.withOpacity(0.7),
                ),
              ),
            ),
            const SizedBox(width: 4),
            buildDbBox(),
            const SizedBox(width: 4),
            buildMuteIcon(),
          ],
        ),
        const SizedBox(height: 4),
        // URI
        GestureDetector(
          onTap: () => widget.onOpenUri(widget.pedal.uri),
          child: Text(
            widget.pedal.uri,
            style: TextStyle(
              fontSize: 8.5,
              color: widget.isDarkMode
                  ? const Color(0xFF00FFCC)
                  : const Color(0xFF00B3FF),
              decoration: TextDecoration.underline,
              fontFamily: 'monospace',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Volume slider with overlay
        Row(
          children: [
            Icon(
              Icons.volume_mute,
              color: widget.isDarkMode
                  ? Colors.grey[isBypassed ? 700 : 600]
                  : Colors.grey[isBypassed ? 600 : 700],
              size: 20,
            ),
            Expanded(child: buildSliderWithRangeOverlay(compact: false)),
            Icon(Icons.volume_up, color: accentColor, size: 20),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${minRange.toStringAsFixed(1)} dB (Start: ${startDb.toStringAsFixed(1)} dB)',
              style: TextStyle(
                fontSize: 9,
                color: Colors.grey[600],
                fontFamily: 'monospace',
              ),
            ),
            Text(
              '${(widget.rangeStart * 100).round()}–${(widget.rangeEnd * 100).round()}%',
              style: TextStyle(
                fontSize: 9,
                color: accentColor.withOpacity(0.7),
                fontFamily: 'monospace',
              ),
            ),
            Text(
              '${maxRange >= 0 ? "+" : ""}${maxRange.toStringAsFixed(1)} dB (End: ${endDb.toStringAsFixed(1)} dB)',
              style: TextStyle(
                fontSize: 9,
                color: Colors.grey[600],
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Fade Shape Selector
        Text(
          'FADE SHAPE',
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: accentColor.withOpacity(0.7),
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: shapeOptions.map((opt) {
            final bool isSelected = shapeName == opt['key'];
            return Expanded(
              child: GestureDetector(
                onTap: () => widget.onFadeShapeChanged(opt['key']!),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? accentColor.withOpacity(0.2)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isSelected ? accentColor : Colors.grey[700]!,
                      width: isSelected ? 1.5 : 1.0,
                    ),
                  ),
                  child: Text(
                    opt['label']!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? accentColor : Colors.grey[500],
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),

        // Custom S-Curve sliders
        if (shapeName == 'custom') ...[
          const SizedBox(height: 8),
          Text(
            'CUSTOM CURVE',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: accentColor.withOpacity(0.7),
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          ...['cx', 'cy', 'slope'].map((param) {
            final double val = widget.customParams[param] ?? 0.5;
            final Map<String, String> labels = {
              'cx': 'CENTER X',
              'cy': 'CENTER Y',
              'slope': 'BLEND',
            };
            return Row(
              children: [
                SizedBox(
                  width: 60,
                  child: Text(
                    labels[param]!,
                    style: TextStyle(fontSize: 8, color: Colors.grey[500]),
                  ),
                ),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: accentColor.withOpacity(0.7),
                      inactiveTrackColor: accentColor.withOpacity(0.15),
                      thumbColor: accentColor,
                      trackHeight: 3,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 7,
                      ),
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 14,
                      ),
                    ),
                    child: Slider(
                      value: val,
                      min: 0.0,
                      max: 1.0,
                      onChanged: (v) {
                        widget.onCustomCurveParamsChanged({
                          ...widget.customParams,
                          param: v,
                        });
                      },
                    ),
                  ),
                ),
                SizedBox(
                  width: 32,
                  child: Text(
                    val.toStringAsFixed(2),
                    style: TextStyle(
                      fontSize: 9,
                      fontFamily: 'monospace',
                      color: accentColor.withOpacity(0.8),
                    ),
                  ),
                ),
              ],
            );
          }),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: () {
                final String json = jsonEncode({
                  'shape': 'custom',
                  ...widget.customParams,
                });
                Clipboard.setData(ClipboardData(text: json));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Custom curve copied to clipboard'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: accentColor.withOpacity(0.5)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'EXPORT',
                  style: TextStyle(
                    fontSize: 9,
                    color: accentColor,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 8),

        // Live Fade Curve Visualizer
        SizedBox(
          height: 120,
          child: CustomPaint(
            painter: FadeCurvePainter(
              accentColor: accentColor,
              curve: displayCurve,
              progress: widget.fadeProgress,
              bars: widget.fadeBars,
              rangeStart: widget.rangeStart,
              rangeEnd: widget.rangeEnd,
              isFadeOut: widget.isFadingOut,
            ),
            child: const SizedBox.expand(),
          ),
        ),
        const SizedBox(height: 8),

        // Fade buttons
        Row(
          children: [
            FadeButton(
              label: 'FADE IN',
              icon: Icons.trending_up,
              isBypassed: isBypassed,
              onTap: () => widget.onTriggerFade(true),
              accentColor: accentColor,
              isFading: widget.isFadingIn,
            ),
            FadeButton(
              label: 'FADE OUT',
              icon: Icons.trending_down,
              isBypassed: isBypassed,
              onTap: () => widget.onTriggerFade(false),
              accentColor: accentColor,
              isFading: widget.isFadingOut,
            ),
          ],
        ),
      ],
    );
  }
}
