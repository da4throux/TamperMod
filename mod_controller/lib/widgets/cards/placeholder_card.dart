// Copyright (c) 2026 TamperMod Contributors
// Licensed under the MIT License
//
// TODO: Extract generic fallback card

import 'package:flutter/material.dart';

/// Generic placeholder card for unsupported controller types
///
/// TODO: Move from main.dart:
/// - _buildPlaceholderCard() method
class PlaceholderCard extends StatelessWidget {
  final String instanceId;

  const PlaceholderCard({super.key, required this.instanceId});

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('TODO: Implement PlaceholderCard'));
  }
}
