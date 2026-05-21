// Copyright (c) 2026 TamperMod Contributors
// Licensed under the MIT License

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// BPM controller widget with tap tempo
class BpmController extends StatelessWidget {
  final double bpm;
  final int fadeBars;
  final bool isDarkMode;
  final VoidCallback onTapTempo;
  final VoidCallback onBpmTap;
  final ValueChanged<int> onFadeBarsChanged;
  final ValueListenable<bool> isTransportRolling;
  final ValueListenable<int> transportSyncMode;
  final ValueChanged<bool> onTransportRollingChanged;
  final ValueChanged<int> onSyncModeChanged;

  const BpmController({
    super.key,
    required this.bpm,
    required this.fadeBars,
    required this.isDarkMode,
    required this.onTapTempo,
    required this.onBpmTap,
    required this.onFadeBarsChanged,
    required this.isTransportRolling,
    required this.transportSyncMode,
    required this.onTransportRollingChanged,
    required this.onSyncModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final double seconds = (60 / bpm) * 4 * fadeBars;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDarkMode
            ? Colors.black.withOpacity(0.35)
            : Colors.grey[300]!.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color:
              (isDarkMode ? const Color(0xFF00FFCC) : const Color(0xFF00B3FF))
                  .withOpacity(0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Fuchsia Tap Tempo Button
          GestureDetector(
            onTap: onTapTempo,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFF007F).withOpacity(0.12),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: const Color(0xFFFF007F).withOpacity(0.4),
                ),
              ),
              child: const Text(
                'TAP',
                style: TextStyle(
                  color: Color(0xFFFF007F),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Editable BPM readout
          GestureDetector(
            onTap: onBpmTap,
            child: Text(
              '${bpm.toStringAsFixed(1)} BPM',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
                color: isDarkMode
                    ? const Color(0xFF00FFCC)
                    : const Color(0xFF0099FF),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Dropdown selector for Fade Beats length
          DropdownButton<int>(
            value: fadeBars,
            dropdownColor: isDarkMode ? const Color(0xFF0F141C) : Colors.white,
            underline: const SizedBox(),
            icon: const Icon(
              Icons.arrow_drop_down,
              color: Colors.grey,
              size: 16,
            ),
            style: TextStyle(
              color: isDarkMode ? Colors.white : Colors.black,
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
            ),
            onChanged: (val) {
              if (val != null) {
                onFadeBarsChanged(val);
              }
            },
            items: [1, 2, 4, 8, 16].map((b) {
              return DropdownMenuItem<int>(
                value: b,
                child: Text('$b Bar${b > 1 ? "s" : ""}'),
              );
            }).toList(),
          ),
          const SizedBox(width: 4),

          // Live duration calculation text
          Text(
            '(${seconds.toStringAsFixed(1)}s)',
            style: TextStyle(
              fontSize: 10,
              color: isDarkMode ? Colors.grey[500] : Colors.grey[700],
            ),
          ),

          // Vertical divider
          Container(
            height: 20,
            width: 1,
            color: Colors.grey.withOpacity(0.4),
            margin: const EdgeInsets.symmetric(horizontal: 10),
          ),

          // Play/Stop Button
          ValueListenableBuilder<bool>(
            valueListenable: isTransportRolling,
            builder: (context, isRolling, _) {
              return IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Icon(
                  isRolling ? Icons.play_arrow : Icons.stop,
                  color: isRolling
                      ? (isDarkMode
                            ? const Color(0xFF00FFCC)
                            : const Color(0xFF00B3FF))
                      : const Color(0xFFFF0055),
                  size: 20,
                ),
                tooltip: isRolling ? 'Stop Transport' : 'Play Transport',
                onPressed: () => onTransportRollingChanged(!isRolling),
              );
            },
          ),
          const SizedBox(width: 10),

          // Sync Mode Dropdown
          ValueListenableBuilder<int>(
            valueListenable: transportSyncMode,
            builder: (context, syncMode, _) {
              return DropdownButton<int>(
                value: (syncMode >= 0 && syncMode <= 2) ? syncMode : 0,
                dropdownColor: isDarkMode
                    ? const Color(0xFF0F141C)
                    : Colors.white,
                underline: const SizedBox(),
                icon: const Icon(Icons.sync, color: Colors.grey, size: 14),
                style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
                onChanged: (val) {
                  if (val != null) {
                    onSyncModeChanged(val);
                  }
                },
                items: const [
                  DropdownMenuItem<int>(value: 0, child: Text('INTERNAL')),
                  DropdownMenuItem<int>(value: 1, child: Text('MIDI')),
                  DropdownMenuItem<int>(value: 2, child: Text('LINK')),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
