// Copyright (c) 2026 TamperMod Contributors
// Licensed under the MIT License

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/plugin_instance.dart';
import '../../utils/curves.dart';
import '../../utils/plugin_category.dart';
import '../common/fade_button.dart';
import '../common/module_help_sheet.dart';
import '../common/size_toggle_button.dart';
import '../common/vector_bezier_editor.dart';
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
  final Map<String, double> customParamsOut;
  final Map<String, Map<String, double>> customPresets;
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
  final void Function(Map<String, double> params) onCustomCurveParamsOutChanged;
  final ValueChanged<Map<String, Map<String, double>>>? onCustomPresetsChanged;
  final void Function(bool fadeIn) onTriggerFade;
  final ValueChanged<String> onOpenUri;

  final double? liveMeterValue;
  final String mode;
  final ValueChanged<String>? onModeChanged;

  final bool isFadePaused;
  final VoidCallback? onPauseResumeFade;
  final VoidCallback? onStopFade;

  const GainCard({
    super.key,
    required this.pedal,
    required this.size,
    required this.isDarkMode,
    required this.glowColor,
    required this.displayName,
    required this.currentValue,
    this.liveMeterValue,
    required this.isMuted,
    required this.isFading,
    required this.isFadingIn,
    required this.isFadingOut,
    required this.fadeProgress,
    this.mode = 'fade',
    this.onModeChanged,
    this.isFadePaused = false,
    this.onPauseResumeFade,
    this.onStopFade,
    required this.rangeStart,
    required this.rangeEnd,
    required this.fadeShape,
    required this.customParams,
    this.customParamsOut = const {},
    this.customPresets = const {},
    required this.fadeBars,
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
    required this.onCustomCurveParamsOutChanged,
    this.onCustomPresetsChanged,
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

    final category = PluginCategoryHelper.getCategoryForPlugin(widget.pedal);

    // ── Size-toggle icon ─────────────────────────────────────────────
    Widget buildSizeToggle() {
      return SizeToggleButton(
        instanceId: widget.pedal.instance,
        currentSize: widget.size,
        accentColor: accentColor,
        isDarkMode: widget.isDarkMode,
        pedal: widget.pedal,
        onTap: widget.onSizeToggled,
        onLongPress: widget.onRenamePressed,
      );
    }

    Widget buildStandardHeaderRow(BuildContext context) {
      return Row(
        children: [
          // 1. Size Toggle & Category Icon
          buildSizeToggle(),
          const SizedBox(width: 6),

          // 2. Card Name (Expanded) + Category Micro-Badge
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onHighlightPressed,
              onLongPress: widget.onRenamePressed,
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      widget.displayName.toUpperCase(),
                      style: TextStyle(
                        fontSize: widget.size == 'compact' ? 13.0 : 16.0,
                        fontWeight: FontWeight.w900,
                        color: accentColor,
                        letterSpacing: 0.8,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: category.defaultColor.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: category.defaultColor.withValues(alpha: 0.5),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      category.shortCode,
                      style: TextStyle(
                        fontSize: 7.5,
                        fontWeight: FontWeight.w900,
                        color: category.defaultColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 4),

          // 3. Info Button
          GestureDetector(
            onTap: () => ModuleHelpSheet.show(context, 'gain', widget.isDarkMode),
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: widget.isDarkMode ? const Color(0xFF1C2433) : Colors.grey[200],
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: widget.isDarkMode ? Colors.grey[800]! : Colors.grey[300]!,
                  width: 0.8,
                ),
              ),
              child: Icon(
                Icons.info_outline,
                size: 13,
                color: widget.isDarkMode ? Colors.grey[300] : Colors.grey[700],
              ),
            ),
          ),
          const SizedBox(width: 4),

          // 4. Mode Toggle (Fade Automation vs Direct Gain & Mute)
          GestureDetector(
            onTap: () {
              final nextMode = widget.mode == 'direct' ? 'fade' : 'direct';
              widget.onModeChanged?.call(nextMode);
            },
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: widget.mode == 'direct'
                    ? accentColor.withOpacity(widget.isDarkMode ? 0.25 : 0.18)
                    : (widget.isDarkMode ? const Color(0xFF1C2433) : Colors.grey[200]),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: widget.mode == 'direct'
                      ? accentColor
                      : (widget.isDarkMode ? Colors.grey[800]! : Colors.grey[300]!),
                  width: widget.mode == 'direct' ? 1.2 : 0.8,
                ),
              ),
              child: Icon(
                widget.mode == 'direct' ? Icons.tune : Icons.auto_graph,
                size: 13,
                color: widget.mode == 'direct'
                    ? accentColor
                    : (widget.isDarkMode ? Colors.grey[300] : Colors.grey[700]),
              ),
            ),
          ),
          const SizedBox(width: 4),

          // 5. Edit Button
          GestureDetector(
            onTap: widget.onRenamePressed,
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: widget.isDarkMode ? const Color(0xFF1C2433) : Colors.grey[200],
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: widget.isDarkMode ? Colors.grey[800]! : Colors.grey[300]!,
                  width: 0.8,
                ),
              ),
              child: Icon(
                Icons.edit,
                size: 13,
                color: widget.isDarkMode ? Colors.grey[300] : Colors.grey[700],
              ),
            ),
          ),
          const SizedBox(width: 4),

          // 6. Focus Button
          GestureDetector(
            onTap: widget.onHighlightPressed,
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: widget.isDarkMode ? const Color(0xFF1C2433) : Colors.grey[200],
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: widget.isDarkMode ? Colors.grey[800]! : Colors.grey[300]!,
                  width: 0.8,
                ),
              ),
              child: Icon(
                Icons.radar,
                size: 13,
                color: accentColor,
              ),
            ),
          ),
          const SizedBox(width: 4),

          // 7. Power Button
          GestureDetector(
            onTap: () => widget.onBypassToggle(!isBypassed),
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: !isBypassed
                    ? widget.glowColor.withOpacity(widget.isDarkMode ? 0.25 : 0.18)
                    : (widget.isDarkMode ? const Color(0xFF1C2433) : Colors.grey[200]),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: !isBypassed ? widget.glowColor : Colors.grey[700]!,
                  width: !isBypassed ? 1.2 : 0.8,
                ),
              ),
              child: Icon(
                Icons.power_settings_new,
                size: 14,
                color: !isBypassed ? widget.glowColor : Colors.grey[500],
              ),
            ),
          ),
        ],
      );
    }

    // ── Direct Gain & Mute UI Component ──────────────────────────────
    Widget buildGiantMuteGainButton({required bool isCompact, bool takeFullHeight = false}) {
      final bool isMuted = widget.isMuted;
      final double displayDb = widget.liveMeterValue ?? clampedValue;
      final bool hasDistinctMeter = widget.liveMeterValue != null && (widget.liveMeterValue! - clampedValue).abs() > 0.05;
      
      // Neutral muted colors (greyish/charcoal, NO bright red/pink glow)
      final Color activeColor = isMuted ? const Color(0xFF8B949E) : accentColor;
      final Color bg = isMuted
          ? (widget.isDarkMode ? const Color(0xFF161B22) : const Color(0xFFE5E7EB))
          : activeColor.withOpacity(widget.isDarkMode ? 0.20 : 0.14);
      final Color border = isMuted
          ? (widget.isDarkMode ? const Color(0xFF30363D) : const Color(0xFFCBD5E1))
          : activeColor.withOpacity(widget.isDarkMode ? 0.8 : 0.6);

      final Widget buttonContent = Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: isCompact ? 10 : 14,
          vertical: isCompact ? (takeFullHeight ? 10 : 7) : 9,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: border, width: isMuted ? 1.2 : 1.5),
          boxShadow: isMuted
              ? null
              : [
                  BoxShadow(
                    color: activeColor.withOpacity(0.22),
                    blurRadius: 8,
                  ),
                ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Speaker Icon Circle
            Container(
              padding: EdgeInsets.all(isCompact ? 6 : 8),
              decoration: BoxDecoration(
                color: isMuted
                    ? (widget.isDarkMode ? const Color(0xFF21262D) : const Color(0xFFD1D5DB))
                    : (widget.isDarkMode ? const Color(0xFF0F141C) : Colors.white),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isMuted
                      ? (widget.isDarkMode ? const Color(0xFF30363D) : Colors.grey[400]!)
                      : activeColor.withOpacity(0.4),
                  width: 0.8,
                ),
              ),
              child: Icon(
                isMuted ? Icons.volume_off : Icons.volume_up,
                size: isCompact ? 18 : 22,
                color: isMuted ? const Color(0xFF8B949E) : activeColor,
              ),
            ),
            const SizedBox(width: 10),
            // Text & Gain Readout Container (Solid dark base to preserve high contrast and readability)
            Expanded(
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isCompact ? 8 : 10,
                  vertical: isCompact ? 4 : 5,
                ),
                decoration: BoxDecoration(
                  color: widget.isDarkMode ? const Color(0xFF0D1117) : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isMuted
                        ? (widget.isDarkMode ? const Color(0xFF21262D) : const Color(0xFFE2E8F0))
                        : activeColor.withOpacity(widget.isDarkMode ? 0.35 : 0.25),
                    width: 0.8,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${displayDb >= 0 ? "+" : ""}${displayDb.toStringAsFixed(1)} dB',
                                style: TextStyle(
                                  fontSize: isCompact ? 14 : 17,
                                  fontWeight: FontWeight.w900,
                                  color: isMuted
                                      ? (widget.isDarkMode ? const Color(0xFFC9D1D9) : Colors.grey[800])
                                      : activeColor,
                                  fontFamily: 'monospace',
                                  letterSpacing: 0.5,
                                ),
                              ),
                              if (hasDistinctMeter) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: activeColor.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                  child: Text(
                                    'KNOB: ${clampedValue >= 0 ? "+" : ""}${clampedValue.toStringAsFixed(1)}',
                                    style: TextStyle(
                                      fontSize: 7.5,
                                      fontWeight: FontWeight.bold,
                                      color: isMuted ? Colors.grey[500] : activeColor.withOpacity(0.9),
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isMuted
                                ? (widget.isDarkMode ? const Color(0xFF21262D) : const Color(0xFFD1D5DB))
                                : activeColor.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: isMuted
                                  ? (widget.isDarkMode ? const Color(0xFF30363D) : const Color(0xFF9CA3AF))
                                  : activeColor.withOpacity(0.5),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            isMuted ? 'MUTED' : 'ACTIVE',
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                              color: isMuted
                                  ? (widget.isDarkMode ? const Color(0xFF8B949E) : Colors.grey[700])
                                  : activeColor,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isMuted
                          ? 'MUTED • TAP TO RESTORE'
                          : 'ACTIVE • TAP TO MUTE',
                      style: TextStyle(
                        fontSize: isCompact ? 8.0 : 8.5,
                        fontWeight: FontWeight.bold,
                        color: isMuted
                            ? (widget.isDarkMode ? const Color(0xFF6E7681) : Colors.grey[600])
                            : (widget.isDarkMode ? Colors.grey[400] : Colors.grey[600]),
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );

      return GestureDetector(
        onTap: isBypassed ? null : widget.onMuteToggled,
        behavior: HitTestBehavior.opaque,
        child: buttonContent,
      );
    }

    Widget buildDirectSliderRow({required bool compact}) {
      return Row(
        children: [
          // Step Down Button [-1.0 dB]
          GestureDetector(
            onTap: isBypassed
                ? null
                : () {
                    final double newVal = (clampedValue - 1.0).clamp(minRange, maxRange);
                    widget.onVolumeChanged(newVal);
                  },
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
              decoration: BoxDecoration(
                color: widget.isDarkMode ? const Color(0xFF1C2433) : Colors.grey[200],
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: widget.isDarkMode ? Colors.grey[800]! : Colors.grey[300]!,
                  width: 0.8,
                ),
              ),
              child: const Text(
                '-1 dB',
                style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: buildVolumeSlider(compact: compact),
          ),
          const SizedBox(width: 4),
          // Step Up Button [+1.0 dB]
          GestureDetector(
            onTap: isBypassed
                ? null
                : () {
                    final double newVal = (clampedValue + 1.0).clamp(minRange, maxRange);
                    widget.onVolumeChanged(newVal);
                  },
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
              decoration: BoxDecoration(
                color: widget.isDarkMode ? const Color(0xFF1C2433) : Colors.grey[200],
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: widget.isDarkMode ? Colors.grey[800]! : Colors.grey[300]!,
                  width: 0.8,
                ),
              ),
              child: const Text(
                '+1 dB',
                style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      );
    }

    Widget buildPauseResumeButton({bool isCompact = false}) {
      final bool isActive = !isBypassed && (widget.isFading || widget.isFadePaused);
      final Color color = isActive
          ? Colors.amber
          : (widget.isDarkMode ? Colors.grey[700]! : Colors.grey[400]!);
      return GestureDetector(
        onTap: isActive ? widget.onPauseResumeFade : null,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: isCompact ? 5 : 7),
          decoration: BoxDecoration(
            color: isActive
                ? Colors.amber.withOpacity(0.18)
                : (widget.isDarkMode ? const Color(0xFF161B22) : Colors.grey[200]),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isActive
                  ? Colors.amber
                  : (widget.isDarkMode ? Colors.grey[800]! : Colors.grey[350]!),
              width: isActive ? 1.2 : 0.8,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                widget.isFadePaused ? Icons.play_arrow : Icons.pause,
                size: isCompact ? 11 : 13,
                color: color,
              ),
              const SizedBox(width: 3),
              Text(
                widget.isFadePaused ? 'RESUME' : 'PAUSE',
                style: TextStyle(
                  fontSize: isCompact ? 8.5 : 9.5,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      );
    }

    Widget buildStopButton({bool isCompact = false}) {
      final bool isActive = !isBypassed && (widget.isFading || widget.isFadePaused);
      final Color color = isActive
          ? const Color(0xFFFF5252)
          : (widget.isDarkMode ? Colors.grey[700]! : Colors.grey[400]!);
      return GestureDetector(
        onTap: isActive ? widget.onStopFade : null,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: isCompact ? 5 : 7),
          decoration: BoxDecoration(
            color: isActive
                ? const Color(0xFFFF5252).withOpacity(0.18)
                : (widget.isDarkMode ? const Color(0xFF161B22) : Colors.grey[200]),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isActive
                  ? const Color(0xFFFF5252)
                  : (widget.isDarkMode ? Colors.grey[800]! : Colors.grey[350]!),
              width: isActive ? 1.2 : 0.8,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.stop,
                size: isCompact ? 11 : 13,
                color: color,
              ),
              const SizedBox(width: 3),
              Text(
                'STOP',
                style: TextStyle(
                  fontSize: isCompact ? 8.5 : 9.5,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      );
    }

    Widget buildFadeTransportRow({bool isCompact = false}) {
      return Row(
        children: [
          Expanded(
            flex: 3,
            child: FadeButton(
              label: 'FADE IN',
              icon: Icons.trending_up,
              isBypassed: isBypassed,
              onTap: () => widget.onTriggerFade(true),
              accentColor: accentColor,
              isFading: widget.isFadingIn,
              isCompact: isCompact,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            flex: 2,
            child: buildPauseResumeButton(isCompact: isCompact),
          ),
          const SizedBox(width: 4),
          Expanded(
            flex: 2,
            child: buildStopButton(isCompact: isCompact),
          ),
          const SizedBox(width: 4),
          Expanded(
            flex: 3,
            child: FadeButton(
              label: 'FADE OUT',
              icon: Icons.trending_down,
              isBypassed: isBypassed,
              onTap: () => widget.onTriggerFade(false),
              accentColor: accentColor,
              isFading: widget.isFadingOut,
              isCompact: isCompact,
            ),
          ),
        ],
      );
    }

    return BaseCard(
      glowColor: widget.glowColor,
      isBypassed: isBypassed,
      isDarkMode: widget.isDarkMode,
      onLongPress: widget.onColorPickerPressed,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: widget.size == 'compact' ? 10.0 : 12.0,
          vertical: widget.size == 'compact' ? 8.0 : 8.0,
        ),
        child: widget.mode == 'direct'
            ? (widget.size == 'compact'
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      buildStandardHeaderRow(context),
                      const SizedBox(height: 6),
                      // Big Mute & Gain Button
                      Expanded(
                        child: buildGiantMuteGainButton(isCompact: true, takeFullHeight: true),
                      ),
                      const SizedBox(height: 6),
                      // Direct Slider Row with [-1 dB] / [+1 dB] Nudge Buttons
                      buildDirectSliderRow(compact: true),
                    ],
                  )
                : widget.size == 'regular'
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header
                          buildStandardHeaderRow(context),
                          const SizedBox(height: 4),
                          // URI + Direct Mode Badge
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: GestureDetector(
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
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: accentColor.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: accentColor.withOpacity(0.4), width: 0.8),
                                ),
                                child: Text(
                                  'DIRECT CONTROL',
                                  style: TextStyle(
                                    fontSize: 7.5,
                                    fontWeight: FontWeight.w900,
                                    color: accentColor,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Giant Mute & Gain Button
                          buildGiantMuteGainButton(isCompact: false),
                          const SizedBox(height: 10),
                          // Direct Slider Row
                          buildDirectSliderRow(compact: false),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header
                          buildStandardHeaderRow(context),
                          const SizedBox(height: 8),
                          // Giant Mute & Gain Button
                          buildGiantMuteGainButton(isCompact: false),
                          const SizedBox(height: 12),
                          // Direct Slider Row
                          buildDirectSliderRow(compact: false),
                          const SizedBox(height: 12),
                          // Range & Unity info bar
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: widget.isDarkMode ? const Color(0xFF0F141C) : Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: widget.isDarkMode ? Colors.grey[850]! : Colors.grey[300]!,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                Text('MIN: ${minRange.toStringAsFixed(1)} dB', style: TextStyle(fontSize: 10, color: Colors.grey[500], fontFamily: 'monospace')),
                                Text('UNITY: 0.0 dB', style: TextStyle(fontSize: 10, color: accentColor, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                                Text('MAX: ${maxRange >= 0 ? "+" : ""}${maxRange.toStringAsFixed(1)} dB', style: TextStyle(fontSize: 10, color: Colors.grey[500], fontFamily: 'monospace')),
                              ],
                            ),
                          ),
                        ],
                      ))
            : widget.size == 'compact'
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row 1: Standard header row
                  buildStandardHeaderRow(context),
                  const SizedBox(height: 4),
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
                  const SizedBox(height: 2),
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
                        '${maxRange.toStringAsFixed(1)} dB',
                        style: TextStyle(fontSize: 9, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Row 4: Top transport controls row
                  Row(
                    children: [
                      Expanded(child: buildPauseResumeButton(isCompact: true)),
                      const SizedBox(width: 4),
                      Expanded(child: buildStopButton(isCompact: true)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Row 5: Fade IN / OUT side by side taking the remaining vertical
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: FadeButton(
                            label: 'FADE IN',
                            icon: Icons.trending_up,
                            isBypassed: isBypassed,
                            onTap: () => widget.onTriggerFade(true),
                            accentColor: accentColor,
                            isFading: widget.isFadingIn,
                            isCompact: true,
                            takeFullHeight: true,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: FadeButton(
                            label: 'FADE OUT',
                            icon: Icons.trending_down,
                            isBypassed: isBypassed,
                            onTap: () => widget.onTriggerFade(false),
                            accentColor: accentColor,
                            isFading: widget.isFadingOut,
                            isCompact: true,
                            takeFullHeight: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : widget.size == 'regular'
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row 1: Standard Header Row
                  buildStandardHeaderRow(context),
                  const SizedBox(height: 4),
                  // URI + dB Box
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: GestureDetector(
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
                      ),
                      const SizedBox(width: 8),
                      buildDbBox(),
                    ],
                  ),
                  const SizedBox(height: 4),
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
                  const SizedBox(height: 6),
                  // Fade and Transport controls
                  buildFadeTransportRow(isCompact: false),
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
                buildSizeToggle: () => buildStandardHeaderRow(context),
                buildFadeTransportRow: () => buildFadeTransportRow(isCompact: false),
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
    required Widget Function() buildFadeTransportRow,
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
        displayCurve = VectorBezierCurve.fromMap(widget.customParams);
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
      {'key': 'custom', 'label': 'VECTOR'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top row: Standard Header Row
        buildSizeToggle(),
        const SizedBox(height: 8),

        // Plugin URI link + dB box
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: GestureDetector(
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
            ),
            const SizedBox(width: 8),
            buildDbBox(),
          ],
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
            Expanded(child: buildSliderWithRangeOverlay(compact: false)),
            Icon(Icons.volume_up, color: accentColor, size: 20),
          ],
        ),
        const SizedBox(height: 2),

        // Range dB labels + percentage
        Row(
          children: [
            Text(
              '${minRange.toStringAsFixed(1)} dB (Start: ${startDb.toStringAsFixed(1)} dB)',
              style: TextStyle(
                fontSize: 9,
                color: Colors.grey[600],
                fontFamily: 'monospace',
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

        // Vectorized Bezier Editor (when VECTOR shape is selected)
        if (shapeName == 'custom') ...[
          const SizedBox(height: 8),
          VectorBezierEditor(
            paramsIn: widget.customParams,
            paramsOut: widget.customParamsOut,
            customPresets: widget.customPresets,
            accentColor: accentColor,
            isDarkMode: widget.isDarkMode,
            onParamsInChanged: widget.onCustomCurveParamsChanged,
            onParamsOutChanged: widget.onCustomCurveParamsOutChanged,
            onCustomPresetsChanged: widget.onCustomPresetsChanged,
            fadeProgress: widget.fadeProgress,
            isFading: widget.isFading,
            isFadingIn: widget.isFadingIn,
            isFadingOut: widget.isFadingOut,
            isFadePaused: widget.isFadePaused,
            currentVolumeFraction: (maxRange > minRange)
                ? (clampedValue - minRange) / (maxRange - minRange)
                : 0.5,
          ),
        ],
        const SizedBox(height: 8),

        // Live Fade Curve Visualizer (for standard presets; vector editor has its own rich visualizer)
        if (shapeName != 'custom') ...[
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
        ],

        // Fade & Transport buttons
        buildFadeTransportRow(),
      ],
    );
  }
}
