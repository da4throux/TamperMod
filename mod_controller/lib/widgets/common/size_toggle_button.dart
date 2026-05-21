// Copyright (c) 2026 TamperMod Contributors
// Licensed under the MIT License
//
// TODO: Extract reusable size toggle button widget

import 'package:flutter/material.dart';

/// Reusable size toggle button widget
///
/// TODO: Move from main.dart:
/// - buildSizeToggle() method logic from gain card
class SizeToggleButton extends StatelessWidget {
  final String instanceId;
  final String currentSize;
  final Color accentColor;
  final VoidCallback onTap;
  final bool isEnabled;

  const SizeToggleButton({
    super.key,
    required this.instanceId,
    required this.currentSize,
    required this.accentColor,
    required this.onTap,
    this.isEnabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isEnabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: isEnabled ? accentColor.withOpacity(0.12) : Colors.grey[800],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isEnabled ? accentColor : Colors.grey[700]!,
            width: 1.0,
          ),
        ),
        child: Icon(
          Icons.aspect_ratio,
          size: 18,
          color: isEnabled ? accentColor : Colors.grey[600],
        ),
      ),
    );
  }
}
