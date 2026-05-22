// Copyright (c) 2026 TamperMod Contributors
// Licensed under the MIT License

import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/plugin_instance.dart';
import '../../services/looper_controller.dart';
import '../../services/websocket_service.dart';
import '../common/module_help_sheet.dart';
import '../common/size_toggle_button.dart';
import 'base_card.dart';

/// ALO looper controller card widget
class LooperCard extends StatefulWidget {
  final PluginInstance pedal;
  final bool isDarkMode;
  final Color glowColor;
  final String displayName;
  final double bpm;
  final LooperController looperController;
  final ModWebSocketService webSocketService;
  final VoidCallback onRenamePressed;
  final VoidCallback onColorPickerPressed;
  final VoidCallback onHighlightPressed;
  final VoidCallback onSizeToggled;
  final VoidCallback onBpmTap;

  const LooperCard({
    super.key,
    required this.pedal,
    required this.isDarkMode,
    required this.glowColor,
    required this.displayName,
    required this.bpm,
    required this.looperController,
    required this.webSocketService,
    required this.onRenamePressed,
    required this.onColorPickerPressed,
    required this.onHighlightPressed,
    required this.onSizeToggled,
    required this.onBpmTap,
  });

  @override
  State<LooperCard> createState() => _LooperCardState();
}

class _LooperCardState extends State<LooperCard> {
  double _lastNonZeroClickVolume = 5.0;

  String? _findPortSymbol(PluginInstance pedal, String keyword) {
    final keywordLower = keyword.toLowerCase();
    for (final k in pedal.parameters.keys) {
      if (k.toLowerCase().contains(keywordLower)) {
        return k;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.looperController,
      builder: (context, _) {
        final Color looperAccentColor = widget.glowColor;
        final primaryThemeColor = widget.isDarkMode
            ? const Color(0xFF00FFCC)
            : const Color(0xFF00B3FF);

        // Find symbols dynamically
        final String thresholdPort =
            _findPortSymbol(widget.pedal, 'threshold') ?? 'threshold';
        final String clickPort =
            _findPortSymbol(widget.pedal, 'click') ??
            _findPortSymbol(widget.pedal, 'metronome') ??
            'click';
        final String mixPort =
            _findPortSymbol(widget.pedal, 'mix') ??
            _findPortSymbol(widget.pedal, 'dry') ??
            'mix';

        final double thresholdValue =
            widget.pedal.parameters[thresholdPort] ?? -40.0;
        final double clickValue = widget.pedal.parameters[clickPort] ?? 0.0;
        final double mixValue = widget.pedal.parameters[mixPort] ?? 50.0;

        final int selectedLoopNum = widget.looperController.selectedLoopNum;

        return BaseCard(
          glowColor: widget.glowColor,
          isDarkMode: widget.isDarkMode,
          isBypassed: widget.pedal.isBypassed,
          onLongPress: widget.onColorPickerPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title / Header Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Size toggle button for ALO looper (extended/regular modes)
                    SizeToggleButton(
                      instanceId: widget.pedal.instance,
                      currentSize: 'expanded',
                      accentColor: looperAccentColor,
                      isDarkMode: widget.isDarkMode,
                      isEnabled: true,
                      onTap: widget.onSizeToggled,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: widget.onHighlightPressed,
                        child: Row(
                          children: [
                            Icon(
                              Icons.music_video,
                              color: looperAccentColor,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                widget.displayName.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.0,
                                  color: widget.isDarkMode
                                      ? Colors.white
                                      : Colors.black,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: Icon(
                                Icons.edit,
                                size: 13,
                                color: widget.isDarkMode
                                    ? Colors.grey[500]
                                    : Colors.grey[600],
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: widget.onRenamePressed,
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: Icon(
                                Icons.help_outline,
                                size: 14,
                                color: primaryThemeColor.withOpacity(0.8),
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => ModuleHelpSheet.show(
                                context,
                                'looper',
                                widget.isDarkMode,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Metronome BPM indicator/badge
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: widget.onBpmTap,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: widget.isDarkMode
                                ? Colors.black
                                : Colors.grey[200],
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: primaryThemeColor.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.query_builder,
                                size: 12,
                                color: primaryThemeColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${widget.bpm.toStringAsFixed(1)} BPM',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'monospace',
                                  color: primaryThemeColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Divider(
                  color:
                      (widget.isDarkMode ? Colors.grey[850] : Colors.grey[300])
                          ?.withOpacity(0.5),
                  height: 1,
                ),
                const SizedBox(height: 12),

                // Loop Selector Buttons (6 exclusive buttons)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(6, (index) {
                    final loopNum = index + 1;
                    final isSelected = selectedLoopNum == loopNum;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isSelected
                                ? looperAccentColor
                                : (widget.isDarkMode
                                      ? Colors.black.withOpacity(0.4)
                                      : Colors.grey[200]),
                            foregroundColor: isSelected
                                ? Colors.black
                                : (widget.isDarkMode
                                      ? Colors.white
                                      : Colors.black),
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                              side: BorderSide(
                                color: isSelected
                                    ? looperAccentColor
                                    : looperAccentColor.withOpacity(0.3),
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                          ),
                          onPressed: () {
                            widget.looperController.selectLoop(loopNum);
                          },
                          child: Text(
                            '$loopNum',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 12),

                // Selected Loop Timeline and Controls
                SizedBox(
                  height: 140,
                  child: _buildLooperTrackSegment(
                    selectedLoopNum,
                    looperAccentColor,
                    widget.pedal,
                  ),
                ),
                const SizedBox(height: 12),
                Divider(
                  color:
                      (widget.isDarkMode ? Colors.grey[850] : Colors.grey[300])
                          ?.withOpacity(0.5),
                  height: 1,
                ),
                const SizedBox(height: 12),

                // Sliders Column at bottom
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildLooperSlider(
                      label: 'Threshold',
                      value: thresholdValue,
                      min: -60.0,
                      max: 0.0,
                      valueSuffix: ' dB',
                      accentColor: looperAccentColor,
                      isThresholdLabel: true,
                      onChanged: (val) {
                        setState(() {
                          widget.pedal.parameters[thresholdPort] = val;
                        });
                        widget.webSocketService.setParamValue(
                          instance: widget.pedal.instance,
                          port: thresholdPort,
                          value: double.parse(val.toStringAsFixed(2)),
                        );
                      },
                      onLabelTap: () {
                        final double current =
                            widget.pedal.parameters[thresholdPort] ?? -40.0;
                        double next;
                        if (current < -50.0) {
                          next = -40.0;
                        } else if (current < -20.0) {
                          next = 0.0;
                        } else {
                          next = -60.0;
                        }
                        setState(() {
                          widget.pedal.parameters[thresholdPort] = next;
                        });
                        widget.webSocketService.setParamValue(
                          instance: widget.pedal.instance,
                          port: thresholdPort,
                          value: next,
                        );
                      },
                    ),
                    const SizedBox(height: 6),
                    _buildLooperSlider(
                      label: 'Mix Setting',
                      value: mixValue,
                      min: 0.0,
                      max: 100.0,
                      accentColor: looperAccentColor,
                      onChanged: (val) {
                        setState(() {
                          widget.pedal.parameters[mixPort] = val;
                        });
                        widget.webSocketService.setParamValue(
                          instance: widget.pedal.instance,
                          port: mixPort,
                          value: double.parse(val.toStringAsFixed(2)),
                        );
                      },
                      onLabelTap: () {
                        final double current =
                            widget.pedal.parameters[mixPort] ?? 100.0;
                        double next;
                        if (current < 25.0) {
                          next = 50.0;
                        } else if (current < 75.0) {
                          next = 100.0;
                        } else {
                          next = 0.0;
                        }
                        setState(() {
                          widget.pedal.parameters[mixPort] = next;
                        });
                        widget.webSocketService.setParamValue(
                          instance: widget.pedal.instance,
                          port: mixPort,
                          value: next,
                        );
                      },
                    ),
                    const SizedBox(height: 6),
                    _buildLooperSlider(
                      label: 'Click Volume',
                      value: clickValue,
                      min: 0.0,
                      max: 10.0,
                      accentColor: looperAccentColor,
                      isRound: true,
                      onChanged: (val) {
                        setState(() {
                          widget.pedal.parameters[clickPort] = val;
                        });
                        widget.webSocketService.setParamValue(
                          instance: widget.pedal.instance,
                          port: clickPort,
                          value: double.parse(val.toStringAsFixed(2)),
                        );
                      },
                      onLabelTap: () {
                        final double current = clickValue;
                        double next;
                        if (current > 0.0) {
                          _lastNonZeroClickVolume = current;
                          next = 0.0;
                        } else {
                          next = _lastNonZeroClickVolume;
                        }
                        setState(() {
                          widget.pedal.parameters[clickPort] = next;
                        });
                        widget.webSocketService.setParamValue(
                          instance: widget.pedal.instance,
                          port: clickPort,
                          value: next,
                        );
                      },
                    ),
                    const SizedBox(height: 6),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLooperTrackSegment(
    int loopNum,
    Color glowColor,
    PluginInstance pedal,
  ) {
    final state = widget.looperController.getState(loopNum);

    Color stateColor;
    String stateText = '';
    IconData stateIcon;
    bool isPulsing = false;

    switch (state) {
      case LooperState.empty:
        stateColor = Colors.grey[600]!;
        stateText = 'Empty Loop';
        stateIcon = Icons.music_note_outlined;
        break;
      case LooperState.countIn:
        stateColor = Colors.orange;
        stateText =
            'COUNT-IN (Rec in ${((16 - widget.looperController.getCurrentBeatIndex(loopNum)) * widget.looperController.beatDurationMs / 1000).toStringAsFixed(1)}s)';
        stateIcon = Icons.hourglass_top;
        isPulsing = true;
        break;
      case LooperState.recording:
        stateColor = const Color(0xFFFF0055);
        stateText =
            'RECORDING (Beat ${widget.looperController.getCurrentBeatIndex(loopNum) + 1}/16)';
        stateIcon = Icons.fiber_manual_record;
        isPulsing = true;
        break;
      case LooperState.playing:
        stateColor = glowColor;
        stateText =
            'PLAYING LOOP (Bar ${widget.looperController.getCurrentBar(loopNum)}, Beat ${widget.looperController.getCurrentBeatInBar(loopNum)})';
        stateIcon = Icons.play_arrow;
        break;
      case LooperState.paused:
        stateColor = Colors.grey[600]!;
        stateText =
            'MUTED (Bar ${widget.looperController.getCurrentBar(loopNum)}, Beat ${widget.looperController.getCurrentBeatInBar(loopNum)})';
        stateIcon = Icons.volume_off;
        break;
    }

    Widget stateIndicator = Icon(stateIcon, color: stateColor, size: 14);
    if (isPulsing) {
      stateIndicator = _PulsingIndicator(icon: stateIcon, color: stateColor);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Track Header Info
        Row(
          children: [
            Text(
              'LOOP $loopNum',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: state == LooperState.empty
                    ? Colors.grey[500]
                    : glowColor,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(width: 8),
            stateIndicator,
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                stateText,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: stateColor,
                  letterSpacing: 0.5,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),

        // Track timeline
        _build4BarTimeline(loopNum, stateColor),
        const SizedBox(height: 6),

        // Track actions row
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      (state == LooperState.countIn ||
                          state == LooperState.recording)
                      ? Colors.grey[800]
                      : const Color(0xFFFF0055),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                icon: Icon(
                  (state == LooperState.countIn ||
                          state == LooperState.recording)
                      ? Icons.cancel
                      : Icons.fiber_manual_record,
                  size: 12,
                ),
                label: Text(
                  (state == LooperState.countIn ||
                          state == LooperState.recording)
                      ? 'CANCEL'
                      : 'RECORD 4-BAR',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
                onPressed: () {
                  if (state == LooperState.countIn ||
                      state == LooperState.recording) {
                    widget.looperController.clearLoop(loopNum);
                  } else {
                    widget.looperController.recordSequence(loopNum);
                  }
                },
              ),
            ),
            const SizedBox(width: 6),

            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.isDarkMode
                      ? Colors.black.withOpacity(0.4)
                      : Colors.grey[200],
                  foregroundColor: widget.isDarkMode
                      ? Colors.white
                      : Colors.black,
                  disabledForegroundColor: Colors.grey[600],
                  disabledBackgroundColor: widget.isDarkMode
                      ? Colors.black.withOpacity(0.2)
                      : Colors.grey[300],
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                    side: BorderSide(
                      color: widget.isDarkMode
                          ? Colors.grey[800]!
                          : Colors.grey[400]!,
                    ),
                  ),
                ),
                onPressed: (state == LooperState.playing)
                    ? () => widget.looperController.pauseLoop(loopNum)
                    : (state == LooperState.paused)
                    ? () => widget.looperController.playLoop(loopNum)
                    : null,
                icon: Icon(
                  (state == LooperState.paused)
                      ? Icons.play_arrow
                      : Icons.volume_off,
                  size: 12,
                ),
                label: Text(
                  (state == LooperState.paused) ? 'PLAY' : 'MUTE',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),

            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber.withOpacity(0.12),
                  foregroundColor: Colors.amber,
                  disabledForegroundColor: Colors.grey[600],
                  disabledBackgroundColor: widget.isDarkMode
                      ? Colors.black.withOpacity(0.2)
                      : Colors.grey[300],
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                    side: const BorderSide(color: Colors.amber),
                  ),
                ),
                onPressed: () => widget.looperController.clearLoop(loopNum),
                icon: const Icon(Icons.delete_outline, size: 12),
                label: const Text(
                  'CLEAR',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),

        // On/Off/Click buttons row (targets the selected loop)
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: (state == LooperState.playing)
                      ? glowColor.withOpacity(0.2)
                      : (widget.isDarkMode
                            ? Colors.black.withOpacity(0.4)
                            : Colors.grey[200]),
                  foregroundColor: (state == LooperState.playing)
                      ? glowColor
                      : (widget.isDarkMode ? Colors.white : Colors.black),
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                    side: BorderSide(
                      color: (state == LooperState.playing)
                          ? glowColor
                          : stateColor.withOpacity(0.4),
                      width: (state == LooperState.playing) ? 2 : 1,
                    ),
                  ),
                ),
                onPressed: () {
                  // ON: Set loop to playing state (if it has content)
                  if (state == LooperState.paused) {
                    widget.looperController.playLoop(loopNum);
                  } else if (state == LooperState.playing ||
                      state == LooperState.recording ||
                      state == LooperState.countIn) {
                    // Already on, do nothing or could toggle to pause
                  } else {
                    // Empty loop - send raw 1.0 to hardware
                    widget.webSocketService.setParamValue(
                      instance: widget.pedal.instance,
                      port: 'loop$loopNum',
                      value: 1.0,
                    );
                  }
                },
                child: const Text(
                  'ON',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: (state == LooperState.paused)
                      ? Colors.grey[700]
                      : (widget.isDarkMode
                            ? Colors.black.withOpacity(0.4)
                            : Colors.grey[200]),
                  foregroundColor: widget.isDarkMode
                      ? Colors.white
                      : Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                    side: BorderSide(
                      color: (state == LooperState.paused)
                          ? Colors.grey[600]!
                          : stateColor.withOpacity(0.4),
                      width: (state == LooperState.paused) ? 2 : 1,
                    ),
                  ),
                ),
                onPressed: () {
                  // OFF: Pause/mute the loop
                  if (state == LooperState.playing) {
                    widget.looperController.pauseLoop(loopNum);
                  } else if (state == LooperState.paused) {
                    // Already off, do nothing
                  } else {
                    // Send raw 0.0 to hardware
                    widget.webSocketService.setParamValue(
                      instance: widget.pedal.instance,
                      port: 'loop$loopNum',
                      value: 0.0,
                    );
                  }
                },
                child: const Text(
                  'OFF',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.isDarkMode
                      ? Colors.black.withOpacity(0.4)
                      : Colors.grey[200],
                  foregroundColor: widget.isDarkMode
                      ? Colors.white
                      : Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                    side: BorderSide(color: stateColor.withOpacity(0.4)),
                  ),
                ),
                onPressed: () {
                  // CLICK: Trigger a single switch press (like a foot switch tap)
                  widget.looperController.manualTrigger(loopNum);
                },
                child: const Text(
                  'CLICK',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLooperSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required Color accentColor,
    required ValueChanged<double> onChanged,
    String valueSuffix = '',
    bool isPercentage = false,
    bool isRound = false,
    bool isThresholdLabel = false,
    VoidCallback? onLabelTap,
  }) {
    final displayValue = isPercentage
        ? (value * 100).toStringAsFixed(0) + '%'
        : isRound
        ? value.round().toString() + valueSuffix
        : value.toStringAsFixed(1) + valueSuffix;
    return Row(
      children: [
        GestureDetector(
          onTap: onLabelTap,
          behavior: HitTestBehavior.opaque,
          child: SizedBox(
            width: 90,
            child: Text(
              label,
              maxLines: isThresholdLabel ? 1 : null,
              overflow: isThresholdLabel ? TextOverflow.ellipsis : null,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: widget.isDarkMode ? Colors.grey[300] : Colors.grey[700],
              ),
            ),
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: accentColor,
              inactiveTrackColor: widget.isDarkMode
                  ? Colors.grey[850]
                  : Colors.grey[300],
              trackHeight: 4.0,
              thumbColor: widget.isDarkMode ? Colors.white : Colors.grey[100],
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12.0),
            ),
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: onLabelTap,
          behavior: HitTestBehavior.opaque,
          child: SizedBox(
            width: 50,
            child: Text(
              displayValue,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: accentColor,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _build4BarTimeline(int loopNum, Color stateColor) {
    final state = widget.looperController.getState(loopNum);
    final progress = widget.looperController.getSweepProgress(loopNum);
    final currentBar = widget.looperController.getCurrentBar(loopNum);
    final currentBeatIndex = widget.looperController.getCurrentBeatIndex(
      loopNum,
    );

    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: widget.isDarkMode
            ? Colors.black.withOpacity(0.5)
            : Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: widget.isDarkMode ? Colors.grey[900]! : Colors.grey[300]!,
        ),
      ),
      child: Stack(
        children: [
          if (state == LooperState.recording)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              right: 0,
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: progress,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF0055).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(7),
                  ),
                ),
              ),
            ),

          Row(
            children: List.generate(4, (barIndex) {
              final isCurrentBar =
                  (state != LooperState.empty) && (currentBar == barIndex + 1);
              return Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border(
                      right: barIndex < 3
                          ? BorderSide(
                              color: stateColor.withOpacity(0.25),
                              width: 1.5,
                            )
                          : BorderSide.none,
                    ),
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: Text(
                          'BAR ${barIndex + 1}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: isCurrentBar
                                ? FontWeight.w900
                                : FontWeight.bold,
                            color: isCurrentBar
                                ? stateColor
                                : (widget.isDarkMode
                                      ? Colors.grey[700]
                                      : Colors.grey[400]),
                          ),
                        ),
                      ),

                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 4,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: List.generate(3, (beatIndex) {
                            final globalBeatIndex =
                                barIndex * 4 + beatIndex + 1;
                            final isCurrentBeat =
                                (state != LooperState.empty) &&
                                (currentBeatIndex == globalBeatIndex);
                            return Container(
                              width: isCurrentBeat ? 8 : 4,
                              height: isCurrentBeat ? 8 : 4,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isCurrentBeat
                                    ? stateColor
                                    : (widget.isDarkMode
                                          ? Colors.grey[850]
                                          : Colors.grey[300]),
                              ),
                            );
                          }),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),

          if (state != LooperState.empty)
            Positioned.fill(
              child: Align(
                alignment: Alignment(progress * 2.0 - 1.0, 0.0),
                child: Container(
                  width: 3,
                  decoration: BoxDecoration(
                    color: stateColor,
                    boxShadow: [
                      BoxShadow(
                        color: stateColor.withOpacity(0.8),
                        blurRadius: 6,
                        spreadRadius: 1.5,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PulsingIndicator extends StatefulWidget {
  final IconData icon;
  final Color color;

  const _PulsingIndicator({required this.icon, required this.color});

  @override
  State<_PulsingIndicator> createState() => _PulsingIndicatorState();
}

class _PulsingIndicatorState extends State<_PulsingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.4, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: Icon(widget.icon, color: widget.color, size: 16),
    );
  }
}
