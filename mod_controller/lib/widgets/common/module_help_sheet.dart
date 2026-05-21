// Copyright (c) 2026 TamperMod Contributors
// Licensed under the MIT License

import 'package:flutter/material.dart';
import '../../models/module_help_data.dart';

/// Module help sheet widget
class ModuleHelpSheet {
  static void show(BuildContext context, String moduleKey, bool isDarkMode) {
    final help = ModuleHelpData.registry[moduleKey];
    if (help == null) return;

    final primaryThemeColor = isDarkMode
        ? const Color(0xFF00FFCC)
        : const Color(0xFF00B3FF);
    final accentThemeColor = const Color(0xFFFF007F);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xFF0F141C) : Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
                border: Border.all(
                  color: primaryThemeColor.withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      color: isDarkMode ? Colors.grey[800] : Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [primaryThemeColor, accentThemeColor],
                            ),
                          ),
                          child: Icon(help.icon, color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                help.title.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.0,
                                  color: isDarkMode
                                      ? Colors.white
                                      : Colors.black,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'TamperMod Companion Documentation',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isDarkMode
                                      ? Colors.grey[500]
                                      : Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.close,
                            color: isDarkMode
                                ? Colors.grey[500]
                                : Colors.grey[750],
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Divider(
                    color: isDarkMode ? Colors.grey[900] : Colors.grey[300],
                  ),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      children: [
                        _buildHelpSectionHeader(
                          'Overview',
                          Icons.info_outline,
                          primaryThemeColor,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          help.overview,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.5,
                            color: isDarkMode
                                ? Colors.grey[300]
                                : Colors.grey[800],
                          ),
                        ),
                        const SizedBox(height: 20),
                        _buildHelpSectionHeader(
                          'Parameters',
                          Icons.settings,
                          primaryThemeColor,
                        ),
                        const SizedBox(height: 8),
                        ...help.parameters.map((param) {
                          final parts = param.split(':');
                          final label = parts[0];
                          final desc = parts.length > 1
                              ? parts.sublist(1).join(':')
                              : '';
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(
                                    top: 6,
                                    right: 12,
                                  ),
                                  child: Icon(
                                    Icons.radio_button_checked,
                                    size: 8,
                                    color: primaryThemeColor,
                                  ),
                                ),
                                Expanded(
                                  child: RichText(
                                    text: TextSpan(
                                      style: TextStyle(
                                        fontSize: 13,
                                        height: 1.4,
                                        color: isDarkMode
                                            ? Colors.grey[300]
                                            : Colors.grey[800],
                                      ),
                                      children: [
                                        TextSpan(
                                          text: '$label:',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        TextSpan(text: desc),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        const SizedBox(height: 20),
                        _buildHelpSectionHeader(
                          'Keyboard Hotkeys',
                          Icons.keyboard,
                          primaryThemeColor,
                        ),
                        const SizedBox(height: 8),
                        ...help.hotkeys.map((hotkey) {
                          final parts = hotkey.split(':');
                          final label = parts[0];
                          final desc = parts.length > 1
                              ? parts.sublist(1).join(':')
                              : '';
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isDarkMode
                                        ? Colors.black
                                        : Colors.grey[200],
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: isDarkMode
                                          ? Colors.grey[800]!
                                          : Colors.grey[400]!,
                                    ),
                                  ),
                                  child: Text(
                                    label,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontFamily: 'monospace',
                                      fontWeight: FontWeight.bold,
                                      color: primaryThemeColor,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    desc,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: isDarkMode
                                          ? Colors.grey[300]
                                          : Colors.grey[800],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        const SizedBox(height: 20),
                        _buildHelpSectionHeader(
                          'Mod Dwarf Under-The-Hood',
                          Icons.settings_ethernet,
                          primaryThemeColor,
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDarkMode
                                ? Colors.black.withOpacity(0.3)
                                : Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isDarkMode
                                  ? Colors.grey[900]!
                                  : Colors.grey[300]!,
                            ),
                          ),
                          child: Text(
                            help.underTheHood,
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.5,
                              fontFamily: 'monospace',
                              color: isDarkMode
                                  ? Colors.grey[400]
                                  : Colors.grey[750],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  static Widget _buildHelpSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Text(
          title.toUpperCase(),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.8,
            color: color,
          ),
        ),
      ],
    );
  }
}
