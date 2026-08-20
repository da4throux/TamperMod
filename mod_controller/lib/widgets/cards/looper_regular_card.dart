// Copyright (c) 2026 TamperMod Contributors
// Licensed under the MIT License

import 'package:flutter/material.dart';
import '../../models/plugin_instance.dart';
import '../../services/looper_controller.dart';
import '../../services/websocket_service.dart';
import '../common/module_help_sheet.dart';
import '../common/size_toggle_button.dart';
import '../../utils/plugin_category.dart';
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
  final VoidCallback onBpmTap;
  final ValueChanged<bool> onBypassToggle;

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
    required this.onBpmTap,
    required this.onBypassToggle,
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title / Header Row (Standardized)
                Row(
                  children: [
                    // 1. Size toggle & Category Icon
                    SizeToggleButton(
                      instanceId: widget.pedal.instance,
                      currentSize: 'regular',
                      accentColor: looperAccentColor,
                      isDarkMode: widget.isDarkMode,
                      isEnabled: true,
                      pedal: widget.pedal,
                      onTap: widget.onSizeToggled,
                      onLongPress: widget.onRenamePressed,
                    ),
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
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.8,
                                  color: widget.isDarkMode
                                      ? Colors.white
                                      : Colors.black,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: PluginCategoryHelper.getCategoryForPlugin(widget.pedal).defaultColor.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: PluginCategoryHelper.getCategoryForPlugin(widget.pedal).defaultColor.withValues(alpha: 0.5),
                                  width: 0.8,
                                ),
                              ),
                              child: Text(
                                PluginCategoryHelper.getCategoryForPlugin(widget.pedal).shortCode,
                                style: TextStyle(
                                  fontSize: 7.5,
                                  fontWeight: FontWeight.w900,
                                  color: PluginCategoryHelper.getCategoryForPlugin(widget.pedal).defaultColor,
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
                      onTap: () => ModuleHelpSheet.show(
                        context,
                        'looper',
                        widget.isDarkMode,
                      ),
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

                    // 4. Edit Button
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

                    // 5. Focus Button
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
                          color: looperAccentColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),

                    // 6. Power Button
                    GestureDetector(
                      onTap: () => widget.onBypassToggle(!widget.pedal.isBypassed),
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: !widget.pedal.isBypassed
                              ? widget.glowColor.withOpacity(widget.isDarkMode ? 0.25 : 0.18)
                              : (widget.isDarkMode ? const Color(0xFF1C2433) : Colors.grey[200]),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: !widget.pedal.isBypassed ? widget.glowColor : Colors.grey[700]!,
                            width: !widget.pedal.isBypassed ? 1.2 : 0.8,
                          ),
                        ),
                        child: Icon(
                          Icons.power_settings_new,
                          size: 14,
                          color: !widget.pedal.isBypassed ? widget.glowColor : Colors.grey[500],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Sub-header Row: Metronome BPM badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'LOOP SEQUENCER',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                        color: widget.isDarkMode ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: widget.onBpmTap,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
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
                const SizedBox(height: 6),
                Divider(
                  color:
                      (widget.isDarkMode ? Colors.grey[850] : Colors.grey[300])
                          ?.withOpacity(0.5),
                  height: 1,
                ),
                const SizedBox(height: 6),

                const SizedBox(height: 6),

                // Expanded 3x2 Timeline Grid - All 6 Tracks Stacked
                _buildAllTracksPlayingBar(looperAccentColor),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAllTracksPlayingBar(Color accentColor) {
    return Container(
      height: 150.0,
      decoration: BoxDecoration(
        color: widget.isDarkMode
            ? Colors.black.withOpacity(0.5)
            : Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: widget.isDarkMode ? Colors.grey[900]! : Colors.grey[300]!,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                _buildTrackRow(0, accentColor, true),
                _buildTrackRow(1, accentColor, false),
              ],
            ),
          ),
          Container(
            width: 1,
            color: widget.isDarkMode ? Colors.grey[900]! : Colors.grey[300]!,
          ),
          Expanded(
            child: Column(
              children: [
                _buildTrackRow(2, accentColor, true),
                _buildTrackRow(3, accentColor, false),
              ],
            ),
          ),
          Container(
            width: 1,
            color: widget.isDarkMode ? Colors.grey[900]! : Colors.grey[300]!,
          ),
          Expanded(
            child: Column(
              children: [
                _buildTrackRow(4, accentColor, true),
                _buildTrackRow(5, accentColor, false),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackRow(int loopIndex, Color accentColor, bool showBottomBorder) {
    final loopNum = loopIndex + 1;
    final state = widget.looperController.getState(loopNum);
    final progress = widget.looperController.getSweepProgress(loopNum);
    final isSelected = widget.looperController.selectedLoopNum == loopNum;

    Color trackColor;
    bool isActive = false;

    switch (state) {
      case LooperState.empty:
        trackColor = Colors.grey[800]!;
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
        trackColor = Colors.blueGrey;
        isActive = false;
        break;
    }

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          widget.looperController.setActiveLooper(widget.pedal);
          widget.looperController.selectLoop(loopNum);
          if (state == LooperState.empty) {
            widget.looperController.recordSequence(loopNum);
          } else if (state == LooperState.countIn || state == LooperState.recording) {
            widget.looperController.clearLoop(loopNum);
          } else if (state == LooperState.playing) {
            widget.looperController.pauseLoop(loopNum);
          } else if (state == LooperState.paused) {
            widget.looperController.playLoop(loopNum);
          }
        },
        onLongPress: () {
          widget.looperController.setActiveLooper(widget.pedal);
          widget.looperController.clearLoop(loopNum);
        },
        child: Container(
          decoration: BoxDecoration(
            color: isSelected
                ? accentColor.withOpacity(widget.isDarkMode ? 0.15 : 0.1)
                : null,
            border: isSelected
                ? Border.all(color: accentColor, width: 2.0)
                : Border(
                    bottom: showBottomBorder
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
                    child: Container(color: trackColor.withOpacity(0.5)),
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
                                      color: trackColor.withOpacity(0.65), // Brighter beat bars
                                      width: 1.5,
                                    )
                                  : BorderSide.none,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),

              // Track label and status (centered vertically, larger size)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Row(
                    children: [
                      Text(
                        'LOOP $loopNum',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: trackColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (isActive)
                        Icon(
                          state == LooperState.recording
                              ? Icons.fiber_manual_record
                              : state == LooperState.countIn
                              ? Icons.hourglass_top
                              : Icons.play_arrow,
                          size: 14,
                          color: trackColor,
                        )
                      else
                        Icon(
                          state == LooperState.paused
                              ? Icons.volume_off
                              : Icons.music_note_outlined,
                          size: 14,
                          color: trackColor,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
