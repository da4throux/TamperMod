// Copyright (c) 2026 TamperMod Contributors
// Licensed under the MIT License
//
// TODO: Create shared card shell with glow, border, padding

import 'package:flutter/material.dart';

/// Base card widget providing shared styling and glow effects
///
/// TODO: Extract common card decoration logic:
/// - Glow color configuration
/// - Border styling
/// - Box shadow effects
/// - Padding and border radius
class BaseCard extends StatelessWidget {
  final Widget child;
  final Color glowColor;
  final bool isBypassed;
  final VoidCallback? onLongPress;

  const BaseCard({
    super.key,
    required this.child,
    required this.glowColor,
    this.isBypassed = false,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: onLongPress,
      child: Opacity(
        opacity: isBypassed ? 0.70 : 1.0,
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: glowColor.withOpacity(isBypassed ? 0.25 : 0.6),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: glowColor.withOpacity(isBypassed ? 0.0 : 0.85),
                blurRadius: 8,
                spreadRadius: 2,
              ),
              BoxShadow(
                color: glowColor.withOpacity(isBypassed ? 0.0 : 0.20),
                blurRadius: 80,
                spreadRadius: 2,
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
