// Copyright (c) 2026 TamperMod Contributors
// Licensed under the MIT License

import 'package:flutter/material.dart';
import '../../models/plugin_instance.dart';
import '../../utils/plugin_category.dart';

/// Reusable size toggle button widget displaying effect category icon
class SizeToggleButton extends StatelessWidget {
  final String instanceId;
  final String currentSize;
  final Color accentColor;
  final VoidCallback onTap;
  final bool isEnabled;
  final bool isDarkMode;
  final VoidCallback? onLongPress;
  final PluginInstance? pedal;
  final IconData? icon;

  const SizeToggleButton({
    super.key,
    required this.instanceId,
    required this.currentSize,
    required this.accentColor,
    required this.onTap,
    required this.isDarkMode,
    this.isEnabled = true,
    this.onLongPress,
    this.pedal,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final category = pedal != null ? PluginCategoryHelper.getCategoryForPlugin(pedal!) : null;
    final IconData displayIcon = icon ?? (category?.icon ?? Icons.tune);
    final Color iconColor = category?.defaultColor ?? accentColor;

    if (!isEnabled) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: (isDarkMode ? Colors.grey[800] : Colors.grey[300])!
              .withOpacity(0.3),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.grey.withOpacity(0.3),
            width: 1.0,
          ),
        ),
        child: Icon(
          displayIcon,
          size: 16,
          color: Colors.grey[600],
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
        decoration: BoxDecoration(
          color: (isDarkMode ? const Color(0xFF161B22) : const Color(0xFFF2F4F7))
              .withOpacity(0.9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: iconColor.withOpacity(0.6),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: iconColor.withOpacity(0.2),
              blurRadius: 4,
              spreadRadius: 0.5,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              displayIcon,
              size: 15,
              color: iconColor,
            ),
            const SizedBox(width: 3.5),
            Text(
              currentSize.isNotEmpty ? currentSize[0].toUpperCase() : 'R',
              style: TextStyle(
                fontSize: 9.0,
                fontWeight: FontWeight.w900,
                color: accentColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

