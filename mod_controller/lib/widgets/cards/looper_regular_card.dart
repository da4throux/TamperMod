// Copyright (c) 2026 TamperMod Contributors
// Licensed under the MIT License

import 'package:flutter/material.dart';
import '../../models/plugin_instance.dart';
import '../../services/looper_controller.dart';
import '../../services/websocket_service.dart';
import '../common/module_help_sheet.dart';
import '../common/size_toggle_button.dart';
import 'base_card.dart';

/// ALO looper regular (compact) card widget - shows all 6 loops in compact form
class LooperRegularCard extends StatefulWidget {
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

  const LooperRegularCard({
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
  });

  @override
  State<LooperRegularCard> createState() => _LooperRegularCardState();
}

class _LooperRegularCardState extends State<LooperRegularCard> {
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
                      currentSize: 'regular',
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
                    Container(
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

                // Small Playing Bar - All 6 Tracks Stacked
                _buildAllTracksPlayingBar(looperAccentColor),
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

                // Action Buttons: Record, Mute, Clear
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF0055),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        icon: const Icon(Icons.fiber_manual_record, size: 14),
                        label: const Text(
                          'RECORD',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                        onPressed: () {
                          widget.looperController.recordSequence(
                            selectedLoopNum,
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: widget.isDarkMode
                              ? Colors.black.withOpacity(0.4)
                              : Colors.grey[200],
                          foregroundColor: widget.isDarkMode
                              ? Colors.white
                              : Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                            side: BorderSide(
                              color: widget.isDarkMode
                                  ? Colors.grey[800]!
                                  : Colors.grey[400]!,
                            ),
                          ),
                        ),
                        icon: const Icon(Icons.volume_off, size: 14),
                        label: const Text(
                          'MUTE',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                        onPressed: () {
                          final state = widget.looperController.getState(
                            selectedLoopNum,
                          );
                          if (state == LooperState.playing) {
                            widget.looperController.pauseLoop(selectedLoopNum);
                          } else if (state == LooperState.paused) {
                            widget.looperController.playLoop(selectedLoopNum);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber.withOpacity(0.12),
                          foregroundColor: Colors.amber,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                            side: const BorderSide(color: Colors.amber),
                          ),
                        ),
                        icon: const Icon(Icons.delete_outline, size: 14),
                        label: const Text(
                          'CLEAR',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                        onPressed: () {
                          widget.looperController.clearLoop(selectedLoopNum);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAllTracksPlayingBar(Color accentColor) {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: widget.isDarkMode
            ? Colors.black.withOpacity(0.5)
            : Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: widget.isDarkMode ? Colors.grey[900]! : Colors.grey[300]!,
        ),
      ),
      child: Column(
        children: List.generate(6, (loopIndex) {
          final loopNum = loopIndex + 1;
          final state = widget.looperController.getState(loopNum);
          final progress = widget.looperController.getSweepProgress(loopNum);

          Color trackColor;
          bool isActive = false;

          switch (state) {
            case LooperState.empty:
              trackColor = Colors.grey[700]!;
              isActive = false;
              break;
            case LooperState.countIn:
              trackColor = Colors.orange;
              isActive = true;
              break;
            case LooperState.recording:
              trackColor = const Color(0xFFFF0055);
              isActive = true;
              break;
            case LooperState.playing:
              trackColor = accentColor;
              isActive = true;
              break;
            case LooperState.paused:
              trackColor = Colors.grey[600]!;
              isActive = false;
              break;
          }

          return Expanded(
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: loopIndex < 5
                      ? BorderSide(
                          color: widget.isDarkMode
                              ? Colors.grey[900]!
                              : Colors.grey[350]!,
                          width: 1,
                        )
                      : BorderSide.none,
                ),
              ),
              child: Stack(
                children: [
                  // Background progress bar
                  if (isActive)
                    Positioned.fill(
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: progress,
                        child: Container(color: trackColor.withOpacity(0.2)),
                      ),
                    ),

                  // Beat bar separators (vertical lines between bars - 3 lines for 4 bars)
                  if (isActive)
                    Positioned.fill(
                      child: Row(
                        children: List.generate(4, (barIndex) {
                          return Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border(
                                  right: barIndex < 3
                                      ? BorderSide(
                                          color: trackColor.withOpacity(0.2),
                                          width: 1.0,
                                        )
                                      : BorderSide.none,
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),

                  // Track label and status
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      children: [
                        Text(
                          'L$loopNum',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: trackColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(width: 4),
                        if (isActive)
                          Icon(
                            state == LooperState.recording
                                ? Icons.fiber_manual_record
                                : state == LooperState.countIn
                                ? Icons.hourglass_top
                                : Icons.play_arrow,
                            size: 10,
                            color: trackColor,
                          )
                        else
                          Icon(
                            Icons.music_note_outlined,
                            size: 10,
                            color: trackColor,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}
