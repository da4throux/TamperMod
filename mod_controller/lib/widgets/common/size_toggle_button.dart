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
    final IconData displayIcon = icon ??
        (pedal != null
            ? PluginCategoryHelper.getCategoryForPlugin(pedal!).icon
            : Icons.tune);

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
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: (isDarkMode ? Colors.grey[800] : Colors.grey[300])!
              .withOpacity(0.5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: accentColor.withOpacity(0.5),
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              displayIcon,
              size: 16,
              color: accentColor,
            ),
            const SizedBox(width: 3),
            Text(
              currentSize.isNotEmpty ? currentSize[0].toUpperCase() : 'R',
              style: TextStyle(
                fontSize: 8.5,
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

