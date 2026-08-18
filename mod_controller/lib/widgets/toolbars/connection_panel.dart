// Copyright (c) 2026 TamperMod Contributors
// Licensed under the MIT License

import 'package:flutter/material.dart';
import 'package:mod_controller/services/websocket_service.dart';

/// Connection panel widget for IP input and connection control
class ConnectionPanel extends StatelessWidget {
  final bool isDarkMode;
  final TextEditingController ipController;
  final ConnectionStatus connectionStatus;
  final VoidCallback onConnectDisconnect;
  final VoidCallback onOpenBrowser;
  final Color Function(ConnectionStatus) getStatusColor;

  final ValueChanged<String>? onIpSelected;

  const ConnectionPanel({
    super.key,
    required this.isDarkMode,
    required this.ipController,
    required this.connectionStatus,
    required this.onConnectDisconnect,
    required this.onOpenBrowser,
    required this.getStatusColor,
    this.onIpSelected,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDisconnected = connectionStatus == ConnectionStatus.disconnected;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF161B22) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: getStatusColor(connectionStatus).withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: isDarkMode
            ? null
            : [
                BoxShadow(
                  color: Colors.grey.withValues(alpha: 0.1),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: ipController,
              decoration: InputDecoration(
                labelText: 'MOD Dwarf IP',
                labelStyle: TextStyle(
                  color: isDarkMode ? Colors.grey : Colors.grey[700],
                  fontSize: 11,
                ),
                border: InputBorder.none,
                prefixIcon: Icon(
                  Icons.lan,
                  color: isDarkMode ? Colors.grey : Colors.grey[600],
                  size: 18,
                ),
                suffixIcon: isDisconnected
                    ? PopupMenuButton<String>(
                        icon: Icon(
                          Icons.arrow_drop_down_circle_outlined,
                          color: isDarkMode
                              ? const Color(0xFF00FFCC)
                              : const Color(0xFF00B3FF),
                          size: 20,
                        ),
                        tooltip: 'Select IP Preset',
                        onSelected: (String value) {
                          ipController.text = value;
                          if (onIpSelected != null) {
                            onIpSelected!(value);
                          }
                        },
                        itemBuilder: (BuildContext context) => [
                          const PopupMenuItem(
                            value: '192.168.51.1',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Direct USB (Pixel Tablet)',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  '192.168.51.1',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: '100.115.92.201',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Chromebook (Hatch / ARC Bridge)',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  '100.115.92.201',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'moddwarf.local',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Wi-Fi / mDNS',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  'moddwarf.local',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    : null,
              ),
              style: TextStyle(
                color: isDarkMode ? Colors.white : Colors.black,
                fontFamily: 'monospace',
                fontSize: 13,
              ),
              enabled: isDisconnected,
            ),
          ),
          const SizedBox(width: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isDisconnected
                  ? (isDarkMode
                        ? const Color(0xFF00FFCC)
                        : const Color(0xFF00B3FF))
                  : const Color(0xFFFF007F),
              foregroundColor: isDisconnected ? Colors.black : Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 4,
              shadowColor:
                  (isDisconnected
                          ? (isDarkMode
                                ? const Color(0xFF00FFCC)
                                : const Color(0xFF00B3FF))
                          : const Color(0xFFFF007F))
                      .withOpacity(0.5),
            ),
            onPressed: onConnectDisconnect,
            child: Text(
              isDisconnected ? 'CONNECT' : 'DISCONNECT',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
            ),
          ),
          const SizedBox(width: 8),
          const SizedBox(width: 4),
          IconButton(
            icon: Icon(
              Icons.open_in_browser,
              color: isDarkMode
                  ? const Color(0xFFFF7700)
                  : const Color(0xFFFF5500),
              size: 20,
            ),
            tooltip: 'Open in Chrome / Browser',
            onPressed: onOpenBrowser,
          ),
        ],
      ),
    );
  }
}
