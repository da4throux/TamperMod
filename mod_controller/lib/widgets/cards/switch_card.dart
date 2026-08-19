// Copyright (c) 2026 TamperMod Contributors
// Licensed under the MIT License

import 'package:flutter/material.dart';
import '../../models/plugin_instance.dart';

/// Switch/routing controller card widget with dual layout modes:
/// 1. Route Mode: 2-Path selection (Path A vs Path B) with custom labels in high-contrast button boxes
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

    final bool isPluginPowered = !pedal.isBypassed;
    final bool isCardActive = isRouteMode ? isPluginPowered : (isToggleActive && isPluginPowered);
    final Color accentColor = isPluginPowered ? glowColor : Colors.grey[600]!;

    void toggleSwitch() {
      if (switchPort != null) {
        final double nextVal = currentValue >= 0.5 ? 0.0 : 1.0;
        onSwitchPathChanged(switchPort, nextVal);
      } else {
        onBypassToggle(!pedal.isBypassed);
      }
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: toggleSwitch,
      onLongPress: onColorPickerPressed,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: isPluginPowered ? 1.0 : 0.60,
        child: Container(
          decoration: BoxDecoration(
            color: isCardActive
                ? glowColor.withOpacity(isDarkMode ? 0.12 : 0.08)
                : (isDarkMode ? const Color(0xFF10141D) : const Color(0xFFF4F6F9)),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isPluginPowered
                  ? glowColor.withOpacity(isCardActive ? 0.85 : 0.3)
                  : (isDarkMode ? Colors.grey[800]! : Colors.grey[350]!),
              width: isCardActive ? 2.0 : 1.2,
            ),
            boxShadow: isCardActive
                ? [
                    BoxShadow(
                      color: glowColor.withOpacity(0.60),
                      blurRadius: 10,
                      spreadRadius: 1.5,
                    ),
                    BoxShadow(
                      color: glowColor.withOpacity(isDarkMode ? 0.18 : 0.25),
                      blurRadius: 80,
                      spreadRadius: 2,
                    ),
                  ]
                : [],
          ),
          child: Padding(
            padding: EdgeInsets.all(size == 'compact' ? 10.0 : 13.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Top Header Row (Name + Edit + Radar + Power Button) ──
                Row(
                  children: [
                    // Card Title in high-contrast capsule
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDarkMode
                              ? const Color(0xFF181F2C).withOpacity(0.92)
                              : Colors.white.withOpacity(0.92),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isDarkMode ? Colors.grey[800]! : Colors.grey[300]!,
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          displayName.toUpperCase(),
                          style: TextStyle(
                            fontSize: size == 'compact' ? 11.5 : 13.0,
                            fontWeight: FontWeight.w900,
                            color: isDarkMode ? Colors.white : Colors.black87,
                            letterSpacing: 0.8,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),

                    // Edit Pen Button
                    GestureDetector(
                      onTap: onRenamePressed,
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: isDarkMode
                              ? const Color(0xFF1C2433)
                              : Colors.grey[200],
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isDarkMode ? Colors.grey[800]! : Colors.grey[300]!,
                            width: 0.8,
                          ),
                        ),
                        child: Icon(
                          Icons.edit,
                          size: 13,
                          color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),

                    // Radar Highlight Button
                    GestureDetector(
                      onTap: onHighlightPressed,
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: isDarkMode
                              ? const Color(0xFF1C2433)
                              : Colors.grey[200],
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isDarkMode ? Colors.grey[800]! : Colors.grey[300]!,
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

                    // Power ON/OFF Button
                    GestureDetector(
                      onTap: () => onBypassToggle(!pedal.isBypassed),
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: isPluginPowered
                              ? glowColor.withOpacity(isDarkMode ? 0.25 : 0.18)
                              : (isDarkMode ? const Color(0xFF1C2433) : Colors.grey[200]),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isPluginPowered ? glowColor : Colors.grey[700]!,
                            width: isPluginPowered ? 1.2 : 0.8,
                          ),
                        ),
                        child: Icon(
                          Icons.power_settings_new,
                          size: 14,
                          color: isPluginPowered ? glowColor : Colors.grey[500],
                        ),
                      ),
                    ),
                  ],
                ),

                const Spacer(),

                // ── Center Content: Route Mode vs Toggle Mode in Button Boxes ──
                if (isRouteMode)
                  _buildRouteSelector(context, isPathBActive, switchPort)
                else
                  _buildToggleLayout(context, isToggleActive, isPluginPowered, switchPort, currentValue),

                const Spacer(),

                // ── Bottom Port Info Footer ──
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? const Color(0xFF131822).withOpacity(0.8)
                        : Colors.grey[200]!.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    switchPort != null
                        ? '$switchPort: ${currentValue.toStringAsFixed(1)}'
                        : (pedal.parameters.isNotEmpty
                            ? 'Params: ${pedal.parameters.keys.join(", ")}'
                            : 'Bypass mode'),
                    style: TextStyle(
                      fontSize: 8.5,
                      color: isDarkMode ? Colors.grey[400] : Colors.grey[700],
                      fontFamily: 'monospace',
                      overflow: TextOverflow.ellipsis,
                    ),
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 1. Route Mode: Two high-contrast independent button boxes for Path A and Path B
  Widget _buildRouteSelector(BuildContext context, bool isPathBActive, String? switchPort) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Path A Box (Down / 0.0)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 10),
          decoration: BoxDecoration(
            color: !isPathBActive
                ? (isDarkMode ? const Color(0xFF192535) : Colors.white)
                : (isDarkMode ? const Color(0xFF121620) : const Color(0xFFE8EEF5)),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: !isPathBActive ? glowColor : (isDarkMode ? Colors.grey[850]! : Colors.grey[350]!),
              width: !isPathBActive ? 1.8 : 1.0,
            ),
            boxShadow: !isPathBActive
                ? [
                    BoxShadow(
                      color: glowColor.withOpacity(0.25),
                      blurRadius: 6,
                      spreadRadius: 0.5,
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Icon(
                !isPathBActive ? Icons.radio_button_checked : Icons.radio_button_off,
                size: 15,
                color: !isPathBActive ? glowColor : Colors.grey[500],
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
                        : (isDarkMode ? Colors.grey[400] : Colors.grey[600]),
                    letterSpacing: 0.8,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              if (!isPathBActive)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: glowColor.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: glowColor.withOpacity(0.6), width: 0.8),
                  ),
                  child: Text(
                    'ACTIVE',
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w900,
                      color: glowColor,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
            ],
          ),
        ),

        const SizedBox(height: 7),

        // Path B Box (Up / 1.0)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 10),
          decoration: BoxDecoration(
            color: isPathBActive
                ? (isDarkMode ? const Color(0xFF192535) : Colors.white)
                : (isDarkMode ? const Color(0xFF121620) : const Color(0xFFE8EEF5)),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: isPathBActive ? glowColor : (isDarkMode ? Colors.grey[850]! : Colors.grey[350]!),
              width: isPathBActive ? 1.8 : 1.0,
            ),
            boxShadow: isPathBActive
                ? [
                    BoxShadow(
                      color: glowColor.withOpacity(0.25),
                      blurRadius: 6,
                      spreadRadius: 0.5,
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Icon(
                isPathBActive ? Icons.radio_button_checked : Icons.radio_button_off,
                size: 15,
                color: isPathBActive ? glowColor : Colors.grey[500],
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
                        : (isDarkMode ? Colors.grey[400] : Colors.grey[600]),
                    letterSpacing: 0.8,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              if (isPathBActive)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: glowColor.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: glowColor.withOpacity(0.6), width: 0.8),
                  ),
                  child: Text(
                    'ACTIVE',
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w900,
                      color: glowColor,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // 2. Toggle Mode: High-contrast independent button box with prominent name and status pill
  Widget _buildToggleLayout(
    BuildContext context,
    bool isToggleActive,
    bool isPluginPowered,
    String? switchPort,
    double currentValue,
  ) {
    final bool isActuallyOn = isToggleActive && isPluginPowered;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: isDarkMode
            ? (isActuallyOn ? const Color(0xFF162030) : const Color(0xFF131822))
            : (isActuallyOn ? Colors.white : const Color(0xFFE8EEF5)),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActuallyOn
              ? glowColor
              : (isDarkMode ? Colors.grey[800]! : Colors.grey[350]!),
          width: isActuallyOn ? 1.8 : 1.0,
        ),
        boxShadow: isActuallyOn
            ? [
                BoxShadow(
                  color: glowColor.withOpacity(0.22),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Bold prominent name in high contrast
          Text(
            displayName.toUpperCase(),
            style: TextStyle(
              fontSize: size == 'compact' ? 15.0 : 18.0,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
              color: isDarkMode ? Colors.white : Colors.black87,
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
              color: isActuallyOn
                  ? glowColor.withOpacity(isDarkMode ? 0.25 : 0.20)
                  : (isDarkMode ? const Color(0xFF0D1117) : Colors.grey[300]),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isActuallyOn ? glowColor : Colors.grey[700]!,
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
                    color: isActuallyOn ? glowColor : Colors.grey[600],
                    shape: BoxShape.circle,
                    boxShadow: isActuallyOn
                        ? [
                            BoxShadow(
                              color: glowColor,
                              blurRadius: 6,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                ),
                const SizedBox(width: 7),
                Text(
                  isActuallyOn ? 'ON' : 'OFF',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.0,
                    color: isActuallyOn
                        ? (isDarkMode ? Colors.white : glowColor)
                        : (isDarkMode ? Colors.grey[500] : Colors.grey[700]),
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

