// Copyright (c) 2026 TamperMod Contributors
// Licensed under the MIT License

import 'package:flutter/material.dart';
import '../../models/plugin_instance.dart';

/// Switch/routing controller card widget with dual layout modes:
/// 1. Route Mode: 2-Path selection (Path A vs Path B) with custom labels
/// 2. Toggle Mode: On/Off switch with prominent name and clean status indicator
class SwitchCard extends StatelessWidget {
  final PluginInstance pedal;
  final String size;
  final bool isDarkMode;
  final Color glowColor;
  final String displayName;
  final String mode; // 'toggle' or 'route'
  final String pathAName;
  final String pathBName;
  final bool isInverted;
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
    this.mode = 'toggle',
    this.pathAName = 'PATH A',
    this.pathBName = 'PATH B',
    this.isInverted = false,
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
    final String? switchPort = _getSwitchPortSymbol(pedal);
    final double currentValue = switchPort != null
        ? (pedal.parameters[switchPort] ?? 0.0)
        : 0.0;

    final bool isRouteMode = mode == 'route';

    // Route Mode: Path B is active if currentValue >= 0.5
    final bool isPathBActive = currentValue >= 0.5;

    // Toggle Mode: Active state respects isInverted configuration
    final bool isToggleActive = switchPort != null
        ? (isInverted ? (currentValue < 0.5) : (currentValue >= 0.5))
        : (isInverted ? pedal.isBypassed : !pedal.isBypassed);

    final bool isCardActive = isRouteMode ? true : isToggleActive;
    final Color accentColor = (isRouteMode || isCardActive) ? glowColor : Colors.grey[600]!;

    return GestureDetector(
      onTap: () {
        if (switchPort != null) {
          final double nextVal = currentValue >= 0.5 ? 0.0 : 1.0;
          onSwitchPathChanged(switchPort, nextVal);
        } else {
          onBypassToggle(!pedal.isBypassed);
        }
      },
      onLongPress: onColorPickerPressed,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: isCardActive ? 1.0 : 0.65,
        child: Container(
          decoration: BoxDecoration(
            color: isCardActive
                ? glowColor.withOpacity(isDarkMode ? 0.14 : 0.10)
                : (isDarkMode ? const Color(0xFF161B22) : Colors.white),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: glowColor.withOpacity(isCardActive ? 0.8 : 0.25),
              width: isCardActive ? 2.0 : 1.5,
            ),
            boxShadow: isCardActive
                ? [
                    BoxShadow(
                      color: glowColor.withOpacity(0.65),
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
                // Top Header Row
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        displayName.toUpperCase(),
                        style: TextStyle(
                          fontSize: size == 'compact' ? 13.0 : 15.0,
                          fontWeight: FontWeight.w900,
                          color: accentColor,
                          letterSpacing: 0.8,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: onRenamePressed,
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: isDarkMode
                              ? Colors.white.withOpacity(0.08)
                              : Colors.black.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          Icons.edit,
                          size: 13,
                          color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: onHighlightPressed,
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: isDarkMode
                              ? Colors.white.withOpacity(0.08)
                              : Colors.black.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          Icons.radar,
                          size: 13,
                          color: accentColor.withOpacity(0.85),
                        ),
                      ),
                    ),
                  ],
                ),

                const Spacer(),

                // Center Content: Route Mode vs Toggle Mode
                if (isRouteMode)
                  // 2-Path Selector Layout
                  _buildRouteSelector(context, isPathBActive, switchPort)
                else
                  // On / Off Clean Toggle Layout
                  _buildToggleLayout(context, isToggleActive),

                const Spacer(),

                // Bottom Port Info Footer
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

  // 1. Route Mode Layout: Two interactive path pills
  Widget _buildRouteSelector(BuildContext context, bool isPathBActive, String? switchPort) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Path A Pill (Down / 0.0)
        GestureDetector(
          onTap: () {
            if (switchPort != null) onSwitchPathChanged(switchPort, 0.0);
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
            decoration: BoxDecoration(
              color: !isPathBActive
                  ? glowColor.withOpacity(isDarkMode ? 0.30 : 0.22)
                  : (isDarkMode ? Colors.black.withOpacity(0.25) : Colors.grey[200]),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: !isPathBActive ? glowColor : Colors.grey[800]!,
                width: !isPathBActive ? 1.8 : 1.0,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  !isPathBActive ? Icons.radio_button_checked : Icons.radio_button_off,
                  size: 14,
                  color: !isPathBActive ? glowColor : Colors.grey[600],
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    pathAName.toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: !isPathBActive ? FontWeight.w900 : FontWeight.w600,
                      color: !isPathBActive
                          ? (isDarkMode ? Colors.white : Colors.black87)
                          : Colors.grey[600],
                      letterSpacing: 0.8,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                if (!isPathBActive)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: glowColor.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'ACTIVE',
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.bold,
                        color: glowColor,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 6),

        // Path B Pill (Up / 1.0)
        GestureDetector(
          onTap: () {
            if (switchPort != null) onSwitchPathChanged(switchPort, 1.0);
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
            decoration: BoxDecoration(
              color: isPathBActive
                  ? glowColor.withOpacity(isDarkMode ? 0.30 : 0.22)
                  : (isDarkMode ? Colors.black.withOpacity(0.25) : Colors.grey[200]),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isPathBActive ? glowColor : Colors.grey[800]!,
                width: isPathBActive ? 1.8 : 1.0,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isPathBActive ? Icons.radio_button_checked : Icons.radio_button_off,
                  size: 14,
                  color: isPathBActive ? glowColor : Colors.grey[600],
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    pathBName.toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isPathBActive ? FontWeight.w900 : FontWeight.w600,
                      color: isPathBActive
                          ? (isDarkMode ? Colors.white : Colors.black87)
                          : Colors.grey[600],
                      letterSpacing: 0.8,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                if (isPathBActive)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: glowColor.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'ACTIVE',
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.bold,
                        color: glowColor,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // 2. Toggle Mode Layout: Large clean title with elegant status badge
  Widget _buildToggleLayout(BuildContext context, bool isToggleActive) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Big bold name in center
          Text(
            displayName.toUpperCase(),
            style: TextStyle(
              fontSize: size == 'compact' ? 17.0 : 20.0,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
              color: isToggleActive
                  ? (isDarkMode ? Colors.white : Colors.black87)
                  : Colors.grey[600],
              overflow: TextOverflow.ellipsis,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
          ),
          const SizedBox(height: 8),
          // Clean status indicator pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: isToggleActive
                  ? glowColor.withOpacity(isDarkMode ? 0.25 : 0.20)
                  : (isDarkMode ? Colors.grey[900] : Colors.grey[300]),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isToggleActive ? glowColor : Colors.grey[700]!,
                width: 1.2,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: isToggleActive ? glowColor : Colors.grey[600],
                    shape: BoxShape.circle,
                    boxShadow: isToggleActive
                        ? [
                            BoxShadow(
                              color: glowColor,
                              blurRadius: 6,
                              spreadRadius: 1,
                            )
                          ]
                        : null,
                  ),
                ),
                const SizedBox(width: 7),
                Text(
                  isToggleActive ? 'ON' : 'OFF',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.0,
                    color: isToggleActive ? glowColor : Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

