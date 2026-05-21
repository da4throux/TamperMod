// Copyright (c) 2026 TamperMod Contributors
// Licensed under the MIT License

import 'package:flutter/material.dart';
import '../../services/websocket_service.dart';

/// Metrics drawer widget showing dashboard metrics and navigation
class MetricsDrawer extends StatelessWidget {
  final bool isDarkMode;
  final double bpm;
  final int activeCount;
  final int totalCount;
  final ConnectionStatus connectionStatus;
  final VoidCallback onRadarTap;
  final VoidCallback onRefreshTap;
  final VoidCallback onOpenBrowser;
  final VoidCallback onThemeToggle;
  final String appVersion;

  const MetricsDrawer({
    super.key,
    required this.isDarkMode,
    required this.bpm,
    required this.activeCount,
    required this.totalCount,
    required this.connectionStatus,
    required this.onRadarTap,
    required this.onRefreshTap,
    required this.onOpenBrowser,
    required this.onThemeToggle,
    required this.appVersion,
  });

  Color _getStatusColor(ConnectionStatus status) {
    switch (status) {
      case ConnectionStatus.connected:
        return const Color(0xFF00FFCC); // Neon Turquoise
      case ConnectionStatus.connecting:
        return Colors.amberAccent;
      case ConnectionStatus.disconnected:
        return const Color(0xFFFF007F); // Neon Pink
    }
  }

  Widget _buildLeftDrawerHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: isDarkMode ? Colors.grey[500] : Colors.grey[600],
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildLeftDrawerTile({
    required IconData icon,
    required String title,
    required String trailingText,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.grey[350] : Colors.grey[800],
            ),
          ),
          const Spacer(),
          Text(
            trailingText,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = connectionStatus == ConnectionStatus.connected;

    return Container(
      color: isDarkMode ? const Color(0xFF0F141C) : Colors.white,
      child: Column(
        children: [
          // Drawer Header
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 20,
              bottom: 24,
              left: 20,
              right: 20,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDarkMode
                    ? [const Color(0xFF161B22), const Color(0xFF0F141C)]
                    : [const Color(0xFFE4E6EB), const Color(0xFFF0F2F5)],
              ),
              border: Border(
                bottom: BorderSide(
                  color: isDarkMode
                      ? const Color(0xFF00FFCC)
                      : const Color(0xFF00B3FF),
                  width: 1.5,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: isDarkMode
                          ? [const Color(0xFF00FFCC), const Color(0xFFFF007F)]
                          : [const Color(0xFF00B3FF), const Color(0xFFFF0055)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (isDarkMode
                                ? const Color(0xFF00FFCC)
                                : const Color(0xFF00B3FF))
                            .withOpacity(0.4),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(Icons.tune, size: 20, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TAMPERMOD',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.0,
                          color: isDarkMode ? Colors.white : Colors.black,
                        ),
                      ),
                      Text(
                        'LIVE CONTROLLER',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode
                              ? const Color(0xFF00FFCC)
                              : const Color(0xFF00B3FF),
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Drawer Navigation / Info Items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 12),
              children: [
                _buildLeftDrawerHeader('DASHBOARD METRICS'),
                _buildLeftDrawerTile(
                  icon: Icons.grid_view,
                  title: 'Active Controls',
                  trailingText: '$activeCount / $totalCount',
                  color: isDarkMode
                      ? const Color(0xFF00FFCC)
                      : const Color(0xFF00B3FF),
                ),
                _buildLeftDrawerTile(
                  icon: Icons.speed,
                  title: 'BPM / Tempo',
                  trailingText: '${bpm.toStringAsFixed(0)} BPM',
                  color: const Color(0xFFFF007F),
                ),
                _buildLeftDrawerTile(
                  icon: Icons.link,
                  title: 'Connection State',
                  trailingText: isConnected ? 'CONNECTED' : 'DISCONNECTED',
                  color: _getStatusColor(connectionStatus),
                ),

                const Divider(height: 24, thickness: 1, color: Colors.grey),
                _buildLeftDrawerHeader('QUICK UTILITIES'),

                ListTile(
                  leading: const Icon(
                    Icons.radar,
                    color: Color(0xFFFF007F),
                    size: 20,
                  ),
                  title: Text(
                    'Locate Workspace Pedals',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                  subtitle: const Text(
                    'strobe pulses on the web canvas',
                    style: TextStyle(fontSize: 10),
                  ),
                  onTap: isConnected
                      ? () {
                          Navigator.pop(context);
                          onRadarTap();
                        }
                      : null,
                ),
                ListTile(
                  leading: const Icon(
                    Icons.refresh,
                    color: Color(0xFF00FFCC),
                    size: 20,
                  ),
                  title: Text(
                    'Refresh Pedalboard',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                  subtitle: const Text(
                    'query parameters from mod dwarf',
                    style: TextStyle(fontSize: 10),
                  ),
                  onTap: isConnected
                      ? () {
                          Navigator.pop(context);
                          onRefreshTap();
                        }
                      : null,
                ),
                ListTile(
                  leading: const Icon(
                    Icons.open_in_browser,
                    color: Color(0xFFFF5500),
                    size: 20,
                  ),
                  title: Text(
                    'Open Pedalboard in Browser',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                  subtitle: const Text(
                    'launch Web interface in Chrome',
                    style: TextStyle(fontSize: 10),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    onOpenBrowser();
                  },
                ),
                ListTile(
                  leading: Icon(
                    isDarkMode ? Icons.light_mode : Icons.dark_mode,
                    color: isDarkMode
                        ? const Color(0xFFFF7700)
                        : const Color(0xFF9D00FF),
                    size: 20,
                  ),
                  title: Text(
                    isDarkMode ? 'Daylight Theme' : 'Midnight Theme',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                  subtitle: const Text(
                    'optimize display for direct sunlight',
                    style: TextStyle(fontSize: 10),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    onThemeToggle();
                  },
                ),
              ],
            ),
          ),

          // Drawer Footer Version Tracking
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: isDarkMode
                      ? const Color(0xFF161B22)
                      : const Color(0xFFE4E6EB),
                  width: 1,
                ),
              ),
            ),
            child: Text(
              'VERSION $appVersion',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
                color: isDarkMode
                    ? const Color(0xFF00FFCC)
                    : const Color(0xFF00B3FF),
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
