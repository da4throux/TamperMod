// Copyright (c) 2026 TamperMod Contributors
// Licensed under the MIT License
//
// TODO: Extract color utilities

import 'package:flutter/material.dart';

/// Neon colors palette for permanent visual cues
const List<String> kNeonColors = [
  '#00FFCC', // Turquoise
  '#FF0055', // Pink
  '#9D00FF', // Purple
  '#00FF66', // Green
  '#FF7700', // Orange
];

/// Convert hex color string to Flutter Color
///
/// TODO: Move from main.dart:
/// - _hexToColor() method
Color hexToColor(String hex) {
  final String cleanHex = hex.replaceAll('#', '');
  if (cleanHex.length == 6) {
    return Color(int.parse('FF$cleanHex', radix: 16));
  }
  return const Color(0xFF00FFCC);
}

/// Convert hex color to RGBA string for JavaScript
String hexToRgba(String hex, double alpha) {
  String c = hex.substring(1);
  if (c.length == 3) c = c[0] + c[0] + c[1] + c[1] + c[2] + c[2];
  final int r = int.parse(c.substring(0, 2), radix: 16);
  final int g = int.parse(c.substring(2, 4), radix: 16);
  final int b = int.parse(c.substring(4, 6), radix: 16);
  return 'rgba($r, $g, $b, $alpha)';
}
