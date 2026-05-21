// Copyright (c) 2026 TamperMod Contributors
// Licensed under the MIT License

import 'package:flutter/material.dart';

/// Reusable fade button widget
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
          icon: Icon(
            icon,
            size: isCompact ? 10 : 13,
            color: isFading ? const Color(0xFFFF007F) : Colors.black,
          ),
          label: Text(
            label,
            style: TextStyle(
              fontSize: isCompact ? 9 : 11,
              fontWeight: FontWeight.w900,
              letterSpacing: isCompact ? 0.5 : 1.0,
              color: isFading ? const Color(0xFFFF007F) : Colors.black,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: isFading
                ? const Color(0xFFFF007F).withOpacity(0.12)
                : accentColor,
            disabledBackgroundColor: Colors.grey[800],
            padding: EdgeInsets.symmetric(vertical: isCompact ? 4 : 8),
            elevation: isFading ? 4 : 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: isFading
                  ? const BorderSide(color: Color(0xFFFF007F), width: 1.5)
                  : BorderSide.none,
            ),
          ),
        ),
      ),
    );
  }
}
