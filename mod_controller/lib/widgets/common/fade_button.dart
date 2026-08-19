// Copyright (c) 2026 TamperMod Contributors
// Licensed under the MIT License

import 'package:flutter/material.dart';

/// Reusable sleek fade button widget
class FadeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isBypassed;
  final VoidCallback onTap;
  final Color accentColor;
  final bool isFading;
  final bool isCompact;
  final bool takeFullHeight;

  const FadeButton({
    super.key,
    required this.label,
    required this.icon,
    required this.isBypassed,
    required this.onTap,
    required this.accentColor,
    required this.isFading,
    this.isCompact = false,
    this.takeFullHeight = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color buttonColor = isBypassed
        ? Colors.grey[700]!
        : (isFading ? const Color(0xFFFF0055) : accentColor);

    return GestureDetector(
      onTap: isBypassed ? null : onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: takeFullHeight ? double.infinity : null,
        alignment: Alignment.center,
        padding: EdgeInsets.symmetric(
          vertical: isCompact ? (takeFullHeight ? 2 : 6) : 8,
          horizontal: isCompact ? 6 : 10,
        ),
        decoration: BoxDecoration(
          color: isBypassed
              ? const Color(0xFF161B22)
              : (isFading
                  ? const Color(0xFFFF0055).withOpacity(0.25)
                  : accentColor.withOpacity(0.18)),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isBypassed
                ? Colors.grey[800]!
                : (isFading ? const Color(0xFFFF0055) : accentColor.withOpacity(0.6)),
            width: isFading ? 1.5 : 1.0,
          ),
          boxShadow: isFading
              ? [
                  BoxShadow(
                    color: const Color(0xFFFF0055).withOpacity(0.4),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: isCompact ? 12 : 14,
              color: buttonColor,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: isCompact ? 10.5 : 11.5,
                fontWeight: FontWeight.w900,
                letterSpacing: isCompact ? 0.6 : 0.8,
                color: buttonColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
