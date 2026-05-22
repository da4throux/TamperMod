// Copyright (c) 2026 TamperMod Contributors
// Licensed under the MIT License

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';

import '../services/websocket_service.dart';
import '../models/plugin_instance.dart';
import '../services/looper_controller.dart';
import '../utils/curves.dart';
import '../widgets/toolbars/bpm_controller.dart';
import '../widgets/toolbars/bottom_toolbar.dart';
import '../widgets/toolbars/connection_panel.dart';
import '../widgets/drawers/metrics_drawer.dart';
import '../widgets/drawers/settings_drawer.dart';
import '../widgets/cards/gain_card.dart';
import '../widgets/cards/switch_card.dart';
import '../widgets/cards/looper_card.dart';
import '../widgets/cards/looper_regular_card.dart';
import '../widgets/cards/placeholder_card.dart';
import '../utils/color_utils.dart';

class DashboardScreen extends StatefulWidget {
  final String appVersion;
  const DashboardScreen({super.key, required this.appVersion});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  final ModWebSocketService _webSocketService = ModWebSocketService();
  late final LooperController _looperController;
  final TextEditingController _ipController = TextEditingController(
    text: '192.168.51.1',
  );
  late final WebViewController _webViewController;

  bool _showControls = true;
  bool _showWeb = true;
  bool _isDarkMode = true;
  List<String> _orderedPluginInstances = [];

  // Track volume slider values locally to make the slider extremely responsive
  final Map<String, double> _localVolumes = {};
  final Map<String, double> _mutedVolumes = {};

  // Fade range cursors: fractional [0.0–1.0] position within min..max gain range
  final Map<String, double> _fadeRangeStart = {};
  final Map<String, double> _fadeRangeEnd = {};

  // Per-pedal fade shape: 'linear' | 'easeInOut' | 'easeIn' | 'easeOut' | 'custom'
  final Map<String, String> _fadeShapes = {};

  // Per-pedal custom S-curve params: cx, cy, slope
  final Map<String, Map<String, double>> _fadeCustomParams = {};

  // Live fade progress [0.0–1.0] — transient, not persisted
  final Map<String, double> _fadeProgress = {};

  // Custom User Ordering and Visibility List
  List<String> _enabledPluginInstances = [];

  final ScrollController _cardsScrollController = ScrollController();
  final Map<String, String> _pedalGlowColors = {};
  final Map<String, bool> _pedalGlowEnabled = {};
  final Map<String, String> _pedalSizes = {};

  Color _hexToColor(String hex) => hexToColor(hex);

  void _updateAllGlowsInWebView() {
    // Safety check: ensure we're mounted and looper controller is initialized
    if (!mounted) return;

    final List<Map<String, dynamic>> configs = [];
    for (final instanceId in _enabledPluginInstances) {
      final bool isEnabled = _pedalGlowEnabled[instanceId] ?? true;
      String colorHex = _pedalGlowColors[instanceId] ?? '';
      if (colorHex.isEmpty) {
        colorHex = _getDefaultColorForInstanceId(instanceId);
      }
      configs.add({
        'instance': instanceId,
        'enabled': isEnabled,
        'color': colorHex,
      });
    }

    // Also include active ALO Looper if discovered and selected
    // Add null safety check for looper controller
    try {
      if (_looperController.activeLooper != null) {
        final String looperId = _looperController.activeLooper!.instance;
        final bool isEnabled = _pedalGlowEnabled[looperId] ?? true;
        String colorHex = _pedalGlowColors[looperId] ?? '';
        if (colorHex.isEmpty) {
          colorHex = '#FF0055'; // Vibrant, iconic looper red by default
        }
        configs.add({
          'instance': looperId,
          'enabled': isEnabled,
          'color': colorHex,
        });
      }
    } catch (e) {
      debugPrint('Error accessing looper controller: $e');
    }

    final String jsCode =
        '''
      (function() {
        const configs = ${jsonEncode(configs)};
        console.log("TamperMod: Updating permanent glows", configs);
        
        // Remove all previous glows
        const existing = document.querySelectorAll(".tamper-highlight, .tamper-permanent-glow");
        existing.forEach(e => {
          e.style.outline = "";
          e.style.boxShadow = "";
          e.style.backgroundColor = "";
          e.classList.remove("tamper-highlight");
          e.classList.remove("tamper-permanent-glow");
        });
        
        // Clean any diagnostic panel overlay if present
        let diag = document.getElementById("tamper-debug");
        if (diag) diag.remove();

        configs.forEach(c => {
          if (!c.enabled) return;
          
          let el = document.querySelector('[mod-instance="' + c.instance + '"]');
          if (!el) {
            const cleanName = c.instance.split("/").pop();
            el = document.querySelector('[mod-instance*="' + cleanName + '"]');
          }
          
          if (el) {
            el.classList.add("tamper-permanent-glow");
            el.setAttribute("data-glow-color", c.color);
            
            // Apply permanent glow with massive visual propagation (neon cloud expands far out!)
            el.style.transition = "outline 0.3s ease, box-shadow 0.3s ease, background-color 0.3s ease";
            el.style.outline = "3px solid " + c.color;
            el.style.outlineOffset = "2px";
            el.style.boxShadow = "0 0 20px 8px " + c.color + ", 0 0 180px 4px " + c.color + ", inset 0 0 15px " + c.color;
            el.style.backgroundColor = hexToRgba(c.color, 0.08);
          }
        });
        
        function hexToRgba(hex, alpha) {
          let c = hex.substring(1);
          if (c.length === 3) c = c[0] + c[0] + c[1] + c[1] + c[2] + c[2];
          const r = parseInt(c.substring(0, 2), 16);
          const g = parseInt(c.substring(2, 4), 16);
          const b = parseInt(c.substring(4, 6), 16);
          return "rgba(" + r + ", " + g + ", " + b + ", " + alpha + ")";
        }
      })();
    ''';

    try {
      _webViewController.runJavaScript(jsCode);
    } catch (e) {
      debugPrint('Error updating all glows: $e');
    }
  }

  void _injectBpmMonitor() {
    const String jsCode = r'''
      (function() {
        function getBpmValue() {
          const selectors = [
            '.bpm', '.tempo', '#bpm', '.bpm-value', '.tempo-value',
            '.status-bar-bpm', '.footer-bpm', '.status-bpm',
            'span[data-bind*="bpm"]', 'div[data-bind*="bpm"]'
          ];
          for (let selector of selectors) {
            const el = document.querySelector(selector);
            if (el && el.textContent) {
              const txt = el.textContent.trim();
              const match = txt.match(/\b([0-9]{2,3}(?:\.[0-9]+)?)\b/);
              if (match) {
                return parseFloat(match[1]);
              }
            }
          }

          const all = document.getElementsByTagName('*');
          for (let i = 0; i < all.length; i++) {
            const el = all[i];
            if (el.children.length === 0 && el.textContent) {
              const txt = el.textContent.trim();
              const match = txt.match(/\b([0-9]{2,3}(?:\.[0-9]+)?)\s*BPM\b/i);
              if (match) {
                return parseFloat(match[1]);
              }
            }
          }
          
          for (let i = 0; i < all.length; i++) {
            const el = all[i];
            if (el.textContent) {
              const txt = el.textContent.trim();
              const match = txt.match(/\b([0-9]{2,3}(?:\.[0-9]+)?)\s*BPM\b/i);
              if (match) {
                return parseFloat(match[1]);
              }
            }
          }
          return null;
        }

        let lastBpm = null;
        if (window.bpmIntervalId) {
          clearInterval(window.bpmIntervalId);
        }
        window.bpmIntervalId = setInterval(function() {
          try {
            const bpm = getBpmValue();
            if (bpm && bpm !== lastBpm) {
              lastBpm = bpm;
              if (window.BpmChannel) {
                window.BpmChannel.postMessage(bpm.toString());
              }
            }
          } catch(e) {}
        }, 1000);
      })();
    ''';

    try {
      _webViewController.runJavaScript(jsCode);
    } catch (e) {
      debugPrint('Error injecting BPM monitor: $e');
    }
  }


  // Fading and BPM Parameter State
  double _bpm = 120.0;
  int _fadeBars =
      8; // Default fade speed period in bars (configurable: 1, 2, 4, 8, 16)

  String _activeConfig = 'default';
  List<String> _configsList = ['default'];

  final Map<String, double> _preFadeVolumes = {};
  final Map<String, Timer?> _fadeTimers = {};
  final Map<String, bool> _fadeDirections =
      {}; // true for Fade In, false for Fade Out

  // Tap-tempo times keeper
  final List<DateTime> _tapTimes = [];

  // User custom display titles for plugin cards (renaming support)
  final Map<String, String> _customTitles = {};

  bool _isMuted(PluginInstance pedal) {
    final double currentValue =
        _localVolumes[pedal.instance] ??
        (pedal.gainPortSymbol != null
            ? pedal.parameters[pedal.gainPortSymbol]
            : null) ??
        0.0;
    return currentValue == pedal.minGain;
  }

  void _toggleMute(PluginInstance pedal) {
    final String instanceId = pedal.instance;
    final double currentValue =
        _localVolumes[instanceId] ??
        (pedal.gainPortSymbol != null
            ? pedal.parameters[pedal.gainPortSymbol]
            : null) ??
        0.0;
    final double minRange = pedal.minGain;

    if (currentValue == minRange) {
      // It is currently muted. Unmute it.
      final double restoredValue = _mutedVolumes[instanceId] ?? 0.0;
      _mutedVolumes.remove(instanceId);
      setState(() {
        _localVolumes[instanceId] = restoredValue;
      });
      if (pedal.gainPortSymbol != null) {
        _webSocketService.setParamValue(
          instance: instanceId,
          port: pedal.gainPortSymbol!,
          value: double.parse(restoredValue.toStringAsFixed(2)),
        );
      }
    } else {
      // Mute it. Save current value.
      _mutedVolumes[instanceId] = currentValue;
      setState(() {
        _localVolumes[instanceId] = minRange;
      });
      if (pedal.gainPortSymbol != null) {
        _webSocketService.setParamValue(
          instance: instanceId,
          port: pedal.gainPortSymbol!,
          value: minRange,
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _looperController = LooperController(webSocketService: _webSocketService);
    WidgetsBinding.instance.addObserver(this);

    // Initialize WebViewController
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF0B0E14))
      ..addJavaScriptChannel(
        'BpmChannel',
        onMessageReceived: (JavaScriptMessage message) {
          final double? parsedBpm = double.tryParse(message.message);
          if (parsedBpm != null) {
            debugPrint('SCRAPED BPM FROM WEBVIEW DOM: $parsedBpm');
            _webSocketService.bpm.value = parsedBpm;
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            // Apply all permanent glows automatically when the page is finished loading!
            _updateAllGlowsInWebView();
            // Inject BPM monitor script
            _injectBpmMonitor();
          },
        ),
      );

    // Load initial URL
    _webViewController.loadRequest(Uri.parse('http://${_ipController.text}'));

    // Load saved theme settings
    _loadThemeSettings();

    // Connect automatically on launch
    _webSocketService.connect(ip: _ipController.text);

    // Listen to value changes to update local volume values and BPM initially
    _webSocketService.gainPedals.addListener(_initializeLocalVolumes);
    _webSocketService.bpm.addListener(_updateBpmFromService);
    _webSocketService.allPlugins.addListener(_syncOrderedPlugins);
  }

  void _initializeLocalVolumes() {
    final gains = _webSocketService.gainPedals.value;
    for (var pedal in gains) {
      if (pedal.gainPortSymbol != null) {
        final double? serverValue = pedal.parameters[pedal.gainPortSymbol];
        if (serverValue != null && !_localVolumes.containsKey(pedal.instance)) {
          _localVolumes[pedal.instance] = serverValue;
        }
      }
    }

    // Auto-populate custom control workspace by default with gains
    if (_enabledPluginInstances.isEmpty && gains.isNotEmpty) {
      _enabledPluginInstances = gains.map((p) => p.instance).toList();
      _updateAllGlowsInWebView();
    }

    setState(() {});
  }

  void _updateBpmFromService() {
    if (mounted) {
      setState(() {
        _bpm = _webSocketService.bpm.value;
      });
    }
  }

  void _syncOrderedPlugins() {
    _syncAndLoadLayoutSettings();
  }

  Future<void> _syncAndLoadLayoutSettings() async {
    final plugins = _webSocketService.allPlugins.value;
    if (plugins.isEmpty) return;

    final baseKey = _getPedalboardBaseKey();
    final List<String> currentIds = plugins.map((p) => p.instance).toList();

    try {
      final prefs = await SharedPreferences.getInstance();
      final String activeConfig = prefs.getString('${baseKey}_active_config') ?? 'default';
      final List<String> configsList = prefs.getStringList('${baseKey}_configs_list') ?? ['default'];

      _activeConfig = activeConfig;
      if (!configsList.contains(_activeConfig)) {
        _activeConfig = 'default';
      }
      _configsList = configsList;
      if (!_configsList.contains('default')) {
        _configsList.insert(0, 'default');
      }

      final key = _getPedalboardKey();
      final List<String>? savedOrder = prefs.getStringList('${key}_order');
      final List<String>? savedEnabled = prefs.getStringList('${key}_enabled');
      final String? savedColorsJson = prefs.getString('${key}_colors');
      final String? savedSizesJson = prefs.getString('${key}_sizes');
      final String? savedTitlesJson = prefs.getString('${key}_custom_titles');
      final String? savedGlowEnabledJson = prefs.getString('${key}_glow_enabled');
      final int? savedFadeBars = prefs.getInt('${key}_fade_bars');

      // 1. Order
      List<String> newOrder = [];
      if (savedOrder != null) {
        for (final id in savedOrder) {
          if (currentIds.contains(id)) {
            newOrder.add(id);
          }
        }
      } else {
        // Default order: non-loopers first, then loopers
        final nonLoopers = plugins
            .where((p) {
              final uriLower = p.uri.toLowerCase();
              final titleLower = p.title.toLowerCase();
              return !(uriLower.contains('alo') || titleLower.contains('alo'));
            })
            .map((p) => p.instance)
            .toList();

        final loopers = plugins
            .where((p) {
              final uriLower = p.uri.toLowerCase();
              final titleLower = p.title.toLowerCase();
              return uriLower.contains('alo') || titleLower.contains('alo');
            })
            .map((p) => p.instance)
            .toList();

        newOrder.addAll(nonLoopers);
        newOrder.addAll(loopers);
      }
      for (final id in currentIds) {
        if (!newOrder.contains(id)) {
          newOrder.add(id);
        }
      }

      // 2. Enabled/Visible
      List<String> newEnabled = [];
      if (savedEnabled != null) {
        newEnabled = savedEnabled
            .where((id) => currentIds.contains(id))
            .toList();
      } else {
        // default populate with gains
        final gains = _webSocketService.gainPedals.value;
        newEnabled = gains.map((p) => p.instance).toList();
      }

      // Force loopers to be enabled/visible
      for (final p in plugins) {
        final uriLower = p.uri.toLowerCase();
        final titleLower = p.title.toLowerCase();
        final isLooper = uriLower.contains('alo') || titleLower.contains('alo');
        if (isLooper && !newEnabled.contains(p.instance)) {
          newEnabled.add(p.instance);
        }
      }

      // Sort newEnabled according to newOrder to keep ordering synchronized
      newEnabled.sort(
        (a, b) => newOrder.indexOf(a).compareTo(newOrder.indexOf(b)),
      );

      // 3. Colors
      final Map<String, String> newColors = {};
      if (savedColorsJson != null) {
        final Map<String, dynamic> decoded = jsonDecode(savedColorsJson);
        decoded.forEach((k, v) {
          newColors[k] = v.toString();
        });
      }
      // Populate defaults if any plugin doesn't have a color assigned yet
      for (final p in plugins) {
        if (!newColors.containsKey(p.instance)) {
          newColors[p.instance] = getLeastUsedColor(newColors);
        }
      }

      // 4. Sizes
      final Map<String, String> newSizes = {};
      if (savedSizesJson != null) {
        final Map<String, dynamic> decoded = jsonDecode(savedSizesJson);
        decoded.forEach((k, v) {
          newSizes[k] = v.toString();
        });
      }
      for (final p in plugins) {
        if (!newSizes.containsKey(p.instance)) {
          final uriLower = p.uri.toLowerCase();
          final titleLower = p.title.toLowerCase();
          final isLooper =
              uriLower.contains('alo') || titleLower.contains('alo');
          newSizes[p.instance] = isLooper ? 'expanded' : 'regular';
        }
      }

      // 5. Custom Titles
      final Map<String, String> newCustomTitles = {};
      if (savedTitlesJson != null) {
        final Map<String, dynamic> decoded = jsonDecode(savedTitlesJson);
        decoded.forEach((k, v) {
          newCustomTitles[k] = v.toString();
        });
      }

      // 6. Glow Enabled
      final Map<String, bool> newGlowEnabled = {};
      if (savedGlowEnabledJson != null) {
        final Map<String, dynamic> decoded = jsonDecode(savedGlowEnabledJson);
        decoded.forEach((k, v) {
          newGlowEnabled[k] = v as bool;
        });
      }

      // 7. Fade range cursors
      final String? savedFadeStart = prefs.getString('${key}_fadeRangeStart');
      final String? savedFadeEnd = prefs.getString('${key}_fadeRangeEnd');
      final String? savedFadeShapes = prefs.getString('${key}_fadeShapes');
      final String? savedFadeCustom = prefs.getString(
        '${key}_fadeCustomParams',
      );
      final Map<String, double> newFadeStart = {};
      final Map<String, double> newFadeEnd = {};
      final Map<String, String> newFadeShapes = {};
      final Map<String, Map<String, double>> newFadeCustomParams = {};

      if (savedFadeStart != null) {
        final Map<String, dynamic> dec = jsonDecode(savedFadeStart);
        dec.forEach((k, v) => newFadeStart[k] = (v as num).toDouble());
      }
      if (savedFadeEnd != null) {
        final Map<String, dynamic> dec = jsonDecode(savedFadeEnd);
        dec.forEach((k, v) => newFadeEnd[k] = (v as num).toDouble());
      }
      if (savedFadeShapes != null) {
        final Map<String, dynamic> dec = jsonDecode(savedFadeShapes);
        dec.forEach((k, v) => newFadeShapes[k] = v.toString());
      }
      if (savedFadeCustom != null) {
        final Map<String, dynamic> outer = jsonDecode(savedFadeCustom);
        outer.forEach((k, v) {
          final Map<String, dynamic> inner = jsonDecode(v.toString());
          newFadeCustomParams[k] = inner.map(
            (ik, iv) => MapEntry(ik, (iv as num).toDouble()),
          );
        });
      }

      if (mounted) {
        setState(() {
          _orderedPluginInstances = newOrder;
          _enabledPluginInstances = newEnabled;
          
          _pedalSizes.clear();
          _pedalSizes.addAll(newSizes);

          _pedalGlowColors.clear();
          _pedalGlowColors.addAll(newColors);

          _customTitles.clear();
          _customTitles.addAll(newCustomTitles);

          _pedalGlowEnabled.clear();
          _pedalGlowEnabled.addAll(newGlowEnabled);

          _fadeRangeStart.clear();
          _fadeRangeStart.addAll(newFadeStart);
          _fadeRangeEnd.clear();
          _fadeRangeEnd.addAll(newFadeEnd);
          _fadeShapes.clear();
          _fadeShapes.addAll(newFadeShapes);
          _fadeCustomParams.clear();
          _fadeCustomParams.addAll(newFadeCustomParams);

          if (savedFadeBars != null) {
            _fadeBars = savedFadeBars;
          }
        });
        _updateAllGlowsInWebView();
      }
    } catch (e) {
      debugPrint('Error loading layout settings: $e');
    }
  }

  void _onTapTempo() {
    final now = DateTime.now();
    _tapTimes.add(now);

    // Keep only the last 5 taps for a running average
    if (_tapTimes.length > 5) {
      _tapTimes.removeAt(0);
    }

    if (_tapTimes.length >= 2) {
      double totalMs = 0;
      for (int i = 1; i < _tapTimes.length; i++) {
        totalMs += _tapTimes[i].difference(_tapTimes[i - 1]).inMilliseconds;
      }
      final double avgMs = totalMs / (_tapTimes.length - 1);
      if (avgMs > 200 && avgMs < 2000) {
        // Limit to 30 to 300 BPM
        final double calculatedBpm = 60000 / avgMs;
        _webSocketService.setBpm(
          double.parse(calculatedBpm.toStringAsFixed(1)),
        );
      }
    }
  }

  Future<void> _setTransportSyncMode(int mode) async {
    final ip = _ipController.text;
    if (ip.isEmpty) return;

    String modeStr = 'none';
    if (mode == 1) {
      modeStr = 'midi';
    } else if (mode == 2) {
      modeStr = 'link';
    }

    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 2);
      final request = await client.postUrl(
        Uri.parse('http://$ip/pedalboard/transport/sync/$modeStr'),
      );
      final response = await request.close();
      debugPrint('Sync Mode POST ($modeStr) response: ${response.statusCode}');

      // Update local state optimistically
      _webSocketService.transportSyncMode.value = mode;
    } catch (e) {
      debugPrint('Error setting sync mode: $e');
      // Fallback: send raw message
      _webSocketService.sendRawMessage('transport-sync-mode $mode');
    }
  }

  Future<void> _openPluginUri(String url) async {
    if (url.isEmpty) return;
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not open URL: $e')));
      }
    }
  }

  void _showBpmDialog() {
    double currentBpm = _bpm;
    final controller = TextEditingController(text: currentBpm.toStringAsFixed(1));
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: _isDarkMode ? const Color(0xFF0F141C) : Colors.white,
          title: Text(
            'SET HOST TEMPO',
            style: TextStyle(
              color: _isDarkMode
                  ? const Color(0xFF00FFCC)
                  : const Color(0xFF00B3FF),
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
              fontSize: 16,
            ),
          ),
          content: StatefulBuilder(
            builder: (context, setState) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Tempo (BPM)',
                        labelStyle: TextStyle(
                          color: _isDarkMode ? Colors.grey : Colors.grey[700],
                        ),
                        enabledBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(
                            color: _isDarkMode
                                ? const Color(0xFF00FFCC)
                                : const Color(0xFF00B3FF),
                          ),
                        ),
                      ),
                      style: TextStyle(
                        color: _isDarkMode ? Colors.white : Colors.black,
                        fontFamily: 'monospace',
                        fontSize: 16,
                      ),
                      onChanged: (text) {
                        final double? parsed = double.tryParse(text);
                        if (parsed != null) {
                          setState(() {
                            currentBpm = parsed.clamp(20.0, 280.0);
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 24),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      BpmKnob(
                        bpm: currentBpm,
                        minBpm: 20.0,
                        maxBpm: 280.0,
                        isDarkMode: _isDarkMode,
                        onChanged: (newVal) {
                          setState(() {
                            currentBpm = newVal.clamp(20.0, 280.0);
                            final newText = currentBpm.toStringAsFixed(1);
                            controller.value = TextEditingValue(
                              text: newText,
                              selection: TextSelection.collapsed(offset: newText.length),
                            );
                          });
                        },
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'KNOB',
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          color: _isDarkMode ? Colors.grey[600] : Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'CANCEL',
                style: TextStyle(
                  color: _isDarkMode ? Colors.grey : Colors.grey[600],
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _isDarkMode
                    ? const Color(0xFF00FFCC)
                    : const Color(0xFF00B3FF),
                foregroundColor: _isDarkMode ? Colors.black : Colors.white,
              ),
              onPressed: () {
                double finalBpm = double.tryParse(controller.text) ?? currentBpm;
                finalBpm = finalBpm.clamp(20.0, 280.0);
                _webSocketService.setBpm(double.parse(finalBpm.toStringAsFixed(1)));
                Navigator.pop(context);
              },
              child: const Text(
                'SET',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  void _triggerFade(PluginInstance pedal, {required bool fadeIn}) {
    if (pedal.gainPortSymbol == null) return;

    final double currentValue =
        _localVolumes[pedal.instance] ??
        pedal.parameters[pedal.gainPortSymbol] ??
        0.0;

    final double minRange = pedal.minGain;
    final double maxRange = pedal.maxGain;

    // Read fade range cursors (fractional 0.0–1.0)
    final double rangeStartFrac = _fadeRangeStart[pedal.instance] ?? 0.0;
    final double rangeEndFrac = _fadeRangeEnd[pedal.instance] ?? 1.0;

    // Convert fractional range to actual dB values
    final double fadeMin = minRange + rangeStartFrac * (maxRange - minRange);
    final double fadeMax = minRange + rangeEndFrac * (maxRange - minRange);

    final double startVal = currentValue.clamp(minRange, maxRange);

    double targetEndValue;
    if (fadeIn) {
      targetEndValue = _preFadeVolumes[pedal.instance] ?? fadeMax;
      targetEndValue = targetEndValue.clamp(fadeMin, fadeMax);
    } else {
      // Save current pre-fade volume if it's above floor
      if (startVal > fadeMin + 1.0) {
        _preFadeVolumes[pedal.instance] = startVal;
      }
      targetEndValue = fadeMin;
    }

    // Resolve the curve to use
    final String shapeName = _fadeShapes[pedal.instance] ?? 'easeInOut';
    final Curve selectedCurve;
    switch (shapeName) {
      case 'linear':
        selectedCurve = Curves.linear;
        break;
      case 'easeIn':
        selectedCurve = Curves.easeIn;
        break;
      case 'easeOut':
        selectedCurve = Curves.easeOut;
        break;
      case 'custom':
        final params = _fadeCustomParams[pedal.instance] ?? {};
        selectedCurve = CustomSCurve(
          cx: params['cx'] ?? 0.5,
          cy: params['cy'] ?? 0.5,
          slope: params['slope'] ?? 1.0,
        );
        break;
      default:
        selectedCurve = Curves.easeInOut;
    }

    // Duration in seconds: (60 / BPM) * 4 beats per bar * bars count
    final double duration = (60 / _bpm) * 4 * _fadeBars;
    final int totalSteps = (duration / 0.05).round();

    if (totalSteps <= 0) return;

    int currentStep = 0;

    // Stop any existing fade timer
    _fadeTimers[pedal.instance]?.cancel();

    setState(() {
      _fadeDirections[pedal.instance] = fadeIn;
      _fadeProgress[pedal.instance] = 0.0;
    });

    _fadeTimers[pedal.instance] = Timer.periodic(
      const Duration(milliseconds: 50),
      (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }

        currentStep++;
        if (currentStep >= totalSteps) {
          setState(() {
            _localVolumes[pedal.instance] = targetEndValue;
            _fadeTimers[pedal.instance] = null;
            _fadeProgress[pedal.instance] = 0.0;
          });
          _webSocketService.setParamValue(
            instance: pedal.instance,
            port: pedal.gainPortSymbol!,
            value: double.parse(targetEndValue.toStringAsFixed(2)),
          );
          timer.cancel();
        } else {
          final double progress = currentStep / totalSteps;
          final double curvedProgress = selectedCurve.transform(progress);
          final double intermediateVal =
              startVal + (targetEndValue - startVal) * curvedProgress;

          setState(() {
            _localVolumes[pedal.instance] = intermediateVal;
            _fadeProgress[pedal.instance] = progress;
          });
          _webSocketService.setParamValue(
            instance: pedal.instance,
            port: pedal.gainPortSymbol!,
            value: double.parse(intermediateVal.toStringAsFixed(2)),
          );
        }
      },
    );
  }

  /// Checks for active WiFi before connecting.
  ///
  /// WiFi prevents the system from routing traffic to the USB Ethernet
  /// interface used to reach the MOD Dwarf (192.168.51.x). If WiFi is
  /// detected as the active connection type, a warning is shown before
  /// proceeding. The user should disable WiFi and reconnect.
  Future<void> _connectWithWifiCheck() async {
    final List<ConnectivityResult> results = await Connectivity()
        .checkConnectivity();
    final bool wifiActive = results.contains(ConnectivityResult.wifi);

    if (wifiActive && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 10),
          backgroundColor: const Color(0xFFCC6600),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: Color(0xFFFF9900), width: 1.5),
          ),
          content: const Row(
            children: [
              Icon(Icons.wifi_off, color: Colors.white, size: 22),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  '⚠️ WiFi is ON — the MOD Dwarf connects via USB Ethernet. '
                  'WiFi blocks the route. Turn off WiFi, then reconnect.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          action: SnackBarAction(
            label: 'SETTINGS',
            textColor: Colors.white,
            onPressed: () {
              // Open WiFi settings
              _openWiFiSettings();
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
            },
          ),
        ),
      );
    }

    // Proceed with connection regardless — user may have WiFi on for other
    // reasons and still wants to try (e.g. WiFi on but already disabled
    // for routing before this check ran).
    _webSocketService.connect(ip: _ipController.text);
    _webViewController.loadRequest(Uri.parse('http://${_ipController.text}'));
  }

  /// Opens WiFi settings on Android
  Future<void> _openWiFiSettings() async {
    try {
      if (Platform.isAndroid) {
        await const MethodChannel(
          'com.example.mod_controller/wifi',
        ).invokeMethod('openWiFiSettings');
      }
    } catch (e) {
      debugPrint('Error opening WiFi settings: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      debugPrint(
        'App returned from background: automatically restoring remote connection...',
      );
      if (_webSocketService.status == ConnectionStatus.disconnected) {
        _webSocketService.connect(ip: _ipController.text);
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _webSocketService.gainPedals.removeListener(_initializeLocalVolumes);
    _webSocketService.bpm.removeListener(_updateBpmFromService);
    _webSocketService.allPlugins.removeListener(_syncOrderedPlugins);
    _cardsScrollController.dispose();

    // Cancel all running fade timers
    for (var timer in _fadeTimers.values) {
      timer?.cancel();
    }

    _looperController.dispose();
    _webSocketService.dispose();
    _ipController.dispose();
    super.dispose();
  }

  Future<void> _openWebInterface() async {
    final ip = _ipController.text;
    if (ip.isEmpty) return;

    final uri = Uri.parse('http://$ip');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not launch http://$ip: $e')),
          );
        }
      }
    }
  }

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

  String _getStatusText(ConnectionStatus status) {
    switch (status) {
      case ConnectionStatus.connected:
        return 'CONNECTED';
      case ConnectionStatus.connecting:
        return 'CONNECTING...';
      case ConnectionStatus.disconnected:
        return 'DISCONNECTED';
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _webSocketService,
      builder: (context, _) {
        final screenWidth = MediaQuery.of(context).size.width;
        final orientation = MediaQuery.of(context).orientation;
        final isLandscape = orientation == Orientation.landscape;

        return Scaffold(
          onEndDrawerChanged: (isOpen) {
            setState(() {});
          },
          // Right-aligned settings drawer (puzzle organizer), occupying the full vertical height
          endDrawer: Drawer(
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: SettingsDrawer(
              isDarkMode: _isDarkMode,
              allPluginsNotifier: _webSocketService.allPlugins,
              enabledPluginInstances: _enabledPluginInstances,
              orderedPluginInstances: _orderedPluginInstances,
              pedalSizes: _pedalSizes,
              pedalGlowColors: _pedalGlowColors,
              customTitles: _customTitles,
              currentConfig: _activeConfig,
              configsList: _configsList,
              onConfigChanged: _switchConfig,
              onConfigDuplicate: _duplicateCurrentConfig,
              onConfigRename: _renameCurrentConfig,
              onConfigDelete: _deleteCurrentConfig,
              onLayoutSettingsChanged: () {
                _updateAllGlowsInWebView();
                _saveLayoutSettings();
              },
              onHighlightPedal: _highlightPedalInWebView,
              onShowColorPicker: _showColorPickerDialog,
              onCyclePedalSize: _cyclePedalSize,
              onScrollToCard: _scrollToCard,
              onBackupRestore: _showBackupRestoreDialog,
            ),
          ),

          // Continuous Left-aligned navigation and metrics drawer
          drawer: Drawer(
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  right: BorderSide(
                    color: _isDarkMode
                        ? const Color(0xFF00FFCC)
                        : const Color(0xFF00B3FF),
                    width: 1.5,
                  ),
                ),
              ),
              child: MetricsDrawer(
                isDarkMode: _isDarkMode,
                bpm: _bpm,
                activeCount: _enabledPluginInstances.length,
                totalCount: _webSocketService.allPlugins.value.length,
                connectionStatus: _webSocketService.status,
                onRadarTap: _highlightAllPedalsInWebView,
                onRefreshTap: _reloadPedalboard,
                onOpenBrowser: _openWebInterface,
                onThemeToggle: () {
                  setState(() {
                    _isDarkMode = !_isDarkMode;
                  });
                  _saveThemeSettings();
                },
                appVersion: widget.appVersion,
              ),
            ),
          ),

          appBar: AppBar(
            backgroundColor: _isDarkMode
                ? const Color(0xFF0F141C)
                : const Color(0xFFE4E6EB),
            elevation: 8,
            leadingWidth: 52,
            leading: Builder(
              builder: (context) => GestureDetector(
                onTap: () {
                  Scaffold.of(context).openDrawer();
                },
                child: Padding(
                  padding: const EdgeInsets.only(
                    left: 14.0,
                    top: 10.0,
                    bottom: 10.0,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: _isDarkMode
                            ? [const Color(0xFF00FFCC), const Color(0xFFFF007F)]
                            : [
                                const Color(0xFF00B3FF),
                                const Color(0xFFFF0055),
                              ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color:
                              (_isDarkMode
                                      ? const Color(0xFF00FFCC)
                                      : const Color(0xFF00B3FF))
                                  .withOpacity(0.4),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(Icons.tune, size: 14, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
            titleSpacing: 12,
            title: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TAMPERMOD LIVE',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                        color: _isDarkMode ? Colors.white : Colors.black,
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _getStatusColor(_webSocketService.status),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _getStatusText(_webSocketService.status),
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: _isDarkMode
                                ? _getStatusColor(_webSocketService.status)
                                : _getStatusColor(
                                    _webSocketService.status,
                                  ).withOpacity(0.85),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              // Premium Integrated BPM & Fade Controller
              if (screenWidth > 580)
                BpmController(
                  bpm: _bpm,
                  fadeBars: _fadeBars,
                  isDarkMode: _isDarkMode,
                  onTapTempo: _onTapTempo,
                  onBpmTap: _showBpmDialog,
                  onBpmChanged: (val) {
                    _webSocketService.setBpm(val);
                  },
                  onFadeBarsChanged: (val) {
                    setState(() {
                      _fadeBars = val;
                    });
                    _saveLayoutSettings();
                  },
                  isTransportRolling: _webSocketService.isTransportRolling,
                  transportSyncMode: _webSocketService.transportSyncMode,
                  onTransportRollingChanged: (val) {
                    _webSocketService.setRolling(val);
                  },
                  onSyncModeChanged: (val) {
                    _setTransportSyncMode(val);
                  },
                ),
              const SizedBox(width: 8),

              // Open Settings Drawer
              Builder(
                builder: (context) {
                  final bool isOpen = Scaffold.of(context).isEndDrawerOpen;
                  return IconButton(
                    icon: Icon(
                      isOpen ? Icons.extension : Icons.extension_outlined,
                      color: const Color(0xFFFF007F),
                      size: 22,
                    ),
                    tooltip: 'Puzzle Organizer',
                    onPressed: () {
                      if (isOpen) {
                        Scaffold.of(context).closeEndDrawer();
                      } else {
                        Scaffold.of(context).openEndDrawer();
                      }
                    },
                  );
                },
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: _isDarkMode
                    ? [const Color(0xFF0F141C), const Color(0xFF05070A)]
                    : [const Color(0xFFF0F2F5), const Color(0xFFE4E6EB)],
              ),
            ),
            child: Column(
              children: [
                // Bottom toolbar (UI bar) sits above connection bar
                BottomToolbar(
                  isDarkMode: _isDarkMode,
                  showControls: _showControls,
                  showWeb: _showWeb,
                  isConnected:
                      _webSocketService.status == ConnectionStatus.connected,
                  onToggleControls: () {
                    if (_showControls && !_showWeb) return;
                    setState(() {
                      _showControls = !_showControls;
                    });
                  },
                  onToggleWeb: () {
                    if (_showWeb && !_showControls) return;
                    setState(() {
                      _showWeb = !_showWeb;
                    });
                  },
                  onControlsOnly: () {
                    setState(() {
                      _showControls = true;
                      _showWeb = false;
                    });
                  },
                  onWebOnly: () {
                    setState(() {
                      _showWeb = true;
                      _showControls = false;
                    });
                  },
                  onRadarTap: _highlightAllPedalsInWebView,
                  onRefreshTap: _reloadPedalboard,
                  onWebReload: () {
                    _webViewController.reload();
                  },
                  onThemeToggle: () {
                    setState(() {
                      _isDarkMode = !_isDarkMode;
                    });
                    _saveThemeSettings();
                  },
                  appVersion: widget.appVersion,
                ),

                // Inline Connection / IP bar
                ConnectionPanel(
                  isDarkMode: _isDarkMode,
                  ipController: _ipController,
                  connectionStatus: _webSocketService.status,
                  onConnectDisconnect: () {
                    final bool isDisconnected =
                        _webSocketService.status ==
                        ConnectionStatus.disconnected;
                    if (isDisconnected) {
                      _connectWithWifiCheck();
                    } else {
                      _webSocketService.disconnect();
                    }
                  },
                  onOpenBrowser: _openWebInterface,
                  getStatusColor: _getStatusColor,
                ),

                // BPM inline widget on tiny screens to avoid AppBar overcrowding
                if (screenWidth <= 580)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    child: BpmController(
                      bpm: _bpm,
                      fadeBars: _fadeBars,
                      isDarkMode: _isDarkMode,
                      onTapTempo: _onTapTempo,
                      onBpmTap: _showBpmDialog,
                      onBpmChanged: (val) {
                        _webSocketService.setBpm(val);
                      },
                      onFadeBarsChanged: (val) {
                        setState(() {
                          _fadeBars = val;
                        });
                        _saveLayoutSettings();
                      },
                      isTransportRolling: _webSocketService.isTransportRolling,
                      transportSyncMode: _webSocketService.transportSyncMode,
                      onTransportRollingChanged: (val) {
                        _webSocketService.setRolling(val);
                      },
                      onSyncModeChanged: (val) {
                        _setTransportSyncMode(val);
                      },
                    ),
                  ),

                // Responsive layout container
                Expanded(child: _buildBodyContent(isLandscape)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBodyContent(bool isLandscape) {
    if (!_showControls && !_showWeb) {
      return const Center(child: Text('Select a view mode above.'));
    }

    if (_showControls && _showWeb) {
      // Split Layout mode
      return isLandscape
          ? Row(
              children: [
                Expanded(flex: 5, child: _buildUnifiedControlsList()),
                Container(width: 1.5, color: Colors.grey[850]),
                Expanded(
                  flex: 6,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      bottomLeft: Radius.circular(12),
                    ),
                    child: _buildWebView(),
                  ),
                ),
              ],
            )
          : Column(
              children: [
                Expanded(flex: 5, child: _buildUnifiedControlsList()),
                Container(height: 1.5, color: Colors.grey[850]),
                Expanded(
                  flex: 6,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                    child: _buildWebView(),
                  ),
                ),
              ],
            );
    } else if (_showControls) {
      return _buildUnifiedControlsList();
    } else {
      return _buildWebView();
    }
  }

  Widget _buildUnifiedControlsList() {
    if (_webSocketService.status != ConnectionStatus.connected) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.link_off,
              size: 64,
              color: const Color(0xFFFF007F).withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            const Text(
              'Not connected to MOD Dwarf',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please verify IP and connection',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ValueListenableBuilder<List<PluginInstance>>(
      valueListenable: _webSocketService.allPlugins,
      builder: (context, plugins, _) {
        // Self-healing: if a new pedalboard is loaded, stale instances in _enabledPluginInstances should be reset
        if (_enabledPluginInstances.isNotEmpty && plugins.isNotEmpty) {
          final bool hasAnyActive = _enabledPluginInstances.any(
            (instanceId) => plugins.any((p) => p.instance == instanceId),
          );
          if (!hasAnyActive) {
            final newGains = plugins
                .where((p) {
                  final uriLower = p.uri.toLowerCase();
                  final titleLower = p.title.toLowerCase();
                  return uriLower.contains('gain') ||
                      uriLower.contains('volume') ||
                      uriLower.contains('amp') ||
                      titleLower.contains('gain') ||
                      titleLower.contains('volume');
                })
                .map((p) => p.instance)
                .toList();

            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  _enabledPluginInstances = newGains;
                });
                _updateAllGlowsInWebView();
              }
            });
          }
        }

        // Hydrate selected active controls list safely using master order
        final List<PluginInstance> enabledPlugins = [];
        for (final instanceId in _orderedPluginInstances) {
          if (_enabledPluginInstances.contains(instanceId)) {
            PluginInstance? found;
            for (final p in plugins) {
              if (p.instance == instanceId) {
                found = p;
                break;
              }
            }
            if (found != null) {
              enabledPlugins.add(found);
            }
          }
        }

        if (enabledPlugins.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.tune_outlined, size: 64, color: Colors.grey[700]),
                  const SizedBox(height: 16),
                  const Text(
                    'No Active Custom Controls',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Open the Settings Drawer (top-right gear icon) to choose which pedals to layout.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
          );
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final double width = constraints.maxWidth;
            final double sidePadding = 8.0;
            final double availableWidth = width - sidePadding * 2;
            final double spacing = 16.0;

            double compactWidth;
            double regularWidth;
            double expandedWidth;

            if (width >= 600) {
              final double netWidth = availableWidth - (spacing * 3);
              final double colWidth = netWidth / 4;
              compactWidth = colWidth;
              regularWidth = (colWidth * 2) + spacing;
              expandedWidth = availableWidth;
            } else {
              final double netWidth = availableWidth - spacing;
              final double colWidth = netWidth / 2;
              compactWidth = colWidth;
              regularWidth = availableWidth;
              expandedWidth = availableWidth;
            }

            return SingleChildScrollView(
              controller: _cardsScrollController,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: enabledPlugins.map((pedal) {
                  final String size = _pedalSizes[pedal.instance] ?? 'regular';
                  final uriLower = pedal.uri.toLowerCase();
                  final titleLower = pedal.title.toLowerCase();
                  final isLooper =
                      uriLower.contains('alo') || titleLower.contains('alo');

                  double cardWidth = regularWidth;
                  double? cardHeight = 240.0;

                  if (isLooper) {
                    // ALO loopers: check size setting
                    if (size == 'regular') {
                      cardWidth = regularWidth;
                      cardHeight = 240.0;
                    } else {
                      // Default to expanded mode
                      cardWidth = expandedWidth;
                      cardHeight = null; // Auto-expand to fit all content
                    }
                  } else {
                    if (size == 'compact') {
                      // Same height as regular — fade buttons take full width
                      cardWidth = compactWidth;
                      cardHeight = 240.0;
                    } else if (size == 'regular') {
                      cardWidth = regularWidth;
                      cardHeight = 240.0;
                    } else {
                      // Expanded: self-sizes to content (null = no height constraint)
                      cardWidth = expandedWidth;
                      cardHeight = null;
                    }
                  }

                  final String colorHex =
                      _pedalGlowColors[pedal.instance] ??
                      _getDefaultColorForPedal(pedal);
                  final Color glowColor = _hexToColor(colorHex);
                  final String displayName =
                      _customTitles[pedal.instance] ?? pedal.title;

                  Widget cardWidget;
                  final isSwitch =
                      uriLower.contains('switch') ||
                      titleLower.contains('switch');
                  final isGainOrVolume =
                      uriLower.contains('gain') ||
                      uriLower.contains('volume') ||
                      uriLower.contains('amp') ||
                      titleLower.contains('gain') ||
                      titleLower.contains('volume');

                  if (isLooper) {
                    // Choose between extended (expanded) and regular (compact) looper cards
                    final looperSize =
                        _pedalSizes[pedal.instance] ?? 'expanded';
                    if (looperSize == 'regular') {
                      cardWidget = LooperRegularCard(
                        pedal: pedal,
                        isDarkMode: _isDarkMode,
                        glowColor: glowColor,
                        displayName: displayName,
                        bpm: _bpm,
                        looperController: _looperController,
                        webSocketService: _webSocketService,
                        onRenamePressed: () => _showRenameDialog(pedal),
                        onColorPickerPressed: () =>
                            _showColorPickerDialog(pedal),
                        onHighlightPressed: () =>
                            _highlightPedalInWebView(pedal),
                        onSizeToggled: () => _cyclePedalSize(pedal.instance),
                        onBpmTap: _showBpmDialog,
                      );
                    } else {
                      // Default to extended mode
                      cardWidget = LooperCard(
                        pedal: pedal,
                        isDarkMode: _isDarkMode,
                        glowColor: glowColor,
                        displayName: displayName,
                        bpm: _bpm,
                        looperController: _looperController,
                        webSocketService: _webSocketService,
                        onRenamePressed: () => _showRenameDialog(pedal),
                        onColorPickerPressed: () =>
                            _showColorPickerDialog(pedal),
                        onHighlightPressed: () =>
                            _highlightPedalInWebView(pedal),
                        onSizeToggled: () => _cyclePedalSize(pedal.instance),
                        onBpmTap: _showBpmDialog,
                      );
                    }
                  } else if (isSwitch) {
                    cardWidget = SwitchCard(
                      pedal: pedal,
                      size: size,
                      isDarkMode: _isDarkMode,
                      glowColor: glowColor,
                      displayName: displayName,
                      onBypassToggle: (val) => _webSocketService.toggleBypass(
                        instance: pedal.instance,
                        bypass: val,
                      ),
                      onRenamePressed: () => _showRenameDialog(pedal),
                      onHighlightPressed: () => _highlightPedalInWebView(pedal),
                      onColorPickerPressed: () => _showColorPickerDialog(pedal),
                      onOpenUri: _openPluginUri,
                      onSwitchPathChanged: (port, val) =>
                          _webSocketService.setParamValue(
                            instance: pedal.instance,
                            port: port,
                            value: val,
                          ),
                    );
                  } else if (isGainOrVolume) {
                    final double currentValue =
                        _localVolumes[pedal.instance] ??
                        (pedal.gainPortSymbol != null
                            ? pedal.parameters[pedal.gainPortSymbol]
                            : null) ??
                        0.0;
                    final bool isFading = _fadeTimers[pedal.instance] != null;
                    final bool isFadingIn =
                        isFading && (_fadeDirections[pedal.instance] == true);
                    final bool isFadingOut =
                        isFading && (_fadeDirections[pedal.instance] == false);
                    final double rangeStart =
                        _fadeRangeStart[pedal.instance] ?? 0.0;
                    final double rangeEnd =
                        _fadeRangeEnd[pedal.instance] ?? 1.0;

                    cardWidget = GainCard(
                      pedal: pedal,
                      size: size,
                      isDarkMode: _isDarkMode,
                      glowColor: glowColor,
                      displayName: displayName,
                      currentValue: currentValue,
                      isMuted: _isMuted(pedal),
                      isFading: isFading,
                      isFadingIn: isFadingIn,
                      isFadingOut: isFadingOut,
                      fadeProgress: _fadeProgress[pedal.instance] ?? 0.0,
                      rangeStart: rangeStart,
                      rangeEnd: rangeEnd,
                      fadeShape: _fadeShapes[pedal.instance] ?? 'Linear',
                      customParams:
                          _fadeCustomParams[pedal.instance] ??
                          {'cx': 0.5, 'cy': 0.5, 'slope': 1.0},
                      fadeBars: _fadeBars,
                      onVolumeChanged: (newValue) {
                        _fadeTimers[pedal.instance]?.cancel();
                        if (_mutedVolumes.containsKey(pedal.instance)) {
                          _mutedVolumes.remove(pedal.instance);
                        }
                        setState(() {
                          _fadeTimers[pedal.instance] = null;
                          _fadeProgress[pedal.instance] = 0.0;
                          _localVolumes[pedal.instance] = newValue;
                        });
                        if (pedal.gainPortSymbol != null) {
                          _webSocketService.setParamValue(
                            instance: pedal.instance,
                            port: pedal.gainPortSymbol!,
                            value: double.parse(newValue.toStringAsFixed(2)),
                          );
                        }
                      },
                      onMuteToggled: () => _toggleMute(pedal),
                      onRenamePressed: () => _showRenameDialog(pedal),
                      onColorPickerPressed: () => _showColorPickerDialog(pedal),
                      onHighlightPressed: () => _highlightPedalInWebView(pedal),
                      onSizeToggled: () {
                        setState(() {
                          final current =
                              _pedalSizes[pedal.instance] ?? 'regular';
                          if (current == 'compact') {
                            _pedalSizes[pedal.instance] = 'regular';
                          } else if (current == 'regular') {
                            _pedalSizes[pedal.instance] = 'expanded';
                          } else {
                            _pedalSizes[pedal.instance] = 'compact';
                          }
                        });
                        _saveLayoutSettings();
                      },
                      onBypassToggle: (val) => _webSocketService.toggleBypass(
                        instance: pedal.instance,
                        bypass: val,
                      ),
                      onFadeRangeChanged: (start, end) {
                        setState(() {
                          _fadeRangeStart[pedal.instance] = start;
                          _fadeRangeEnd[pedal.instance] = end;
                        });
                        _saveLayoutSettings();
                      },
                      onFadeShapeChanged: (shape) {
                        setState(() {
                          _fadeShapes[pedal.instance] = shape;
                        });
                        _saveLayoutSettings();
                      },
                      onCustomCurveParamsChanged: (params) {
                        setState(() {
                          _fadeCustomParams[pedal.instance] = params;
                        });
                        _saveLayoutSettings();
                      },
                      onTriggerFade: (fadeIn) =>
                          _triggerFade(pedal, fadeIn: fadeIn),
                      onOpenUri: _openPluginUri,
                    );
                  } else {
                    cardWidget = PlaceholderCard(
                      pedal: pedal,
                      size: size,
                      isDarkMode: _isDarkMode,
                      glowColor: glowColor,
                      displayName: displayName,
                      onBypassToggle: (val) => _webSocketService.toggleBypass(
                        instance: pedal.instance,
                        bypass: val,
                      ),
                      onRenamePressed: () => _showRenameDialog(pedal),
                      onHighlightPressed: () => _highlightPedalInWebView(pedal),
                      onColorPickerPressed: () => _showColorPickerDialog(pedal),
                      onOpenUri: _openPluginUri,
                    );
                  }

                  return SizedBox(
                    width: cardWidth,
                    height: cardHeight,
                    child: cardWidget,
                  );
                }).toList(),
              ),
            );
          },
        );
      },
    );
  }

  void _highlightAllPedalsInWebView() {
    final List<Map<String, dynamic>> configs = [];
    for (final instanceId in _enabledPluginInstances) {
      final bool isEnabled = _pedalGlowEnabled[instanceId] ?? true;
      String colorHex = _pedalGlowColors[instanceId] ?? '';
      if (colorHex.isEmpty) {
        colorHex = _getDefaultColorForInstanceId(instanceId);
      }
      configs.add({
        'instance': instanceId,
        'enabled': isEnabled,
        'color': colorHex,
      });
    }

    final String jsCode =
        '''
      (function() {
        const configs = ${jsonEncode(configs)};
        console.log("TamperMod: Synchronous board-wide blink pulse", configs);
        
        configs.forEach(c => {
          let el = document.querySelector('[mod-instance="' + c.instance + '"]');
          if (!el) {
            const cleanName = c.instance.split("/").pop();
            el = document.querySelector('[mod-instance*="' + cleanName + '"]');
          }
          
          if (el) {
            // Speed up transitions
            el.style.transition = "outline 0.12s ease, box-shadow 0.12s ease, background-color 0.12s ease";
            
            // Blink 5 times (2 seconds)
            let flashCount = 0;
            const interval = setInterval(() => {
              const isWhite = (flashCount % 2 === 0);
              if (isWhite) {
                el.style.outline = "16px solid #FFFFFF";
                el.style.outlineOffset = "6px";
                el.style.boxShadow = "0 0 120px 40px #FFFFFF, inset 0 0 45px #FFFFFF";
                el.style.backgroundColor = "rgba(255, 255, 255, 0.9)";
              } else {
                el.style.outline = "4px solid " + c.color;
                el.style.outlineOffset = "2px";
                el.style.boxShadow = "0 0 25px 12px " + c.color + ", 0 0 160px 4px " + c.color + ", inset 0 0 15px " + c.color;
                el.style.backgroundColor = hexToRgba(c.color, 0.3);
              }
              flashCount++;
              if (flashCount > 9) {
                clearInterval(interval);
                
                // Restore permanent glow state cleanly!
                if (c.enabled) {
                  el.style.transition = "outline 0.3s ease, box-shadow 0.3s ease, background-color 0.3s ease";
                  el.style.outline = "3px solid " + c.color;
                  el.style.outlineOffset = "2px";
                  el.style.boxShadow = "0 0 20px 8px " + c.color + ", 0 0 180px 4px " + c.color + ", inset 0 0 15px " + c.color;
                  el.style.backgroundColor = hexToRgba(c.color, 0.08);
                } else {
                  el.style.outline = "";
                  el.style.boxShadow = "";
                  el.style.backgroundColor = "";
                }
              }
            }, 200);
          }
        });
        
        function hexToRgba(hex, alpha) {
          let c = hex.substring(1);
          if (c.length === 3) c = c[0] + c[0] + c[1] + c[1] + c[2] + c[2];
          const r = parseInt(c.substring(0, 2), 16);
          const g = parseInt(c.substring(2, 4), 16);
          const b = parseInt(c.substring(4, 6), 16);
          return "rgba(" + r + ", " + g + ", " + b + ", " + alpha + ")";
        }
      })();
    ''';

    // SnackBar feedback
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          '⚡ SYNCHRONIZED BOARD-WIDE NEON IDENTIFICATION PULSE',
          style: TextStyle(
            color: Color(0xFF00FFCC),
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
            fontSize: 12,
          ),
        ),
        backgroundColor: const Color(0xFF161B22),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );

    try {
      _webViewController.runJavaScript(jsCode);
    } catch (e) {
      debugPrint('Error running board sync blink: $e');
    }
  }

  void _reloadPedalboard() {
    setState(() {
      _localVolumes.clear();
    });
    _webSocketService.requestPedalboard();
  }

  void _highlightPedalInWebView(PluginInstance pedal) {
    final String instId = pedal.instance;
    final String colorHex =
        _pedalGlowColors[instId] ?? _getDefaultColorForPedal(pedal);
    final bool isGlowEnabled = _pedalGlowEnabled[instId] ?? true;

    // Construct robust JavaScript to blink the pedal element in the Web GUI for 2 seconds
    final String jsCode =
        '''
      (function() {
        const instId = "$instId";
        const color = "$colorHex";
        const isGlowEnabled = $isGlowEnabled;
        console.log("TamperMod: Blinking pedal " + instId);
        
        let el = document.querySelector('[mod-instance="' + instId + '"]');
        if (!el) {
          const cleanName = instId.split("/").pop();
          el = document.querySelector('[mod-instance*="' + cleanName + '"]');
        }
        
        if (el) {
          // Temporarily accelerate transition speeds
          el.style.transition = "outline 0.12s ease, box-shadow 0.12s ease, background-color 0.12s ease";
          
          // Blink 5 times over 2 seconds (each cycle takes 400ms: 200ms white, 200ms default/off)
          let flashCount = 0;
          const interval = setInterval(() => {
            const isWhite = (flashCount % 2 === 0);
            if (isWhite) {
              el.style.outline = "16px solid #FFFFFF";
              el.style.outlineOffset = "6px";
              el.style.boxShadow = "0 0 120px 40px #FFFFFF, inset 0 0 45px #FFFFFF";
              el.style.backgroundColor = "rgba(255, 255, 255, 0.9)";
            } else {
              el.style.outline = "4px solid " + color;
              el.style.outlineOffset = "2px";
              el.style.boxShadow = "0 0 100px 2px " + color + ", inset 0 0 15px " + color;
              el.style.backgroundColor = hexToRgba(color, 0.3);
            }
            flashCount++;
            if (flashCount > 9) { // 5 complete blinking cycles (2 seconds)
              clearInterval(interval);
              
              // Restore permanent glow state cleanly!
              if (isGlowEnabled) {
                el.style.transition = "outline 0.3s ease, box-shadow 0.3s ease, background-color 0.3s ease";
                el.style.outline = "3px solid " + color;
                el.style.outlineOffset = "2px";
                el.style.boxShadow = "0 0 120px 2px " + color + ", inset 0 0 15px " + color;
                el.style.backgroundColor = hexToRgba(color, 0.08);
              } else {
                el.style.outline = "";
                el.style.boxShadow = "";
                el.style.backgroundColor = "";
              }
            }
          }, 200);
        }
        
        function hexToRgba(hex, alpha) {
          let c = hex.substring(1);
          if (c.length === 3) c = c[0] + c[0] + c[1] + c[1] + c[2] + c[2];
          const r = parseInt(c.substring(0, 2), 16);
          const g = parseInt(c.substring(2, 4), 16);
          const b = parseInt(c.substring(4, 6), 16);
          return "rgba(" + r + ", " + g + ", " + b + ", " + alpha + ")";
        }
      })();
    ''';

    // Local controller UI feedback (SnackBar)
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '⚡ BLINK IDENTIFYING: ${pedal.title.toUpperCase()}',
          style: const TextStyle(
            color: Color(0xFF00FFCC),
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
            fontSize: 12,
          ),
        ),
        backgroundColor: const Color(0xFF161B22),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );

    try {
      _webViewController.runJavaScript(jsCode);
    } catch (e) {
      debugPrint('Error highlighting pedal in WebView: $e');
    }
  }

  void _showRenameDialog(PluginInstance pedal) {
    final currentTitle = _customTitles[pedal.instance] ?? pedal.title;
    final controller = TextEditingController(text: currentTitle);
    final String instId = pedal.instance;
    final String currentColorHex =
        _pedalGlowColors[instId] ?? _getDefaultColorForPedal(pedal);
    String selectedColorHex = currentColorHex;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: _isDarkMode
                  ? const Color(0xFF0F141C)
                  : Colors.white,
              title: Text(
                'RENAME & CUSTOMIZE PEDAL',
                style: TextStyle(
                  color: _isDarkMode
                      ? const Color(0xFF00FFCC)
                      : const Color(0xFF00B3FF),
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  fontSize: 16,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name input
                    TextField(
                      controller: controller,
                      decoration: InputDecoration(
                        labelText: 'Custom Display Name',
                        labelStyle: TextStyle(
                          color: _isDarkMode ? Colors.grey : Colors.grey[700],
                        ),
                        enabledBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(
                            color: _isDarkMode
                                ? const Color(0xFF00FFCC)
                                : const Color(0xFF00B3FF),
                          ),
                        ),
                      ),
                      style: TextStyle(
                        color: _isDarkMode ? Colors.white : Colors.black,
                      ),
                      autofocus: true,
                    ),
                    const SizedBox(height: 20),
                    // Color picker section
                    Text(
                      'GLOW COLOR',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _isDarkMode
                            ? Colors.grey[400]
                            : Colors.grey[600],
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      alignment: WrapAlignment.start,
                      spacing: 10,
                      runSpacing: 10,
                      children: kNeonColors.map((hex) {
                        final Color dotColor = _hexToColor(hex);
                        final bool isSelected =
                            hex.toUpperCase() == selectedColorHex.toUpperCase();

                        int usageCount = 0;
                        for (var p in _webSocketService.allPlugins.value) {
                          final String pId = p.instance;
                          final String pColor =
                              _pedalGlowColors[pId] ??
                              _getDefaultColorForPedal(p);
                          if (pColor.toUpperCase() == hex.toUpperCase()) {
                            usageCount++;
                          }
                        }

                        return GestureDetector(
                          onTap: () {
                            setDialogState(() {
                              selectedColorHex = hex;
                            });
                          },
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: dotColor,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected
                                    ? (_isDarkMode
                                          ? Colors.white
                                          : Colors.black)
                                    : Colors.transparent,
                                width: 3,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: dotColor.withOpacity(
                                    isSelected ? 0.6 : 0.2,
                                  ),
                                  blurRadius: isSelected ? 12 : 6,
                                  spreadRadius: isSelected ? 2 : 1,
                                ),
                              ],
                            ),
                            child: usageCount > 0
                                ? Center(
                                    child: Container(
                                      padding: const EdgeInsets.all(3),
                                      decoration: BoxDecoration(
                                        color: dotColor.computeLuminance() > 0.5
                                            ? Colors.black.withOpacity(0.15)
                                            : Colors.white.withOpacity(0.2),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Text(
                                        '$usageCount',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color:
                                              dotColor.computeLuminance() > 0.5
                                              ? Colors.black
                                              : Colors.white,
                                        ),
                                      ),
                                    ),
                                  )
                                : null,
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'CANCEL',
                    style: TextStyle(
                      color: _isDarkMode ? Colors.grey : Colors.grey[600],
                    ),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isDarkMode
                        ? const Color(0xFF00FFCC)
                        : const Color(0xFF00B3FF),
                    foregroundColor: _isDarkMode ? Colors.black : Colors.white,
                  ),
                  onPressed: () {
                    if (controller.text.trim().isNotEmpty) {
                      setState(() {
                        _customTitles[pedal.instance] = controller.text.trim();
                        _pedalGlowColors[instId] = selectedColorHex;
                      });
                      _updateAllGlowsInWebView();
                      _saveLayoutSettings();
                    }
                    Navigator.pop(context);
                  },
                  child: const Text(
                    'SAVE',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showColorPickerDialog(PluginInstance pedal) {
    final String instId = pedal.instance;
    final String currentColorHex =
        _pedalGlowColors[instId] ?? _getDefaultColorForPedal(pedal);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: _isDarkMode ? const Color(0xFF161B22) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'CHOOSE GLOW COLOR',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
              color: _isDarkMode ? Colors.white : Colors.black,
            ),
          ),
          content: SingleChildScrollView(
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: kNeonColors.map((hex) {
                final Color dotColor = _hexToColor(hex);
                final bool isSelected =
                    hex.toUpperCase() == currentColorHex.toUpperCase();

                int usageCount = 0;
                for (var p in _webSocketService.allPlugins.value) {
                  final String pId = p.instance;
                  final String pColor =
                      _pedalGlowColors[pId] ?? _getDefaultColorForPedal(p);
                  if (pColor.toUpperCase() == hex.toUpperCase()) {
                    usageCount++;
                  }
                }

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _pedalGlowColors[instId] = hex;
                    });
                    _updateAllGlowsInWebView();
                    _saveLayoutSettings();
                    Navigator.of(context).pop();
                  },
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: dotColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected
                            ? (_isDarkMode ? Colors.white : Colors.black)
                            : Colors.transparent,
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: dotColor.withOpacity(isSelected ? 0.6 : 0.2),
                          blurRadius: isSelected ? 12 : 6,
                          spreadRadius: isSelected ? 2 : 1,
                        ),
                      ],
                    ),
                    child: usageCount > 0
                        ? Center(
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: dotColor.computeLuminance() > 0.5
                                    ? Colors.black.withOpacity(0.15)
                                    : Colors.white.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '$usageCount',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: dotColor.computeLuminance() > 0.5
                                      ? Colors.black
                                      : Colors.white,
                                ),
                              ),
                            ),
                          )
                        : null,
                  ),
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'CANCEL',
                style: TextStyle(
                  color: _isDarkMode
                      ? const Color(0xFF00FFCC)
                      : const Color(0xFF00B3FF),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildWebView() {
    return WebViewWidget(controller: _webViewController);
  }

  Future<void> _loadThemeSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedDark = prefs.getBool('is_dark_mode');
      if (savedDark != null && mounted) {
        setState(() {
          _isDarkMode = savedDark;
        });
      }
    } catch (e) {
      debugPrint('Error loading theme settings: $e');
    }
  }

  Future<void> _saveThemeSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_dark_mode', _isDarkMode);
    } catch (e) {
      debugPrint('Error saving theme settings: $e');
    }
  }

  int _stableStringHash(String s) {
    int hash = 5381;
    for (int i = 0; i < s.length; i++) {
      hash = ((hash << 5) + hash) + s.codeUnitAt(i);
      hash = hash & 0xFFFFFFFF; // Force 32-bit unsigned integer
    }
    return hash;
  }

  String _getPedalboardBaseKey() {
    final plugins = _webSocketService.allPlugins.value;
    if (plugins.isEmpty) return 'default_pedalboard';
    final List<String> instances = plugins.map((p) => p.instance).toList()
      ..sort();
    final String joint = instances.join(',');
    final int hash = _stableStringHash(joint);
    return 'pedalboard_$hash';
  }

  String _getPedalboardKey() {
    final base = _getPedalboardBaseKey();
    if (base == 'default_pedalboard') return 'default_pedalboard';
    return '${base}_$_activeConfig';
  }

  Future<void> _duplicateCurrentConfig() async {
    final baseKey = _getPedalboardBaseKey();
    if (baseKey == 'default_pedalboard') return;

    final TextEditingController nameController = TextEditingController();
    final String? newName = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: _isDarkMode ? const Color(0xFF0F141C) : Colors.white,
          title: Text(
            'DUPLICATE CONFIGURATION',
            style: TextStyle(
              color: _isDarkMode ? const Color(0xFF00FFCC) : const Color(0xFF00B3FF),
              fontWeight: FontWeight.bold,
              fontSize: 16,
              letterSpacing: 1.2,
            ),
          ),
          content: TextField(
            controller: nameController,
            decoration: InputDecoration(
              labelText: 'New Configuration Name',
              labelStyle: TextStyle(
                color: _isDarkMode ? Colors.grey : Colors.grey[700],
              ),
              enabledBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.grey),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(
                  color: _isDarkMode ? const Color(0xFF00FFCC) : const Color(0xFF00B3FF),
                ),
              ),
            ),
            style: TextStyle(
              color: _isDarkMode ? Colors.white : Colors.black,
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'CANCEL',
                style: TextStyle(
                  color: _isDarkMode ? Colors.grey : Colors.grey[600],
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _isDarkMode ? const Color(0xFF00FFCC) : const Color(0xFF00B3FF),
                foregroundColor: _isDarkMode ? Colors.black : Colors.white,
              ),
              onPressed: () {
                final text = nameController.text.trim();
                if (text.isNotEmpty) {
                  Navigator.pop(context, text);
                }
              },
              child: const Text(
                'DUPLICATE',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );

    if (newName == null || newName.isEmpty) return;

    // Save current configuration first to ensure everything is saved
    await _saveLayoutSettings();

    final prefs = await SharedPreferences.getInstance();
    final oldKey = _getPedalboardKey();
    
    setState(() {
      _activeConfig = newName;
      if (!_configsList.contains(newName)) {
        _configsList.add(newName);
      }
    });

    final newKey = _getPedalboardKey();

    // Copy all settings from oldKey to newKey in SharedPreferences
    final List<String>? order = prefs.getStringList('${oldKey}_order');
    if (order != null) await prefs.setStringList('${newKey}_order', order);

    final List<String>? enabled = prefs.getStringList('${oldKey}_enabled');
    if (enabled != null) await prefs.setStringList('${newKey}_enabled', enabled);

    final String? colors = prefs.getString('${oldKey}_colors');
    if (colors != null) await prefs.setString('${newKey}_colors', colors);

    final String? sizes = prefs.getString('${oldKey}_sizes');
    if (sizes != null) await prefs.setString('${newKey}_sizes', sizes);

    final String? customTitles = prefs.getString('${oldKey}_custom_titles');
    if (customTitles != null) await prefs.setString('${newKey}_custom_titles', customTitles);

    final String? glowEnabled = prefs.getString('${oldKey}_glow_enabled');
    if (glowEnabled != null) await prefs.setString('${newKey}_glow_enabled', glowEnabled);

    final int? fadeBars = prefs.getInt('${oldKey}_fade_bars');
    if (fadeBars != null) await prefs.setInt('${newKey}_fade_bars', fadeBars);

    final String? fadeRangeStart = prefs.getString('${oldKey}_fadeRangeStart');
    if (fadeRangeStart != null) await prefs.setString('${newKey}_fadeRangeStart', fadeRangeStart);

    final String? fadeRangeEnd = prefs.getString('${oldKey}_fadeRangeEnd');
    if (fadeRangeEnd != null) await prefs.setString('${newKey}_fadeRangeEnd', fadeRangeEnd);

    final String? fadeShapes = prefs.getString('${oldKey}_fadeShapes');
    if (fadeShapes != null) await prefs.setString('${newKey}_fadeShapes', fadeShapes);

    final String? fadeCustomParams = prefs.getString('${oldKey}_fadeCustomParams');
    if (fadeCustomParams != null) await prefs.setString('${newKey}_fadeCustomParams', fadeCustomParams);

    // Save configurations list & active config metadata
    await prefs.setStringList('${baseKey}_configs_list', _configsList);
    await prefs.setString('${baseKey}_active_config', _activeConfig);

    // Reload settings
    await _syncAndLoadLayoutSettings();
  }

  Future<void> _renameCurrentConfig() async {
    final baseKey = _getPedalboardBaseKey();
    if (baseKey == 'default_pedalboard') return;
    if (_activeConfig == 'default') return; // Cannot rename default

    final TextEditingController nameController = TextEditingController(text: _activeConfig);
    final String? newName = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: _isDarkMode ? const Color(0xFF0F141C) : Colors.white,
          title: Text(
            'RENAME CONFIGURATION',
            style: TextStyle(
              color: _isDarkMode ? const Color(0xFF00FFCC) : const Color(0xFF00B3FF),
              fontWeight: FontWeight.bold,
              fontSize: 16,
              letterSpacing: 1.2,
            ),
          ),
          content: TextField(
            controller: nameController,
            decoration: InputDecoration(
              labelText: 'Configuration Name',
              labelStyle: TextStyle(
                color: _isDarkMode ? Colors.grey : Colors.grey[700],
              ),
              enabledBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.grey),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(
                  color: _isDarkMode ? const Color(0xFF00FFCC) : const Color(0xFF00B3FF),
                ),
              ),
            ),
            style: TextStyle(
              color: _isDarkMode ? Colors.white : Colors.black,
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'CANCEL',
                style: TextStyle(
                  color: _isDarkMode ? Colors.grey : Colors.grey[600],
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _isDarkMode ? const Color(0xFF00FFCC) : const Color(0xFF00B3FF),
                foregroundColor: _isDarkMode ? Colors.black : Colors.white,
              ),
              onPressed: () {
                final text = nameController.text.trim();
                if (text.isNotEmpty) {
                  Navigator.pop(context, text);
                }
              },
              child: const Text(
                'RENAME',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );

    if (newName == null || newName.isEmpty || newName == _activeConfig) return;

    // Save first
    await _saveLayoutSettings();

    final prefs = await SharedPreferences.getInstance();
    final oldConfigName = _activeConfig;
    final oldKey = _getPedalboardKey();

    setState(() {
      final index = _configsList.indexOf(oldConfigName);
      if (index != -1) {
        _configsList[index] = newName;
      } else {
        _configsList.add(newName);
      }
      _activeConfig = newName;
    });

    final newKey = _getPedalboardKey();

    // Copy all settings from oldKey to newKey in SharedPreferences
    final List<String>? order = prefs.getStringList('${oldKey}_order');
    if (order != null) await prefs.setStringList('${newKey}_order', order);

    final List<String>? enabled = prefs.getStringList('${oldKey}_enabled');
    if (enabled != null) await prefs.setStringList('${newKey}_enabled', enabled);

    final String? colors = prefs.getString('${oldKey}_colors');
    if (colors != null) await prefs.setString('${newKey}_colors', colors);

    final String? sizes = prefs.getString('${oldKey}_sizes');
    if (sizes != null) await prefs.setString('${newKey}_sizes', sizes);

    final String? customTitles = prefs.getString('${oldKey}_custom_titles');
    if (customTitles != null) await prefs.setString('${newKey}_custom_titles', customTitles);

    final String? glowEnabled = prefs.getString('${oldKey}_glow_enabled');
    if (glowEnabled != null) await prefs.setString('${newKey}_glow_enabled', glowEnabled);

    final int? fadeBars = prefs.getInt('${oldKey}_fade_bars');
    if (fadeBars != null) await prefs.setInt('${newKey}_fade_bars', fadeBars);

    final String? fadeRangeStart = prefs.getString('${oldKey}_fadeRangeStart');
    if (fadeRangeStart != null) await prefs.setString('${newKey}_fadeRangeStart', fadeRangeStart);

    final String? fadeRangeEnd = prefs.getString('${oldKey}_fadeRangeEnd');
    if (fadeRangeEnd != null) await prefs.setString('${newKey}_fadeRangeEnd', fadeRangeEnd);

    final String? fadeShapes = prefs.getString('${oldKey}_fadeShapes');
    if (fadeShapes != null) await prefs.setString('${newKey}_fadeShapes', fadeShapes);

    final String? fadeCustomParams = prefs.getString('${oldKey}_fadeCustomParams');
    if (fadeCustomParams != null) await prefs.setString('${newKey}_fadeCustomParams', fadeCustomParams);

    // Save configurations list & active config metadata
    await prefs.setStringList('${baseKey}_configs_list', _configsList);
    await prefs.setString('${baseKey}_active_config', _activeConfig);

    // Delete old configurations keys
    await prefs.remove('${oldKey}_order');
    await prefs.remove('${oldKey}_enabled');
    await prefs.remove('${oldKey}_colors');
    await prefs.remove('${oldKey}_sizes');
    await prefs.remove('${oldKey}_custom_titles');
    await prefs.remove('${oldKey}_glow_enabled');
    await prefs.remove('${oldKey}_fade_bars');
    await prefs.remove('${oldKey}_fadeRangeStart');
    await prefs.remove('${oldKey}_fadeRangeEnd');
    await prefs.remove('${oldKey}_fadeShapes');
    await prefs.remove('${oldKey}_fadeCustomParams');

    await _syncAndLoadLayoutSettings();
  }

  Future<void> _deleteCurrentConfig() async {
    final baseKey = _getPedalboardBaseKey();
    if (baseKey == 'default_pedalboard') return;
    if (_activeConfig == 'default') return; // Cannot delete default

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: _isDarkMode ? const Color(0xFF0F141C) : Colors.white,
          title: const Text(
            'DELETE CONFIGURATION',
            style: TextStyle(
              color: Color(0xFFFF007F),
              fontWeight: FontWeight.bold,
              fontSize: 16,
              letterSpacing: 1.2,
            ),
          ),
          content: Text(
            'Are you sure you want to permanently delete the configuration "${_activeConfig}"?',
            style: TextStyle(
              color: _isDarkMode ? Colors.white : Colors.black,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'CANCEL',
                style: TextStyle(
                  color: _isDarkMode ? Colors.grey : Colors.grey[600],
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF007F),
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                'DELETE',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    final prefs = await SharedPreferences.getInstance();
    final oldConfigName = _activeConfig;
    final oldKey = _getPedalboardKey();

    setState(() {
      _configsList.remove(oldConfigName);
      _activeConfig = 'default';
    });

    // Save configurations list & active config metadata
    await prefs.setStringList('${baseKey}_configs_list', _configsList);
    await prefs.setString('${baseKey}_active_config', _activeConfig);

    // Delete old configurations keys
    await prefs.remove('${oldKey}_order');
    await prefs.remove('${oldKey}_enabled');
    await prefs.remove('${oldKey}_colors');
    await prefs.remove('${oldKey}_sizes');
    await prefs.remove('${oldKey}_custom_titles');
    await prefs.remove('${oldKey}_glow_enabled');
    await prefs.remove('${oldKey}_fade_bars');
    await prefs.remove('${oldKey}_fadeRangeStart');
    await prefs.remove('${oldKey}_fadeRangeEnd');
    await prefs.remove('${oldKey}_fadeShapes');
    await prefs.remove('${oldKey}_fadeCustomParams');

    await _syncAndLoadLayoutSettings();
  }

  Future<void> _switchConfig(String targetConfigName) async {
    if (targetConfigName == _activeConfig) return;

    // Save current settings first
    await _saveLayoutSettings();

    final baseKey = _getPedalboardBaseKey();
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      _activeConfig = targetConfigName;
    });

    await prefs.setString('${baseKey}_active_config', _activeConfig);

    // Load layout settings for the new configuration
    await _syncAndLoadLayoutSettings();
  }

  Future<void> _saveLayoutSettings() async {
    final key = _getPedalboardKey();
    if (key == 'default_pedalboard') return;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('${key}_order', _orderedPluginInstances);
      await prefs.setStringList('${key}_enabled', _enabledPluginInstances);
      await prefs.setString('${key}_colors', jsonEncode(_pedalGlowColors));
      await prefs.setString('${key}_sizes', jsonEncode(_pedalSizes));
      await prefs.setString('${key}_custom_titles', jsonEncode(_customTitles));
      await prefs.setString('${key}_glow_enabled', jsonEncode(_pedalGlowEnabled));
      await prefs.setInt('${key}_fade_bars', _fadeBars);
      // Fade settings
      await prefs.setString(
        '${key}_fadeRangeStart',
        jsonEncode(_fadeRangeStart),
      );
      await prefs.setString('${key}_fadeRangeEnd', jsonEncode(_fadeRangeEnd));
      await prefs.setString('${key}_fadeShapes', jsonEncode(_fadeShapes));
      // Encode nested map: Map<String, Map<String, double>>
      final customEncoded = _fadeCustomParams.map(
        (k, v) => MapEntry(k, jsonEncode(v)),
      );
      await prefs.setString(
        '${key}_fadeCustomParams',
        jsonEncode(customEncoded),
      );
      debugPrint('Saved layout settings for $key');
    } catch (e) {
      debugPrint('Error saving layout settings: $e');
    }
  }

  Future<Map<String, dynamic>> _getDatabaseSummary() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final Set<String> keys = prefs.getKeys();
      final Set<String> pedalboards = {};
      final Set<String> configs = {};
      int keyCount = 0;

      for (final key in keys) {
        if (key.startsWith('pedalboard_')) {
          keyCount++;
          final parts = key.split('_');
          if (parts.length >= 2) {
            final pbId = parts[1];
            pedalboards.add('pedalboard_$pbId');
          }
          if (key.contains('_configs_list')) {
            final list = prefs.getStringList(key);
            if (list != null) {
              configs.addAll(list);
            }
          }
        }
      }

      return {
        'pedalboardsCount': pedalboards.length,
        'configsCount': configs.isEmpty ? 1 : configs.length,
        'keysCount': keyCount,
      };
    } catch (e) {
      debugPrint('Error getting database summary: $e');
      return {
        'pedalboardsCount': 0,
        'configsCount': 0,
        'keysCount': 0,
      };
    }
  }

  Future<void> _exportConfigurationsToFile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final Set<String> keys = prefs.getKeys();
      final Map<String, dynamic> backupData = {};

      for (final key in keys) {
        if (key.startsWith('pedalboard_') || key == 'is_dark_mode') {
          final value = prefs.get(key);
          backupData[key] = value;
        }
      }

      final jsonString = jsonEncode(backupData);
      final tempDir = Directory.systemTemp;
      final tempFile = File('${tempDir.path}/tampermod_layouts_backup.json');
      await tempFile.writeAsString(jsonString);

      await Share.shareXFiles(
        [XFile(tempFile.path)],
        subject: 'TamperMod Layout Backup',
        text: 'TamperMod Layout configurations backup JSON file.',
      );
    } catch (e) {
      debugPrint('Error exporting configurations: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error exporting configurations: $e'),
            backgroundColor: const Color(0xFFFF007F),
          ),
        );
      }
    }
  }

  Future<void> _importConfigurationsFromFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null || result.files.single.path == null) {
        return; // User cancelled
      }

      final file = File(result.files.single.path!);
      final jsonString = await file.readAsString();
      final Map<String, dynamic> decoded = jsonDecode(jsonString);

      if (decoded.isEmpty || !decoded.keys.any((k) => k.startsWith('pedalboard_'))) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Invalid backup file structure!'),
              backgroundColor: Color(0xFFFF007F),
            ),
          );
        }
        return;
      }

      if (!mounted) return;

      // Ask for confirmation
      final bool? confirm = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            backgroundColor: _isDarkMode ? const Color(0xFF0F141C) : Colors.white,
            title: const Text(
              'CONFIRM RESTORE',
              style: TextStyle(
                color: Color(0xFFFF007F),
                fontWeight: FontWeight.bold,
                fontSize: 16,
                letterSpacing: 1.2,
              ),
            ),
            content: Text(
              'This will overwrite all your current pedalboard layouts and settings. Are you sure you want to continue?',
              style: TextStyle(
                color: _isDarkMode ? Colors.white : Colors.black,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  'CANCEL',
                  style: TextStyle(
                    color: _isDarkMode ? Colors.grey : Colors.grey[600],
                  ),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF007F),
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'RESTORE',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          );
        },
      );

      if (confirm != true) return;

      final prefs = await SharedPreferences.getInstance();

      // Clear existing pedalboard configurations
      final Set<String> currentKeys = prefs.getKeys();
      for (final key in currentKeys) {
        if (key.startsWith('pedalboard_')) {
          await prefs.remove(key);
        }
      }

      // Write new configuration keys
      for (final entry in decoded.entries) {
        final key = entry.key;
        final val = entry.value;
        if (val is bool) {
          await prefs.setBool(key, val);
        } else if (val is int) {
          await prefs.setInt(key, val);
        } else if (val is double) {
          await prefs.setDouble(key, val);
        } else if (val is String) {
          await prefs.setString(key, val);
        } else if (val is List) {
          await prefs.setStringList(key, val.map((e) => e.toString()).toList());
        }
      }

      // Reload
      await _syncAndLoadLayoutSettings();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Layout configurations restored successfully!'),
            backgroundColor: Color(0xFF00FFCC),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error importing configurations: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error importing configurations: $e'),
            backgroundColor: const Color(0xFFFF007F),
          ),
        );
      }
    }
  }

  void _showBackupRestoreDialog() async {
    final summary = await _getDatabaseSummary();
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final TextEditingController jsonTextController = TextEditingController();

            return AlertDialog(
              backgroundColor: _isDarkMode ? const Color(0xFF0F141C) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: _isDarkMode
                      ? const Color(0xFF00FFCC).withOpacity(0.3)
                      : const Color(0xFF00B3FF).withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              title: Row(
                children: [
                  Icon(
                    Icons.settings_backup_restore_rounded,
                    color: _isDarkMode ? const Color(0xFF00FFCC) : const Color(0xFF00B3FF),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'BACKUP & RESTORE',
                    style: TextStyle(
                      color: _isDarkMode ? Colors.white : Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 450,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Database Summary Panel
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                        decoration: BoxDecoration(
                          color: _isDarkMode
                              ? const Color(0xFF070A0F)
                              : Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _isDarkMode ? Colors.grey[850]! : Colors.grey[300]!,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildStatItem('Pedalboards', '${summary['pedalboardsCount']}'),
                            _buildStatItem('Configurations', '${summary['configsCount']}'),
                            _buildStatItem('Total Keys', '${summary['keysCount']}'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Instructions
                      Text(
                        'Layout configurations are deleted when the application is uninstalled. Use these tools to back up and restore your settings.',
                        style: TextStyle(
                          fontSize: 11,
                          color: _isDarkMode ? Colors.grey[400] : Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Two Action Cards
                      Row(
                        children: [
                          // Export Card
                          Expanded(
                            child: _buildBackupCard(
                              title: 'EXPORT TO DRIVE',
                              subtitle: 'Save JSON file via system Share Sheet',
                              icon: Icons.cloud_upload_rounded,
                              color: const Color(0xFF00FFCC),
                              onTap: () {
                                Navigator.pop(context);
                                _exportConfigurationsToFile();
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Import Card
                          Expanded(
                            child: _buildBackupCard(
                              title: 'IMPORT FROM DRIVE',
                              subtitle: 'Pick JSON file from system folders',
                              icon: Icons.folder_open_rounded,
                              color: const Color(0xFFFF007F),
                              onTap: () {
                                Navigator.pop(context);
                                _importConfigurationsFromFile();
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Collapsible Raw Text Options
                      ExpansionTile(
                        iconColor: _isDarkMode ? const Color(0xFF00FFCC) : const Color(0xFF00B3FF),
                        collapsedIconColor: Colors.grey,
                        title: Text(
                          'Advanced: Raw Clipboard JSON',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _isDarkMode ? Colors.grey[300] : Colors.grey[800],
                          ),
                        ),
                        children: [
                          const SizedBox(height: 8),
                          TextField(
                            controller: jsonTextController,
                            maxLines: 4,
                            decoration: InputDecoration(
                              hintText: 'Paste layout backup JSON string here...',
                              hintStyle: const TextStyle(fontSize: 11, color: Colors.grey),
                              fillColor: _isDarkMode ? const Color(0xFF070A0F) : Colors.grey[50],
                              filled: true,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF00FFCC),
                                  foregroundColor: Colors.black,
                                  textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                                icon: const Icon(Icons.copy_rounded, size: 14),
                                label: const Text('COPY CURRENT JSON'),
                                onPressed: () async {
                                  try {
                                    final prefs = await SharedPreferences.getInstance();
                                    final Set<String> keys = prefs.getKeys();
                                    final Map<String, dynamic> backupData = {};
                                    for (final key in keys) {
                                      if (key.startsWith('pedalboard_') || key == 'is_dark_mode') {
                                        backupData[key] = prefs.get(key);
                                      }
                                    }
                                    final jsonStr = jsonEncode(backupData);
                                    await Clipboard.setData(ClipboardData(text: jsonStr));
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('JSON copied to clipboard!'),
                                          backgroundColor: Color(0xFF00FFCC),
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    debugPrint('Error copying JSON: $e');
                                  }
                                },
                              ),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFFF007F),
                                  foregroundColor: Colors.white,
                                  textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                                icon: const Icon(Icons.paste_rounded, size: 14),
                                label: const Text('IMPORT FROM TEXT'),
                                onPressed: () async {
                                  final text = jsonTextController.text.trim();
                                  if (text.isEmpty) return;
                                  Navigator.pop(context);
                                  
                                  try {
                                    final Map<String, dynamic> decoded = jsonDecode(text);
                                    if (decoded.isEmpty || !decoded.keys.any((k) => k.startsWith('pedalboard_'))) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Invalid backup JSON!'),
                                          backgroundColor: Color(0xFFFF007F),
                                        ),
                                      );
                                      return;
                                    }
                                    
                                    final bool? confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (context) {
                                        return AlertDialog(
                                          backgroundColor: _isDarkMode ? const Color(0xFF0F141C) : Colors.white,
                                          title: const Text('CONFIRM RESTORE', style: TextStyle(color: Color(0xFFFF007F), fontWeight: FontWeight.bold, fontSize: 16)),
                                          content: const Text('Are you sure you want to overwrite all configurations with this JSON?'),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(context, false),
                                              child: Text('CANCEL', style: TextStyle(color: _isDarkMode ? Colors.grey : Colors.grey[600])),
                                            ),
                                            ElevatedButton(
                                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF007F), foregroundColor: Colors.white),
                                              onPressed: () => Navigator.pop(context, true),
                                              child: const Text('RESTORE', style: TextStyle(fontWeight: FontWeight.bold)),
                                            ),
                                          ],
                                        );
                                      },
                                    );
                                    
                                    if (confirm != true) return;
                                    
                                    final prefs = await SharedPreferences.getInstance();
                                    final Set<String> currentKeys = prefs.getKeys();
                                    for (final key in currentKeys) {
                                      if (key.startsWith('pedalboard_')) {
                                        await prefs.remove(key);
                                      }
                                    }
                                    for (final entry in decoded.entries) {
                                      final key = entry.key;
                                      final val = entry.value;
                                      if (val is bool) {
                                        await prefs.setBool(key, val);
                                      } else if (val is int) {
                                        await prefs.setInt(key, val);
                                      } else if (val is double) {
                                        await prefs.setDouble(key, val);
                                      } else if (val is String) {
                                        await prefs.setString(key, val);
                                      } else if (val is List) {
                                        await prefs.setStringList(key, val.map((e) => e.toString()).toList());
                                      }
                                    }
                                    await _syncAndLoadLayoutSettings();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Layout configurations restored successfully!'),
                                        backgroundColor: Color(0xFF00FFCC),
                                      ),
                                    );
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Error restoring JSON: $e'),
                                        backgroundColor: const Color(0xFFFF007F),
                                      ),
                                    );
                                  }
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'CLOSE',
                    style: TextStyle(
                      color: _isDarkMode ? Colors.grey : Colors.grey[600],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            color: _isDarkMode ? const Color(0xFF00FFCC) : const Color(0xFF00B3FF),
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: _isDarkMode ? Colors.grey[500] : Colors.grey[600],
            fontWeight: FontWeight.w600,
            fontSize: 8,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildBackupCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _isDarkMode ? const Color(0xFF131924) : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          splashColor: color.withOpacity(0.2),
          highlightColor: color.withOpacity(0.1),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  color: color,
                  size: 32,
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _isDarkMode ? Colors.white : Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _isDarkMode ? Colors.grey[500] : Colors.grey[600],
                    fontSize: 8.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getDefaultColorForInstanceId(String instanceId) {
    // All plugins use the same least-used color assignment — no type overrides.
    return getLeastUsedColor(_pedalGlowColors);
  }

  String _getDefaultColorForPedal(PluginInstance pedal) {
    return _getDefaultColorForInstanceId(pedal.instance);
  }

  void _cyclePedalSize(String instanceId) {
    PluginInstance? pedal;
    for (var p in _webSocketService.allPlugins.value) {
      if (p.instance == instanceId) {
        pedal = p;
        break;
      }
    }
    if (pedal != null) {
      final uriLower = pedal.uri.toLowerCase();
      final titleLower = pedal.title.toLowerCase();
      final isLooper = uriLower.contains('alo') || titleLower.contains('alo');
      if (isLooper) {
        // ALO loopers toggle between 'expanded' and 'regular' modes
        final currentSize = _pedalSizes[instanceId] ?? 'expanded';
        setState(() {
          _pedalSizes[instanceId] = currentSize == 'expanded'
              ? 'regular'
              : 'expanded';
        });
        _saveLayoutSettings();
        return;
      }
    }

    final current = _pedalSizes[instanceId] ?? 'regular';
    String next = 'regular';
    if (current == 'compact') {
      next = 'regular';
    } else if (current == 'regular') {
      next = 'expanded';
    } else if (current == 'expanded') {
      next = 'compact';
    }
    setState(() {
      _pedalSizes[instanceId] = next;
    });
    _saveLayoutSettings();
  }

  void _scrollToCard(String instanceId) {
    final int index = _enabledPluginInstances.indexOf(instanceId);
    if (index == -1) return;

    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final bool isSplit = _showControls && _showWeb;

    double controlsWidth = screenWidth;
    if (isSplit) {
      controlsWidth = isLandscape ? (screenWidth * 5 / 11) : screenWidth;
    }

    // Calculate card dimensions based on screen width
    final double sidePadding = 8.0;
    final double availableWidth = controlsWidth - sidePadding * 2;
    final double spacing = 16.0;

    double cardHeight = 240.0;
    int crossAxisCount = 1;

    if (controlsWidth >= 600) {
      final double netWidth = availableWidth - (spacing * 3);
      final double colWidth = netWidth / 4;
      crossAxisCount = 2;
      // Average card height (some may be compact, regular, or expanded)
      cardHeight = 240.0;
    } else {
      crossAxisCount = 1;
      cardHeight = 240.0;
    }

    // Calculate which row the card is in
    final int rowIndex = index ~/ crossAxisCount;

    // Calculate scroll offset to position the card
    // Account for padding and spacing
    final double scrollOffset = (rowIndex * (cardHeight + spacing)) - spacing;

    if (_cardsScrollController.hasClients) {
      // Scroll to position with some margin to ensure full visibility
      final double targetOffset = scrollOffset.clamp(
        0.0,
        _cardsScrollController.position.maxScrollExtent,
      );

      _cardsScrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOutCubic,
      );
    }
  }
}
