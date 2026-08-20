// Copyright (c) 2026 TamperMod Contributors
// Licensed under the MIT License

import 'package:flutter/material.dart';

/// Reusable sleek fade button widget
class FadeButton extends StatelessWidget {
  final String label;
  final String? subLabel;
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
    this.subLabel,
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
          vertical: isCompact ? (takeFullHeight ? 2 : 4) : 6,
          horizontal: isCompact ? 4 : 8,
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: isCompact ? 11 : 13,
                  color: buttonColor,
                ),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: isCompact ? 9.5 : 11.0,
                    fontWeight: FontWeight.w900,
                    letterSpacing: isCompact ? 0.5 : 0.7,
                    color: buttonColor,
                  ),
                ),
              ],
            ),
            if (subLabel != null && subLabel!.isNotEmpty) ...[
              const SizedBox(height: 1.5),
              Text(
                subLabel!,
                style: TextStyle(
                  fontSize: isCompact ? 7.5 : 8.5,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                  color: isFading ? Colors.white : buttonColor.withOpacity(0.85),
                  letterSpacing: 0.3,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
