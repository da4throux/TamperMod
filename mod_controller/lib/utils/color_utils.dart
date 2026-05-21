// Copyright (c) 2026 TamperMod Contributors
// Licensed under the MIT License
//
// Color utilities for neon glow effects and hex conversion

import 'package:flutter/material.dart';

/// Neon colors palette — 10 colors for plugin glow assignment.
/// All plugins (including ALO Looper) use this palette equally.
const List<String> kNeonColors = [
  '#00FFCC', // Turquoise
  '#FF0055', // Hot Red
  '#9D00FF', // Purple
  '#00FF66', // Green
  '#FF7700', // Orange
  '#00FFFF', // Cyan
  '#FF00CC', // Hot Pink
  '#AAFF00', // Lime
  '#007FFF', // Sky Blue
  '#FF4D4D', // Coral
];

/// Returns the color from [kNeonColors] that is least represented
/// in [assignedColors] (a map of instanceId → hex color string).
///
/// Ties are broken by palette order (earlier colors preferred).
/// If [assignedColors] is empty, returns the first color in the palette.
String getLeastUsedColor(Map<String, String> assignedColors) {
  final Map<String, int> counts = {for (final c in kNeonColors) c: 0};

  for (final hex in assignedColors.values) {
    final normalized = hex.toUpperCase();
    for (final key in counts.keys) {
      if (key.toUpperCase() == normalized) {
        counts[key] = (counts[key] ?? 0) + 1;
        break;
      }
    }
  }

  String best = kNeonColors[0];
  int bestCount = counts[best] ?? 0;
  for (final color in kNeonColors) {
    final count = counts[color] ?? 0;
    if (count < bestCount) {
      best = color;
      bestCount = count;
    }
  }
  return best;
}

/// Convert hex color string to Flutter Color.
///
/// Handles both 6-digit and 3-digit hex color codes.
Color hexToColor(String hex) {
  final String cleanHex = hex.replaceAll('#', '');
  if (cleanHex.length == 6) {
    return Color(int.parse('FF$cleanHex', radix: 16));
  }
  return const Color(0xFF00FFCC); // Default to turquoise
}

/// Convert hex color to RGBA string for JavaScript.
///
/// Used for WebView glow effects and dynamic styling.
String hexToRgba(String hex, double alpha) {
  String c = hex.substring(1);
  if (c.length == 3) c = c[0] + c[0] + c[1] + c[1] + c[2] + c[2];
  final int r = int.parse(c.substring(0, 2), radix: 16);
  final int g = int.parse(c.substring(2, 4), radix: 16);
  final int b = int.parse(c.substring(4, 6), radix: 16);
  return 'rgba($r, $g, $b, $alpha)';
}
