// Copyright (c) 2026 TamperMod Contributors
// Licensed under the MIT License

import 'package:flutter/material.dart';
import '../../models/plugin_instance.dart';
import 'base_card.dart';

/// Generic placeholder card for unsupported controller types
class PlaceholderCard extends StatelessWidget {
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

  const PlaceholderCard({
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
  });

  @override
  Widget build(BuildContext context) {
    final bool isBypassed = pedal.isBypassed;
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
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: isDarkMode ? Colors.grey[600] : Colors.grey[700],
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Generic module',
                        style: TextStyle(
                          fontSize: 10,
                          color: isDarkMode ? Colors.grey[500] : Colors.grey[700],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
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
                                          fontSize: 16,
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
                                  ],
                                ),
                                const SizedBox(height: 2),
                                GestureDetector(
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
                              ],
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.power_settings_new,
                          color: powerIconColor,
                          size: 24,
                        ),
                        onPressed: () => onBypassToggle(!isBypassed),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.grey, height: 1),
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: isDarkMode ? Colors.grey[600] : Colors.grey[700],
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Custom card layout coming soon.',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDarkMode ? Colors.grey[500] : Colors.grey[700],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}
