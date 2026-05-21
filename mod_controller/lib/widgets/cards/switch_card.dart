// Copyright (c) 2026 TamperMod Contributors
// Licensed under the MIT License
//
// TODO: Extract Switch/routing controller card

import 'package:flutter/material.dart';

/// Switch/routing controller card widget
///
/// TODO: Move from main.dart:
/// - _buildSwitchCard() method
/// - _getSwitchPortSymbol() method
/// - _setSwitchPath() method
class SwitchCard extends StatefulWidget {
  final String instanceId;

  const SwitchCard({super.key, required this.instanceId});

  @override
  State<SwitchCard> createState() => _SwitchCardState();
}

class _SwitchCardState extends State<SwitchCard> {
  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('TODO: Implement SwitchCard'));
  }
}
