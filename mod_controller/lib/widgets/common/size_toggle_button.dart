// Copyright (c) 2026 TamperMod Contributors
// Licensed under the MIT License

import 'package:flutter/material.dart';

/// Reusable size toggle button widget
class SizeToggleButton extends StatelessWidget {
  final String instanceId;
  final String currentSize;
  final Color accentColor;
  final VoidCallback onTap;
  final bool isEnabled;
  final bool isDarkMode;

  const SizeToggleButton({
    super.key,
    required this.instanceId,
    required this.currentSize,
    required this.accentColor,
    required this.onTap,
    required this.isDarkMode,
    this.isEnabled = true,
  });

  @override
  Widget build(BuildContext context) {
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
          Icons.aspect_ratio,
          size: 18,
          color: Colors.grey[600],
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: (isDarkMode ? Colors.grey[800] : Colors.grey[300])!
              .withOpacity(0.5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: accentColor.withOpacity(0.4),
            width: 1.0,
          ),
        ),
        child: Icon(
          Icons.aspect_ratio,
          size: 18,
          color: accentColor,
        ),
      ),
    );
  }
}
