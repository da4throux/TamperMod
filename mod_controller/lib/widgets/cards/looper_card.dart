// Copyright (c) 2026 TamperMod Contributors
// Licensed under the MIT License
//
// TODO: Extract ALO looper controller card

import 'package:flutter/material.dart';

/// ALO looper controller card widget
///
/// TODO: Move from main.dart:
/// - _buildLooperControlPanel() method
/// - _buildLooperTrackSegment() method
/// - _buildLooperSlider() method
/// - _build4BarTimeline() method
/// - _PulsingIndicator widget
/// - _findPortSymbol() method
class LooperCard extends StatefulWidget {
  final String instanceId;

  const LooperCard({super.key, required this.instanceId});

  @override
  State<LooperCard> createState() => _LooperCardState();
}

class _LooperCardState extends State<LooperCard> {
  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('TODO: Implement LooperCard'));
  }
}
