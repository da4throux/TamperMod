// Copyright (c) 2026 TamperMod Contributors
// Licensed under the MIT License

import 'package:flutter/material.dart';

/// Bottom toolbar widget with view selectors and theme toggle
class BottomToolbar extends StatelessWidget {
  final bool isDarkMode;
  final bool showControls;
  final bool showWeb;
  final bool isConnected;
  final VoidCallback onToggleControls;
  final VoidCallback onToggleWeb;
  final VoidCallback onControlsOnly;
  final VoidCallback onWebOnly;
  final VoidCallback onRadarTap;
  final VoidCallback onRefreshTap;
  final VoidCallback onThemeToggle;
  final String appVersion;

  const BottomToolbar({
    super.key,
    required this.isDarkMode,
    required this.showControls,
    required this.showWeb,
    required this.isConnected,
    required this.onToggleControls,
    required this.onToggleWeb,
    required this.onControlsOnly,
    required this.onWebOnly,
    required this.onRadarTap,
    required this.onRefreshTap,
    required this.onThemeToggle,
    required this.appVersion,
  });

  Widget _buildLayoutButton({
    required IconData icon,
    required String tooltip,
    required bool isActive,
    required VoidCallback onTap,
    required VoidCallback onLongPress,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isActive
                ? const Color(0xFF00FFCC).withOpacity(0.12)
                : Colors.transparent,
            border: Border.all(
              color: isActive
                  ? const Color(0xFF00FFCC).withOpacity(0.4)
                  : Colors.transparent,
              width: 1,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: isActive ? const Color(0xFF00FFCC) : Colors.grey[600],
            size: 22,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = isDarkMode
        ? const Color(0xFF00FFCC)
        : const Color(0xFF00B3FF);
    final accentColor = const Color(0xFFFF007F);

    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF0F141C) : const Color(0xFFE4E6EB),
        border: Border(
          top: BorderSide(color: primaryColor.withOpacity(0.3), width: 1.5),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: View Mode Selectors
          Row(
            children: [
              _buildLayoutButton(
                icon: Icons.tune,
                tooltip: 'Toggle Controls view',
                isActive: showControls,
                onTap: onToggleControls,
                onLongPress: onControlsOnly,
              ),
              const SizedBox(width: 8),
              _buildLayoutButton(
                icon: Icons.language,
                tooltip: 'Toggle Web interface',
                isActive: showWeb,
                onTap: onToggleWeb,
                onLongPress: onWebOnly,
              ),
            ],
          ),

          // Center: Radar locate & Reload pedalboard
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.radar, color: accentColor, size: 20),
                tooltip: 'Glow all Workspace Pedals in Web GUI',
                onPressed: isConnected ? onRadarTap : null,
              ),
              const SizedBox(width: 12),
              IconButton(
                icon: Icon(
                  Icons.refresh,
                  color: isDarkMode
                      ? const Color(0xFF00FFCC)
                      : const Color(0xFF009977),
                  size: 20,
                ),
                tooltip: 'Refresh Pedalboard',
                onPressed: isConnected ? onRefreshTap : null,
              ),
            ],
          ),

          // Right: Theme Toggler & Version Label
          Row(
            children: [
              IconButton(
                icon: Icon(
                  isDarkMode
                      ? Icons.wb_sunny_outlined
                      : Icons.nightlight_round,
                  color: isDarkMode
                      ? const Color(0xFFFF7700)
                      : const Color(0xFF9D00FF),
                  size: 20,
                ),
                tooltip: isDarkMode
                    ? 'Switch to Daylight Theme'
                    : 'Switch to Midnight Theme',
                onPressed: onThemeToggle,
              ),
              const SizedBox(width: 8),
              Text(
                'v$appVersion',
                style: TextStyle(
                  color: isDarkMode ? Colors.grey[500] : Colors.grey[600],
                  fontFamily: 'monospace',
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
