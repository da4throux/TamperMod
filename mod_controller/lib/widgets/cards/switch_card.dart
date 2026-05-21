// Copyright (c) 2026 TamperMod Contributors
// Licensed under the MIT License

import 'package:flutter/material.dart';
import '../../models/plugin_instance.dart';
import '../common/module_help_sheet.dart';
import 'base_card.dart';

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
          s.contains('mode')) {
        return symbol;
      }
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

    final bool isPathB = currentValue >= 0.5;
    final Color accentColor = isBypassed ? Colors.grey[600]! : glowColor;
    final Color powerIconColor = isBypassed ? const Color(0xFFFF007F) : glowColor;

    return BaseCard(
      glowColor: glowColor,
      isBypassed: isBypassed,
      isDarkMode: isDarkMode,
      onLongPress: onColorPickerPressed,
      child: Padding(
        padding: EdgeInsets.all(size == 'compact' ? 10.0 : 16.0),
        child: size == 'compact'
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: onHighlightPressed,
                          child: Text(
                            displayName.toUpperCase(),
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w900,
                              color: accentColor,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.edit,
                          size: 12,
                          color: isDarkMode ? Colors.grey[500] : Colors.grey[600],
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: onRenamePressed,
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: Icon(
                          Icons.help_outline,
                          size: 12,
                          color: accentColor.withOpacity(0.8),
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => ModuleHelpSheet.show(context, 'switch', isDarkMode),
                      ),
                      const SizedBox(width: 8),
                      // Compact Power Switch
                      GestureDetector(
                        onTap: () => onBypassToggle(!isBypassed),
                        child: Icon(
                          Icons.power_settings_new,
                          color: powerIconColor,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Path selector A/B row
                  Row(
                    children: [
                      Icon(
                        Icons.alt_route,
                        color: isDarkMode
                            ? Colors.grey[isBypassed ? 700 : 600]
                            : Colors.grey[isBypassed ? 600 : 700],
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Switch: ${switchPort ?? "None"}',
                          style: TextStyle(
                            fontSize: 9.5,
                            color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isBypassed
                              ? Colors.grey[800]
                              : (isPathB
                                  ? const Color(0xFFFF007F).withOpacity(0.12)
                                  : const Color(0xFF00FFCC).withOpacity(0.12)),
                          foregroundColor: isBypassed
                              ? Colors.grey
                              : (isPathB ? const Color(0xFFFF007F) : const Color(0xFF00FFCC)),
                          side: BorderSide(
                            color: isBypassed
                                ? Colors.grey[700]!
                                : (isPathB ? const Color(0xFFFF007F) : const Color(0xFF00FFCC)),
                            width: 1.0,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          minimumSize: const Size(60, 24),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        onPressed: isBypassed || switchPort == null
                            ? null
                            : () => onSwitchPathChanged(switchPort, isPathB ? 0.0 : 1.0),
                        child: Text(
                          isPathB ? 'PATH B' : 'PATH A',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: onHighlightPressed,
                          child: Tooltip(
                            message: 'Tap to locate in Web interface',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        displayName.toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w900,
                                          color: accentColor,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        Icons.edit,
                                        size: 14,
                                        color: isDarkMode ? Colors.grey[500] : Colors.grey[600],
                                      ),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: onRenamePressed,
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: Icon(
                                        Icons.help_outline,
                                        size: 14,
                                        color: accentColor.withOpacity(0.8),
                                      ),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () => ModuleHelpSheet.show(context, 'switch', isDarkMode),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () => onOpenUri(pedal.uri),
                                        child: Text(
                                          pedal.uri,
                                          style: TextStyle(
                                            fontSize: 8.5,
                                            color: isDarkMode
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
                                    Text(
                                      'Switch: ${switchPort ?? "None"}',
                                      style: TextStyle(
                                        fontSize: 8.5,
                                        color: isDarkMode ? Colors.grey[500] : Colors.grey[700],
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.power_settings_new,
                          color: powerIconColor,
                          size: 26,
                        ),
                        onPressed: () => onBypassToggle(!isBypassed),
                      ),
                    ],
                  ),
                  const Spacer(),

                  // Custom A / B Switch Control
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // PATH A Button
                      GestureDetector(
                        onTap: isBypassed || switchPort == null
                            ? null
                            : () => onSwitchPathChanged(switchPort, 0.0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          decoration: BoxDecoration(
                            color: (!isPathB && !isBypassed)
                                ? const Color(0xFF00FFCC).withOpacity(0.12)
                                : (isDarkMode ? Colors.black.withOpacity(0.3) : Colors.grey[200]),
                            borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                            border: Border.all(
                              color: (!isPathB && !isBypassed)
                                  ? const Color(0xFF00FFCC)
                                  : (isDarkMode ? Colors.grey[800]! : Colors.grey[400]!),
                              width: 1.5,
                            ),
                          ),
                          child: Text(
                            'PATH A (CLEAN)',
                            style: TextStyle(
                              color: (!isPathB && !isBypassed)
                                  ? const Color(0xFF00FFCC)
                                  : (isDarkMode ? Colors.grey[600] : Colors.grey[700]),
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                      ),

                      // PATH B Button
                      GestureDetector(
                        onTap: isBypassed || switchPort == null
                            ? null
                            : () => onSwitchPathChanged(switchPort, 1.0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          decoration: BoxDecoration(
                            color: (isPathB && !isBypassed)
                                ? const Color(0xFFFF007F).withOpacity(0.12)
                                : (isDarkMode ? Colors.black.withOpacity(0.3) : Colors.grey[200]),
                            borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
                            border: Border.all(
                              color: (isPathB && !isBypassed)
                                  ? const Color(0xFFFF007F)
                                  : (isDarkMode ? Colors.grey[800]! : Colors.grey[400]!),
                              width: 1.5,
                            ),
                          ),
                          child: Text(
                            'PATH B (HEAVY)',
                            style: TextStyle(
                              color: (isPathB && !isBypassed)
                                  ? const Color(0xFFFF007F)
                                  : (isDarkMode ? Colors.grey[600] : Colors.grey[700]),
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                ],
              ),
      ),
    );
  }
}
