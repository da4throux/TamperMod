// Copyright (c) 2026 TamperMod Contributors
// Licensed under the MIT License
//
// TODO: Extract reusable fade button widget

import 'package:flutter/material.dart';

/// Reusable fade button widget
///
/// TODO: Move from main.dart:
/// - _buildFadeButton() method logic
class FadeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isBypassed;
  final VoidCallback onTap;
  final Color accentColor;
  final bool isFading;
  final bool isCompact;

  const FadeButton({
    super.key,
    required this.label,
    required this.icon,
    required this.isBypassed,
    required this.onTap,
    required this.accentColor,
    required this.isFading,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: ElevatedButton.icon(
          onPressed: isBypassed ? null : onTap,
          icon: Icon(icon, size: isCompact ? 10 : 13),
          label: Text(label),
        ),
      ),
    );
  }
}
