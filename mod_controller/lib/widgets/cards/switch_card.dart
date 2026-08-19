// Copyright (c) 2026 TamperMod Contributors
// Licensed under the MIT License

import 'package:flutter/material.dart';
import '../../models/plugin_instance.dart';


/// Switch/routing controller card widget
class SwitchCard extends StatelessWidget {
  final PluginInstance pedal;
  final String size;
  final bool isDarkMode;
  final Color glowColor;
  final String displayName;
  final ValueChanged<bool> onBypassToggle;
  final VoidCallback onRenamePressed;
  final VoidCallback onHighlightPressed;
  final VoidCallback onColorPickerPressed;
  final ValueChanged<String> onOpenUri;
  final void Function(String port, double value) onSwitchPathChanged;

  const SwitchCard({
    super.key,
    required this.pedal,
    required this.size,
    required this.isDarkMode,
    required this.glowColor,
    required this.displayName,
    required this.onBypassToggle,
    required this.onRenamePressed,
    required this.onHighlightPressed,
    required this.onColorPickerPressed,
    required this.onOpenUri,
    required this.onSwitchPathChanged,
  });

  String? _getSwitchPortSymbol(PluginInstance pedal) {
    for (final symbol in pedal.parameters.keys) {
      if (symbol == ':bypass') continue;
      final s = symbol.toLowerCase();
      if (s.contains('select') ||
          s.contains('out') ||
          s.contains('route') ||
          s.contains('switch') ||
          s.contains('channel') ||
          s.contains('option') ||
          s.contains('param') ||
          s.contains('position') ||
          s.contains('value') ||
          s.contains('mode') ||
          s.contains('in') ||
          s.contains('state')) {
        return symbol;
      }
    }
    // Fallback to first non-bypass parameter if available
    final nonBypass = pedal.parameters.keys.where((k) => k != ':bypass').toList();
    if (nonBypass.isNotEmpty) {
      return nonBypass.first;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final bool isBypassed = pedal.isBypassed;
    final String? switchPort = _getSwitchPortSymbol(pedal);
    final double currentValue = switchPort != null
        ? (pedal.parameters[switchPort] ?? 0.0)
        : 0.0;

    // Active state is based on parameter value if a port exists, otherwise bypass state
    final bool isActive = switchPort != null ? (currentValue >= 0.5) : !isBypassed;
    final Color accentColor = isActive ? glowColor : Colors.grey[600]!;

    // The whole card is a tap-to-toggle big button for the switchbox
    return GestureDetector(
      onTap: () {
        if (switchPort != null) {
          final double nextVal = currentValue >= 0.5 ? 0.0 : 1.0;
          onSwitchPathChanged(switchPort, nextVal);
        } else {
          onBypassToggle(!isBypassed);
        }
      },
      onLongPress: onColorPickerPressed,
      child: Opacity(
        opacity: isActive ? 1.0 : 0.65,
        child: Container(
          decoration: BoxDecoration(
            color: isActive
                ? glowColor.withOpacity(isDarkMode ? 0.15 : 0.12)
                : (isDarkMode ? const Color(0xFF161B22) : Colors.white),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: glowColor.withOpacity(isActive ? 0.8 : 0.25),
              width: isActive ? 2.0 : 1.5,
            ),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: glowColor.withOpacity(0.7),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                    BoxShadow(
                      color: glowColor.withOpacity(isDarkMode ? 0.2 : 0.3),
                      blurRadius: 80,
                      spreadRadius: 2,
                    ),
                  ]
                : [],
          ),
          child: Padding(
            padding: EdgeInsets.all(size == 'compact' ? 10.0 : 14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row: name + edit + help
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        displayName.toUpperCase(),
                        style: TextStyle(
                          fontSize: size == 'compact' ? 13.5 : 16.0,
                          fontWeight: FontWeight.w900,
                          color: accentColor,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: onRenamePressed,
                      behavior: HitTestBehavior.opaque,
                      child: Icon(
                        Icons.edit,
                        size: 13,
                        color: isDarkMode ? Colors.grey[500] : Colors.grey[600],
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: onHighlightPressed,
                      behavior: HitTestBehavior.opaque,
                      child: Icon(
                        Icons.radar,
                        size: 13,
                        color: accentColor.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),

                const Spacer(),

                // Big central ON / OFF indicator
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isActive ? Icons.toggle_on : Icons.toggle_off,
                        size: 52,
                        color: isActive ? glowColor : Colors.grey[600],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isActive ? 'ON' : 'OFF',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.0,
                          color: isActive ? glowColor : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Port / value hint at the bottom
                Text(
                  switchPort != null
                      ? '$switchPort: ${currentValue.toStringAsFixed(1)}'
                      : (pedal.parameters.isNotEmpty
                          ? 'Params: ${pedal.parameters.keys.join(", ")}'
                          : 'Bypass mode'),
                  style: TextStyle(
                    fontSize: 9,
                    color: isDarkMode ? Colors.grey[600] : Colors.grey[500],
                    fontFamily: 'monospace',
                    overflow: TextOverflow.ellipsis,
                  ),
                  maxLines: 1,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
