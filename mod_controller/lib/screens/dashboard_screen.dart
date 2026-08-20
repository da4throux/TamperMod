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
import '../utils/plugin_category.dart';
import '../models/parameter_metadata.dart';

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
  bool _showConnectionPanel = true;
  bool _isDarkMode = true;
  List<String> _orderedPluginInstances = [];

  // Track volume slider values locally to make the slider extremely responsive
  final Map<String, double> _localVolumes = {};
  final Map<String, double> _mutedVolumes = {};
  final Map<String, double> _scrapedPedalDisplays = {};

  // Fade range cursors: fractional [0.0–1.0] position within min..max gain range
  final Map<String, double> _fadeRangeStart = {};
  final Map<String, double> _fadeRangeEnd = {};

  // Per-pedal fade shape: 'linear' | 'easeInOut' | 'easeIn' | 'easeOut' | 'custom'
  final Map<String, String> _fadeShapes = {};

  // Per-pedal custom S-curve params: h1x, h1y, mx, my, h2x, h2y (Fade In)
  final Map<String, Map<String, double>> _fadeCustomParams = {};
  // Per-pedal custom S-curve params: h1x, h1y, mx, my, h2x, h2y (Fade Out)
  final Map<String, Map<String, double>> _fadeCustomParamsOut = {};
  // User-saved custom curve presets
  final Map<String, Map<String, double>> _savedCustomCurvePresets = {};

  // Live fade progress [0.0–1.0] — transient, not persisted
  final Map<String, double> _fadeProgress = {};

  // Custom User Ordering and Visibility List
  List<String> _enabledPluginInstances = [];

  final ScrollController _cardsScrollController = ScrollController();
  final Map<String, GlobalKey> _cardKeys = {};
  final Map<String, String> _pedalGlowColors = {};
  final Map<String, bool> _pedalGlowEnabled = {};
  final Map<String, String> _pedalSizes = {};

  String? _highlightedInstanceId;
  Timer? _highlightTimer;
  Timer? _flashStrobeTimer;
  bool _isFlashStateOn = false;

  GlobalKey _getCardKey(String instanceId) {
    return _cardKeys.putIfAbsent(instanceId, () => GlobalKey());
  }

  // Inline puzzle organizer panel state (replaces overlay endDrawer)
  bool _isPuzzleOpen = false;

  Color _hexToColor(String hex) => hexToColor(hex);

  void _updateAllGlowsInWebView() {
    // Safety check: ensure we're mounted and looper controller is initialized
    if (!mounted) return;

    final List<Map<String, dynamic>> configs = [];
    for (final instanceId in _enabledPluginInstances) {
      if (instanceId.startsWith('__spacer_') || instanceId.startsWith('__linebreak_')) continue;
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

    final Map<String, Map<String, dynamic>> titlesMap = {};
    for (final p in _webSocketService.allPlugins.value) {
      final bool isPlaced = _enabledPluginInstances.contains(p.instance);
      final cat = PluginCategoryHelper.getCategoryForPlugin(p);
      titlesMap[p.instance] = {
        'title': p.title,
        'custom': _customTitles[p.instance] ?? '',
        'isPlaced': isPlaced,
        'categoryCode': cat.shortCode,
        'categoryLabel': cat.label,
        'categoryColor': cat.defaultColor.toARGB32().toRadixString(16).substring(2),
        'categoryEmoji': PluginCategoryHelper.getCategoryEmoji(cat.type),
      };
    }

    final String jsCode =
        '''
      (function() {
        const configs = ${jsonEncode(configs)};
        window._tamperPedalTitles = ${jsonEncode(titlesMap)};
        console.log("TamperMod: Updating permanent glows and pedal titles", configs);
        
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
      _injectPedalClickListener();
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

  void _handleDiscoveryData(String jsonString) {
    try {
      final List<dynamic> decoded = json.decode(jsonString);
      for (final item in decoded) {
        if (item is Map<String, dynamic>) {
          final String? instance = item['instance'];
          final String? name = item['name'];
          final String? label = item['label'];
          final List<dynamic>? portsData = item['ports'];
          if (instance != null && portsData != null) {
            final List<ParameterMetadata> metadataList = portsData
                .map((p) => ParameterMetadata.fromJson(p as Map<String, dynamic>))
                .toList();
            _webSocketService.updatePluginMetadata(
              instance: instance,
              name: name,
              label: label,
              metadataList: metadataList,
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error parsing discovery data: $e');
    }
  }

  void _injectMetadataDiscovery() {
    const String jsCode = r'''
      (function() {
        if (!window._hasInstalledTamperInspector) {
          window._hasInstalledTamperInspector = true;
          console.log("TAMPER: Installing Traffic Inspector & Control Helpers into WebView context");

          // 1. Intercept WebSocket sends and track active socket
          if (window.WebSocket) {
            var origWsSend = WebSocket.prototype.send;
            WebSocket.prototype.send = function(data) {
              window.tamperActiveWs = this;
              console.log("TAMPER_WS_SEND: " + data);
              return origWsSend.apply(this, arguments);
            };
          }

          // 2. Intercept XHR / AJAX sends
          if (window.XMLHttpRequest) {
            var origXhrOpen = XMLHttpRequest.prototype.open;
            var origXhrSend = XMLHttpRequest.prototype.send;
            XMLHttpRequest.prototype.open = function(method, url) {
              this._url = url;
              this._method = method;
              return origXhrOpen.apply(this, arguments);
            };
            XMLHttpRequest.prototype.send = function(body) {
              console.log("TAMPER_XHR_SEND: " + this._method + " " + this._url + " (body: " + body + ")");
              return origXhrSend.apply(this, arguments);
            };
          }

          // 3. Expose window.tamperSetParam helper (syncs Backbone model visually)
          window.tamperSetParam = function(instance, port, value) {
            console.log("TAMPER_CALL: tamperSetParam(" + instance + ", " + port + ", " + value + ")");
            var numVal = parseFloat(value);
            var cleanName = (instance || '').split('/').pop();
            try {
              if (window.pedalboard && typeof window.pedalboard.get === 'function') {
                var pluginsColl = window.pedalboard.get('plugins');
                if (pluginsColl && typeof pluginsColl.each === 'function') {
                  pluginsColl.each(function(p) {
                    var inst = (typeof p.get === 'function') ? p.get('instance') : p.instance;
                    if (inst === instance || inst === '/graph/' + cleanName || inst === cleanName) {
                      if (typeof p.set_parameter === 'function') {
                        p.set_parameter(port, numVal);
                        console.log("TAMPER: set_parameter succeeded on Backbone model for " + instance);
                      }
                    }
                  });
                }
              }
            } catch(e) {
              console.error("TAMPER: Backbone set_parameter error: ", e);
            }
            return true;
          };

          // 4. Expose window.tamperSetBypass helper (syncs Backbone model visually)
          window.tamperSetBypass = function(instance, bypassed) {
            console.log("TAMPER_CALL: tamperSetBypass(" + instance + ", " + bypassed + ")");
            var intVal = bypassed ? 1 : 0;
            var cleanName = (instance || '').split('/').pop();
            try {
              if (window.pedalboard && typeof window.pedalboard.get === 'function') {
                var pluginsColl = window.pedalboard.get('plugins');
                if (pluginsColl && typeof pluginsColl.each === 'function') {
                  pluginsColl.each(function(p) {
                    var inst = (typeof p.get === 'function') ? p.get('instance') : p.instance;
                    if (inst === instance || inst === '/graph/' + cleanName || inst === cleanName) {
                      if (typeof p.set_bypass === 'function') {
                        p.set_bypass(!!bypassed);
                        console.log("TAMPER: set_bypass succeeded on Backbone model for " + instance);
                      } else if (typeof p.set_parameter === 'function') {
                        p.set_parameter(':bypass', intVal);
                      }
                    }
                  });
                }
              }
            } catch(e) {
              console.error("TAMPER: Backbone set_bypass error: ", e);
            }
            return true;
          };
        }

        function scrapeMetadata() {
          var plugins = [];
          
          // 1. Try Backbone.js first
          try {
            if (window.pedalboard && typeof window.pedalboard.get === 'function') {
              var pluginsColl = window.pedalboard.get('plugins');
              if (pluginsColl && typeof pluginsColl.each === 'function') {
                pluginsColl.each(function(plugin) {
                  var ports = [];
                  var controlPorts = typeof plugin.get === 'function' ? plugin.get('ports') : plugin.ports;
                  if (controlPorts && controlPorts.control && controlPorts.control.input) {
                    controlPorts.control.input.forEach(function(port) {
                      var sym = (typeof port.get === 'function' ? port.get('symbol') : port.symbol) || '';
                      if (!sym || sym === ':bypass' || sym === 'bypass') return;
                      
                      var name = (typeof port.get === 'function' ? port.get('name') : port.name) || sym;
                      var ranges = (typeof port.get === 'function' ? port.get('ranges') : port.ranges) || {};
                      var minVal = ranges.min !== undefined ? ranges.min : (typeof port.get === 'function' ? port.get('min') : port.min);
                      var maxVal = ranges.max !== undefined ? ranges.max : (typeof port.get === 'function' ? port.get('max') : port.max);
                      var stepVal = ranges.step !== undefined ? ranges.step : (typeof port.get === 'function' ? port.get('step') : port.step);
                      var isToggle = typeof port.get === 'function' ? port.get('is_toggle') : port.is_toggle;
                      
                      minVal = parseFloat(minVal);
                      if (isNaN(minVal)) minVal = 0.0;
                      maxVal = parseFloat(maxVal);
                      if (isNaN(maxVal)) maxVal = 1.0;
                      stepVal = parseFloat(stepVal);
                      if (isNaN(stepVal)) stepVal = 0.01;
                      
                      ports.push({
                        symbol: sym,
                        name: name,
                        min: minVal,
                        max: maxVal,
                        step: stepVal,
                        is_toggle: !!isToggle || (minVal === 0 && maxVal === 1 && stepVal === 1)
                      });
                    });
                  }
                  
                  var pluginName = typeof plugin.get === 'function' ? plugin.get('name') : plugin.name;
                  var pluginLabel = typeof plugin.get === 'function' ? plugin.get('label') : plugin.label;
                  
                  plugins.push({
                    instance: typeof plugin.get === 'function' ? plugin.get('instance') : plugin.instance,
                    uri: typeof plugin.get === 'function' ? plugin.get('uri') : plugin.uri,
                    name: pluginName || '',
                    label: pluginLabel || '',
                    ports: ports
                  });
                });
                if (plugins.length > 0) return JSON.stringify(plugins);
              }
            }
          } catch(e) {
            console.error("Backbone scraping failed: ", e);
          }

          // 2. Fallback: DOM scraping
          try {
            var pedalNodes = document.querySelectorAll('.mod-pedal');
            pedalNodes.forEach(function(pedalNode) {
              var instance = pedalNode.getAttribute('mod-instance');
              var uri = pedalNode.getAttribute('mod-uri') || '';
              if (!instance) return;
              
              var labelVal = '';
              var nameVal = '';
              var brandNode = pedalNode.querySelector('.mod-plugin-brand h1') || pedalNode.querySelector('.mod-pedal-title');
              if (brandNode) {
                labelVal = brandNode.textContent.trim();
                nameVal = labelVal;
              }
              
              var ports = [];
              var controlNodes = pedalNode.querySelectorAll('[mod-port]');
              controlNodes.forEach(function(controlNode) {
                var portSymbol = controlNode.getAttribute('mod-port-symbol');
                if (!portSymbol) {
                  var portAttr = controlNode.getAttribute('mod-port') || '';
                  portSymbol = portAttr.split('/').pop();
                }
                if (!portSymbol || portSymbol === ':bypass' || portSymbol === 'bypass') return;
                
                var minVal = 0.0;
                var maxVal = 1.0;
                var stepVal = 0.01;
                var isToggle = false;
                
                var settingsPanel = document.querySelector('.mod-settings[mod-instance="' + instance + '"]');
                if (settingsPanel) {
                  var inputControl = settingsPanel.querySelector('[mod-port-symbol="' + portSymbol + '"] input');
                  if (inputControl) {
                    minVal = parseFloat(inputControl.getAttribute('min')) || 0.0;
                    maxVal = parseFloat(inputControl.getAttribute('max')) || 1.0;
                    stepVal = parseFloat(inputControl.getAttribute('step')) || 0.01;
                  }
                }
                
                if (controlNode.classList.contains('mod-switch') || controlNode.classList.contains('mod-footswitch')) {
                  isToggle = true;
                  minVal = 0.0;
                  maxVal = 1.0;
                  stepVal = 1.0;
                }
                
                ports.push({
                  symbol: portSymbol,
                  name: portSymbol,
                  min: minVal,
                  max: maxVal,
                  step: stepVal,
                  is_toggle: isToggle
                });
              });
              
              plugins.push({
                instance: instance,
                uri: uri,
                name: nameVal,
                label: labelVal,
                ports: ports
              });
            });
          } catch(e) {
            console.error("DOM scraping failed: ", e);
          }
          
          return JSON.stringify(plugins);
        }

        if (window.discoveryIntervalId) {
          clearInterval(window.discoveryIntervalId);
        }
        window.discoveryIntervalId = setInterval(function() {
          try {
            var data = scrapeMetadata();
            if (data && window.DiscoveryChannel) {
              window.DiscoveryChannel.postMessage(data);
            }
          } catch(e) {}
        }, 3000);

        if (window.tamperMeterIntervalId) {
          clearInterval(window.tamperMeterIntervalId);
        }
        window.tamperMeterIntervalId = setInterval(function() {
          try {
            if (window.PedalMeterChannel) {
              var displays = {};
              document.querySelectorAll('.mod-pedal, [mod\\:instance], [data-instance]').forEach(function(el) {
                var inst = el.getAttribute('mod:instance') || (el.dataset && el.dataset.instance) || el.id;
                if (inst) {
                  var disp = el.querySelector('.mod-display, .mod-display-text, text.display, text, [class*="display"], [class*="meter"]');
                  if (disp) {
                    var t = (disp.textContent || disp.innerText || '').trim();
                    var n = parseFloat(t.replace(/[^0-9.-]/g, ''));
                    if (!isNaN(n)) displays[inst] = n;
                  }
                }
              });
              if (Object.keys(displays).length > 0) {
                window.PedalMeterChannel.postMessage(JSON.stringify(displays));
              }
            }
          } catch(e) {}
        }, 350);
      })();
    ''';

    try {
      _webViewController.runJavaScript(jsCode);
    } catch (e) {
      debugPrint('Error injecting discovery monitor: $e');
    }
  }

  void _injectPedalClickListener() {
    const String jsCode = r'''
      (function() {
        console.log("TAMPER: Ensuring interactive sub-pedal Hover Name Tag in WebView");

        function findPedalElementAndInstance(el) {
          if (!el) return null;
          let curr = el;
          // Upwards search up to 30 levels
          for (let i = 0; i < 30 && curr && curr !== document && curr !== window; i++) {
            if (curr.getAttribute) {
              const inst = curr.getAttribute('mod-instance') || (curr.dataset && curr.dataset.instance);
              if (inst) return { el: curr, inst: inst };
              const uri = curr.getAttribute('mod-uri');
              if (uri) {
                const child = curr.querySelector && curr.querySelector('[mod-instance], [data-instance]');
                if (child && child.getAttribute) {
                  const cInst = child.getAttribute('mod-instance') || (child.dataset && child.dataset.instance);
                  if (cInst) return { el: curr, inst: cInst };
                }
              }
            }
            if (curr.classList) {
              const cList = (typeof curr.className === 'string') ? curr.className : (curr.classList.value || '');
              if (cList.indexOf('mod-pedal') !== -1 || cList.indexOf('pedal') !== -1 || cList.indexOf('plugin') !== -1 || cList.indexOf('mod-plugin') !== -1) {
                const inst = (curr.getAttribute && curr.getAttribute('mod-instance')) || (curr.dataset && curr.dataset.instance);
                if (inst) return { el: curr, inst: inst };
              }
            }
            curr = curr.parentElement || curr.parentNode;
          }
          return null;
        }

        let hoverTag = document.getElementById('tamper-pedal-hover-tag');
        if (!hoverTag) {
          hoverTag = document.createElement('div');
          hoverTag.id = 'tamper-pedal-hover-tag';
          hoverTag.style.position = 'fixed';
          hoverTag.style.pointerEvents = 'auto';
          hoverTag.style.cursor = 'pointer';
          hoverTag.style.userSelect = 'none';
          hoverTag.style.zIndex = '2147483647'; // Max possible z-index
          hoverTag.style.padding = '6px 12px';
          hoverTag.style.borderRadius = '8px';
          hoverTag.style.backgroundColor = 'rgba(11, 14, 20, 0.95)';
          hoverTag.style.border = '1.5px solid #00FFCC';
          hoverTag.style.color = '#FFFFFF';
          hoverTag.style.fontFamily = 'system-ui, -apple-system, sans-serif';
          hoverTag.style.fontSize = '12px';
          hoverTag.style.fontWeight = 'bold';
          hoverTag.style.letterSpacing = '0.5px';
          hoverTag.style.boxShadow = '0 6px 22px rgba(0, 255, 204, 0.4), 0 0 12px rgba(0, 0, 0, 0.9)';
          hoverTag.style.opacity = '0';
          hoverTag.style.transition = 'opacity 0.2s ease, transform 0.15s ease, border-color 0.15s ease';
          hoverTag.style.transform = 'translate(-50%, 0)';
          hoverTag.style.whiteSpace = 'nowrap';
          hoverTag.style.display = 'flex';
          hoverTag.style.alignItems = 'center';
          hoverTag.style.gap = '6px';
          (document.body || document.documentElement).appendChild(hoverTag);
        }

        let currentActiveInst = '';
        let isHoveringTag = false;
        let fadeTimer = null;

        hoverTag.onmouseenter = function() {
          isHoveringTag = true;
          if (fadeTimer) {
            clearTimeout(fadeTimer);
            fadeTimer = null;
          }
          hoverTag.style.opacity = '1';
          hoverTag.style.transform = 'translate(-50%, -2px) scale(1.03)';
          hoverTag.style.borderColor = '#FFFFFF';
        };

        hoverTag.onmouseleave = function() {
          isHoveringTag = false;
          hoverTag.style.transform = 'translate(-50%, 0) scale(1.0)';
          hoverTag.style.borderColor = '#00FFCC';
          if (fadeTimer) clearTimeout(fadeTimer);
          fadeTimer = setTimeout(function() {
            if (!isHoveringTag) {
              hoverTag.style.opacity = '0';
            }
          }, 800);
        };

        function handleTagClick(e) {
          e.preventDefault();
          e.stopPropagation();
          if (e.stopImmediatePropagation) e.stopImmediatePropagation();
          if (currentActiveInst && window.PedalClickChannel) {
            console.log("TAMPER_TAG_CLICK_DISPATCH: " + currentActiveInst);
            window.PedalClickChannel.postMessage(currentActiveInst);
          }
        }

        ['click', 'pointerdown', 'mousedown', 'touchstart'].forEach(function(evt) {
          hoverTag.addEventListener(evt, handleTagClick, true);
        });

        function getPedalDetails(el, inst) {
          try {
            let title = '';
            let custom = '';
            let isPlaced = true;
            let categoryCode = 'FX';
            let categoryColor = '#00FFCC';
            let categoryEmoji = '🔊';
            if (window._tamperPedalTitles && typeof window._tamperPedalTitles === 'object' && inst) {
              const cleanInst = String(inst).replace(/^\/graph\//, '').replace(/^\//, '').toLowerCase();
              for (const [k, v] of Object.entries(window._tamperPedalTitles)) {
                if (!v) continue;
                const cleanK = String(k).replace(/^\/graph\//, '').replace(/^\//, '').toLowerCase();
                if (String(k).toLowerCase() === String(inst).toLowerCase() || cleanK === cleanInst || cleanK.endsWith(cleanInst) || cleanInst.endsWith(cleanK)) {
                  title = v.title || '';
                  custom = v.custom || '';
                  if (typeof v.isPlaced === 'boolean') isPlaced = v.isPlaced;
                  if (v.categoryCode) categoryCode = v.categoryCode;
                  if (v.categoryColor) categoryColor = '#' + v.categoryColor;
                  if (v.categoryEmoji) categoryEmoji = v.categoryEmoji;
                  break;
                }
              }
            }
            if (!title && el && el.getAttribute) {
              title = el.getAttribute('title') || el.getAttribute('data-name') || '';
            }
            if (!title && inst) {
              title = String(inst).split('/').pop().replace(/_/g, ' ');
            }
            
            let displayName = title || inst;
            if (custom && custom.trim().toUpperCase() !== title.trim().toUpperCase()) {
              displayName = title + ' / ' + custom;
            }
            return {
              displayName: displayName,
              isPlaced: isPlaced,
              categoryCode: categoryCode,
              categoryColor: categoryColor,
              categoryEmoji: categoryEmoji
            };
          } catch(err) {
            return { displayName: String(inst || ''), isPlaced: true, categoryCode: 'FX', categoryColor: '#00FFCC', categoryEmoji: '🔊' };
          }
        }

        function handlePointerMove(e) {
          try {
            if (isHoveringTag) return;
            if (e.target === hoverTag || (hoverTag && hoverTag.contains && hoverTag.contains(e.target))) return;

            const targetPedal = findPedalElementAndInstance(e.target);

            if (targetPedal) {
              const pedalEl = targetPedal.el;
              const inst = targetPedal.inst;
              currentActiveInst = inst;
              const details = getPedalDetails(pedalEl, inst);
              
              const catEmoji = details.categoryEmoji || '🧩';
              const catCode = details.categoryCode || 'FX';
              const catColor = details.categoryColor || '#00FFCC';
              const statusIcon = details.isPlaced ? '🧩' : '📦';
              const statusLabel = details.isPlaced ? 'PLACED' : 'AVAILABLE POOL';
              const statusColor = details.isPlaced ? '#00FFCC' : '#FFAA00';
              const statusBg = details.isPlaced ? 'rgba(0,255,204,0.18)' : 'rgba(255,170,0,0.18)';
              const statusBorder = details.isPlaced ? 'rgba(0,255,204,0.5)' : 'rgba(255,170,0,0.5)';

              hoverTag.innerHTML = `
                <span style="font-size:15px;line-height:1;margin-right:2px;">${catEmoji}</span>
                <span style="color:#FFFFFF;font-weight:bold;">${details.displayName.toUpperCase()}</span>
                <span style="background:rgba(255,255,255,0.1);color:${catColor};border:1px solid ${catColor};border-radius:4px;padding:2px 5px;font-size:8.5px;font-weight:900;letter-spacing:0.5px;">${catCode}</span>
                <span style="background:${statusBg};color:${statusColor};border:1px solid ${statusBorder};border-radius:4px;padding:2px 5px;font-size:8px;font-weight:900;letter-spacing:0.5px;">${statusIcon} ${statusLabel}</span>
              `;
              
              // Position directly below the pedal visual
              const rect = pedalEl.getBoundingClientRect();
              const centerX = rect.left + (rect.width / 2);
              const bottomY = rect.bottom + 6; // 6px below bottom of pedal visual

              if (bottomY + 38 > window.innerHeight) {
                hoverTag.style.top = Math.max(6, rect.top - 38) + 'px';
              } else {
                hoverTag.style.top = bottomY + 'px';
              }
              hoverTag.style.left = Math.max(30, Math.min(window.innerWidth - 30, centerX)) + 'px';
              hoverTag.style.opacity = '1';

              // While hovering pedal: keep it visible permanently!
              if (fadeTimer) {
                clearTimeout(fadeTimer);
                fadeTimer = null;
              }
            } else {
              // Not on a pedal: give 1.5 seconds to move to tag or fade out
              if (!fadeTimer && !isHoveringTag) {
                fadeTimer = setTimeout(function() {
                  if (!isHoveringTag) {
                    hoverTag.style.opacity = '0';
                  }
                  fadeTimer = null;
                }, 1500);
              }
            }
          } catch(err) {
            console.error('Tamper pointer move error:', err);
          }
        }

        if (!window._hasBoundPedalHoverEvents) {
          window._hasBoundPedalHoverEvents = true;
          ['pointermove', 'mousemove', 'pointerover', 'mouseover'].forEach(function(type) {
            window.addEventListener(type, handlePointerMove, { capture: true, passive: true });
            document.addEventListener(type, handlePointerMove, { capture: true, passive: true });
          });
        }
      })();
    ''';

    try {
      _webViewController.runJavaScript(jsCode);
    } catch (e) {
      debugPrint('Error injecting pedal click listener: $e');
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
  final Map<String, bool?> _fadeDirections =
      {}; // true for Fade In, false for Fade Out
  final Map<String, bool> _fadePaused = {};
  final Map<String, int> _fadeCurrentStep = {};
  final Map<String, int> _fadeTotalSteps = {};
  final Map<String, double> _fadeStartVal = {};
  final Map<String, double> _fadeTargetVal = {};
  final Map<String, Curve> _fadeActiveCurve = {};

  // Tap-tempo times keeper
  final List<DateTime> _tapTimes = [];

  // User custom display titles for plugin cards (renaming support)
  final Map<String, String> _customTitles = {};

  // Custom regular card visible parameters for unrecognized devices
  final Map<String, List<String>> _customCardVisibleParams = {};

  // Custom compact card visible parameters for unrecognized devices
  final Map<String, List<String>> _customCardVisibleCompactParams = {};

  // Switch card configuration maps
  final Map<String, String> _switchModes = {}; // 'toggle' or 'route'
  final Map<String, String> _switchPathANames = {}; // Path A name (0.0/Down)
  final Map<String, String> _switchPathBNames = {}; // Path B name (1.0/Up)
  final Map<String, bool> _switchInverted = {}; // false: 1=ON, true: 0=ON

  // Gain card configuration maps
  final Map<String, String> _gainCardModes = {}; // 'fade' or 'direct'

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
      ..setOnConsoleMessage((JavaScriptConsoleMessage consoleMessage) {
        debugPrint('WEBVIEW CONSOLE [${consoleMessage.level.name}]: ${consoleMessage.message}');
      })
      ..addJavaScriptChannel(
        'DiscoveryChannel',
        onMessageReceived: (JavaScriptMessage message) {
          _handleDiscoveryData(message.message);
        },
      )
      ..addJavaScriptChannel(
        'PedalClickChannel',
        onMessageReceived: (JavaScriptMessage message) {
          final String instanceId = message.message.trim();
          if (instanceId.isNotEmpty) {
            _handlePedalSearchClick(instanceId);
          }
        },
      )
      ..addJavaScriptChannel(
        'PedalMeterChannel',
        onMessageReceived: (JavaScriptMessage message) {
          try {
            final Map<String, dynamic> decoded = jsonDecode(message.message);
            bool updated = false;
            decoded.forEach((k, v) {
              final double? numVal = double.tryParse(v.toString());
              if (numVal != null) {
                final String cleanKey = k.startsWith('/') ? k : '/graph/$k';
                if (_scrapedPedalDisplays[cleanKey] != numVal || _scrapedPedalDisplays[k] != numVal) {
                  _scrapedPedalDisplays[cleanKey] = numVal;
                  _scrapedPedalDisplays[k] = numVal;
                  updated = true;
                }
              }
            });
            if (updated && mounted) {
              setState(() {});
            }
          } catch (e) {
            // Ignore parse errors
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
            // Inject Metadata discovery scraper
            _injectMetadataDiscovery();
            // Inject Pedal Click Interceptor
            _injectPedalClickListener();
          },
        ),
      );

    // Load initial URL
    _webViewController.loadRequest(Uri.parse('http://${_ipController.text}'));

    // Load saved theme settings and IP
    _loadThemeSettings();
    _loadSavedIp();

    // Connect automatically on launch
    _webSocketService.connect(ip: _ipController.text);

    // Listen to value changes to update local volume values and BPM initially
    _webSocketService.gainPedals.addListener(_initializeLocalVolumes);
    _webSocketService.bpm.addListener(_updateBpmFromService);
    _webSocketService.allPlugins.addListener(_syncOrderedPlugins);

    // Global keyboard listener (Ctrl+S / Cmd+S copy JSON backup)
    HardwareKeyboard.instance.addHandler(_handleGlobalKeyEvents);
  }

  void _initializeLocalVolumes() {
    final gains = _webSocketService.gainPedals.value;
    for (var pedal in gains) {
      if (pedal.gainPortSymbol != null) {
        final double? serverValue = pedal.parameters[pedal.gainPortSymbol];
        if (serverValue != null && (_fadeTimers[pedal.instance] == null) && !_mutedVolumes.containsKey(pedal.instance)) {
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
      String effectiveKey = key;
      List<String>? savedOrder = prefs.getStringList('${key}_order');

      // Lenient matching: if current exact pedalboard key has no saved order,
      // find the most similar saved pedalboard layout configuration and inherit its settings!
      if (savedOrder == null) {
        final matchingKey = _findBestMatchingPedalboardKey(prefs, currentIds);
        if (matchingKey != null) {
          effectiveKey = matchingKey;
          savedOrder = prefs.getStringList('${effectiveKey}_order');
          debugPrint('Lenient matching: inherited layout from $matchingKey for $key');
        }
      }

      final List<String>? savedEnabled = prefs.getStringList('${effectiveKey}_enabled');
      final String? savedColorsJson = prefs.getString('${effectiveKey}_colors');
      final String? savedSizesJson = prefs.getString('${effectiveKey}_sizes');
      final String? savedTitlesJson = prefs.getString('${effectiveKey}_custom_titles');
      final String? savedGlowEnabledJson = prefs.getString('${effectiveKey}_glow_enabled');
      final int? savedFadeBars = prefs.getInt('${effectiveKey}_fade_bars');
      final String? savedCustomVisibleParamsJson = prefs.getString('${effectiveKey}_custom_card_visible_params');
      final String? savedCustomVisibleCompactParamsJson = prefs.getString('${effectiveKey}_custom_card_visible_compact_params');
      final String? savedSwitchModesJson = prefs.getString('${effectiveKey}_switch_modes');
      final String? savedSwitchPathANamesJson = prefs.getString('${effectiveKey}_switch_path_a_names');
      final String? savedSwitchPathBNamesJson = prefs.getString('${effectiveKey}_switch_path_b_names');
      final String? savedSwitchInvertedJson = prefs.getString('${effectiveKey}_switch_inverted');
      final String? savedGainCardModesJson = prefs.getString('${effectiveKey}_gain_card_modes');
      final String? savedFadeStart = prefs.getString('${effectiveKey}_fadeRangeStart');
      final String? savedFadeEnd = prefs.getString('${effectiveKey}_fadeRangeEnd');
      final String? savedFadeShapes = prefs.getString('${effectiveKey}_fadeShapes');
      final String? savedFadeCustom = prefs.getString('${effectiveKey}_fadeCustomParams');
      final String? savedFadeCustomOut = prefs.getString('${effectiveKey}_fadeCustomParamsOut');

      // 1. Order
      List<String> newOrder = [];
      if (savedOrder != null) {
        for (final id in savedOrder) {
          if (currentIds.contains(id) || id.startsWith('__spacer_') || id.startsWith('__linebreak_')) {
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
            .where((id) => currentIds.contains(id) || id.startsWith('__spacer_') || id.startsWith('__linebreak_'))
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

      // 5.5. Custom Card Visible Params
      final Map<String, List<String>> newCustomVisibleParams = {};
      if (savedCustomVisibleParamsJson != null) {
        try {
          final Map<String, dynamic> decoded = jsonDecode(savedCustomVisibleParamsJson);
          decoded.forEach((k, v) {
            if (v is List) {
              newCustomVisibleParams[k] = List<String>.from(v.map((e) => e.toString()));
            }
          });
        } catch (e) {
          debugPrint('Error decoding custom_card_visible_params: $e');
        }
      }

      // 5.6. Custom Compact Card Visible Params
      final Map<String, List<String>> newCustomVisibleCompactParams = {};
      if (savedCustomVisibleCompactParamsJson != null) {
        try {
          final Map<String, dynamic> decoded = jsonDecode(savedCustomVisibleCompactParamsJson);
          decoded.forEach((k, v) {
            if (v is List) {
              newCustomVisibleCompactParams[k] = List<String>.from(v.map((e) => e.toString()));
            }
          });
        } catch (e) {
          debugPrint('Error decoding custom_card_visible_compact_params: $e');
        }
      }

      // 5.7. Switch Configs
      final Map<String, String> newSwitchModes = {};
      if (savedSwitchModesJson != null) {
        try {
          final Map<String, dynamic> decoded = jsonDecode(savedSwitchModesJson);
          decoded.forEach((k, v) => newSwitchModes[k] = v.toString());
        } catch (e) {
          debugPrint('Error decoding switch_modes: $e');
        }
      }

      final Map<String, String> newSwitchPathANames = {};
      if (savedSwitchPathANamesJson != null) {
        try {
          final Map<String, dynamic> decoded = jsonDecode(savedSwitchPathANamesJson);
          decoded.forEach((k, v) => newSwitchPathANames[k] = v.toString());
        } catch (e) {
          debugPrint('Error decoding switch_path_a_names: $e');
        }
      }

      final Map<String, String> newSwitchPathBNames = {};
      if (savedSwitchPathBNamesJson != null) {
        try {
          final Map<String, dynamic> decoded = jsonDecode(savedSwitchPathBNamesJson);
          decoded.forEach((k, v) => newSwitchPathBNames[k] = v.toString());
        } catch (e) {
          debugPrint('Error decoding switch_path_b_names: $e');
        }
      }

      final Map<String, bool> newSwitchInverted = {};
      if (savedSwitchInvertedJson != null) {
        try {
          final Map<String, dynamic> decoded = jsonDecode(savedSwitchInvertedJson);
          decoded.forEach((k, v) => newSwitchInverted[k] = v == true);
        } catch (e) {
          debugPrint('Error decoding switch_inverted: $e');
        }
      }

      // 5.8. Gain Card Modes ('fade' or 'direct')
      final Map<String, String> newGainCardModes = {};
      if (savedGainCardModesJson != null) {
        try {
          final Map<String, dynamic> decoded = jsonDecode(savedGainCardModesJson);
          decoded.forEach((k, v) => newGainCardModes[k] = v.toString());
        } catch (e) {
          debugPrint('Error decoding gain_card_modes: $e');
        }
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
      final Map<String, double> newFadeStart = {};
      final Map<String, double> newFadeEnd = {};
      final Map<String, String> newFadeShapes = {};
      final Map<String, Map<String, double>> newFadeCustomParams = {};
      final Map<String, Map<String, double>> newFadeCustomParamsOut = {};

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
      final String? savedCustomPresets = prefs.getString('custom_curve_presets');
      final Map<String, Map<String, double>> newCustomPresets = {};
      if (savedCustomPresets != null) {
        final Map<String, dynamic> outer = jsonDecode(savedCustomPresets);
        outer.forEach((k, v) {
          final Map<String, dynamic> inner = jsonDecode(v.toString());
          newCustomPresets[k] = inner.map(
            (ik, iv) => MapEntry(ik, (iv as num).toDouble()),
          );
        });
      }
      if (savedFadeCustomOut != null) {
        final Map<String, dynamic> outer = jsonDecode(savedFadeCustomOut);
        outer.forEach((k, v) {
          final Map<String, dynamic> inner = jsonDecode(v.toString());
          newFadeCustomParamsOut[k] = inner.map(
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

          _customCardVisibleParams.clear();
          _customCardVisibleParams.addAll(newCustomVisibleParams);

          _customCardVisibleCompactParams.clear();
          _customCardVisibleCompactParams.addAll(newCustomVisibleCompactParams);

          _switchModes.clear();
          _switchModes.addAll(newSwitchModes);

          _switchPathANames.clear();
          _switchPathANames.addAll(newSwitchPathANames);

          _switchPathBNames.clear();
          _switchPathBNames.addAll(newSwitchPathBNames);

          _switchInverted.clear();
          _switchInverted.addAll(newSwitchInverted);

          _gainCardModes.clear();
          _gainCardModes.addAll(newGainCardModes);

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
          _fadeCustomParamsOut.clear();
          _fadeCustomParamsOut.addAll(newFadeCustomParamsOut);
          _savedCustomCurvePresets.clear();
          _savedCustomCurvePresets.addAll(newCustomPresets);

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
        final inParams = _fadeCustomParams[pedal.instance] ??
            {'h1x': 0.25, 'h1y': 0.1, 'mx': 0.5, 'my': 0.5, 'h2x': 0.75, 'h2y': 0.9};
        final outParams = _fadeCustomParamsOut[pedal.instance] ??
            VectorBezierCurve.mirror(inParams);
        selectedCurve =
            VectorBezierCurve.fromMap(fadeIn ? inParams : outParams);
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

    _fadeCurrentStep[pedal.instance] = currentStep;
    _fadeTotalSteps[pedal.instance] = totalSteps;
    _fadeStartVal[pedal.instance] = startVal;
    _fadeTargetVal[pedal.instance] = targetEndValue;
    _fadeActiveCurve[pedal.instance] = selectedCurve;
    _fadePaused[pedal.instance] = false;

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
        _fadeCurrentStep[pedal.instance] = currentStep;
        if (currentStep >= totalSteps) {
          setState(() {
            _localVolumes[pedal.instance] = targetEndValue;
            _fadeTimers[pedal.instance] = null;
            _fadePaused[pedal.instance] = false;
            _fadeProgress[pedal.instance] = 0.0;
            _fadeDirections[pedal.instance] = null;
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

  void _stopFade(PluginInstance pedal) {
    _fadeTimers[pedal.instance]?.cancel();
    setState(() {
      _fadeTimers[pedal.instance] = null;
      _fadePaused[pedal.instance] = false;
      _fadeProgress[pedal.instance] = 0.0;
      _fadeDirections[pedal.instance] = null;
    });
  }

  void _pauseResumeFade(PluginInstance pedal) {
    final bool isPaused = _fadePaused[pedal.instance] ?? false;
    if (!isPaused) {
      // Pause active timer
      _fadeTimers[pedal.instance]?.cancel();
      setState(() {
        _fadeTimers[pedal.instance] = null;
        _fadePaused[pedal.instance] = true;
      });
    } else {
      // Resume from current step
      setState(() {
        _fadePaused[pedal.instance] = false;
      });
      final int totalSteps = _fadeTotalSteps[pedal.instance] ?? 100;
      int currentStep = _fadeCurrentStep[pedal.instance] ?? 0;
      final double startVal = _fadeStartVal[pedal.instance] ?? 0.0;
      final double targetEndValue = _fadeTargetVal[pedal.instance] ?? 0.0;
      final Curve selectedCurve = _fadeActiveCurve[pedal.instance] ?? Curves.easeInOut;

      _fadeTimers[pedal.instance] = Timer.periodic(
        const Duration(milliseconds: 50),
        (timer) {
          if (!mounted) {
            timer.cancel();
            return;
          }
          currentStep++;
          _fadeCurrentStep[pedal.instance] = currentStep;
          if (currentStep >= totalSteps) {
            setState(() {
              _localVolumes[pedal.instance] = targetEndValue;
              _fadeTimers[pedal.instance] = null;
              _fadePaused[pedal.instance] = false;
              _fadeProgress[pedal.instance] = 0.0;
              _fadeDirections[pedal.instance] = null;
            });
            if (pedal.gainPortSymbol != null) {
              _webSocketService.setParamValue(
                instance: pedal.instance,
                port: pedal.gainPortSymbol!,
                value: double.parse(targetEndValue.toStringAsFixed(2)),
              );
            }
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
            if (pedal.gainPortSymbol != null) {
              _webSocketService.setParamValue(
                instance: pedal.instance,
                port: pedal.gainPortSymbol!,
                value: double.parse(intermediateVal.toStringAsFixed(2)),
              );
            }
          }
        },
      );
    }
  }

  /// Checks for active WiFi before connecting.
  ///
  /// WiFi prevents the system from routing traffic to the USB Ethernet
  /// interface used to reach the MOD Dwarf (192.168.51.x). If WiFi is
  /// detected as the active connection type, a warning is shown before
  /// proceeding. The user should disable WiFi and reconnect.
  /// If connected via Chromebook bridge (100.115.92.x), a helper banner is shown.
  Future<void> _connectWithWifiCheck() async {
    final List<ConnectivityResult> results = await Connectivity()
        .checkConnectivity();
    final bool wifiActive = results.contains(ConnectivityResult.wifi);
    final String targetIp = _ipController.text.trim();
    final bool isDirectUsbIp = targetIp.startsWith('192.168.51.');
    final bool isChromebookBridgeIp = targetIp.startsWith('100.115.92.');

    if (wifiActive && isDirectUsbIp && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 8),
          backgroundColor: const Color(0xFFCC6600),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: Color(0xFFFF9900), width: 1.5),
          ),
          content: InkWell(
            onTap: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
            },
            child: const Row(
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
                SizedBox(width: 8),
                Icon(Icons.close, color: Colors.white70, size: 18),
              ],
            ),
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
    } else if (isChromebookBridgeIp && mounted) {
      _showBridgeInstructionsBanner();
    }

    // Proceed with connection regardless — user may have WiFi on for other
    // reasons and still wants to try (e.g. WiFi on but already disabled
    // for routing before this check ran).
    _saveIp(targetIp);
    _webSocketService.connect(ip: _ipController.text);
    _webViewController.loadRequest(Uri.parse('http://${_ipController.text}'));
  }

  /// Displays an orange helper banner explaining the Chromebook / Crostini bridge,
  /// with a button to copy `./scripts/bridge_dwarf.sh` to clipboard.
  void _showBridgeInstructionsBanner() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
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
        content: InkWell(
          onTap: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
          child: const Row(
            children: [
              Icon(Icons.terminal, color: Colors.white, size: 22),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '🌉 Chromebook Bridge Mode (Wi-Fi is OK)',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Run ./scripts/bridge_dwarf.sh in Crostini Linux terminal.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8),
              Icon(Icons.close, color: Colors.white70, size: 18),
            ],
          ),
        ),
        action: SnackBarAction(
          label: 'COPY CMD',
          textColor: const Color(0xFF00FFCC),
          onPressed: () {
            Clipboard.setData(
              const ClipboardData(text: './scripts/bridge_dwarf.sh'),
            );
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                duration: const Duration(seconds: 3),
                backgroundColor: const Color(0xFF1E2638),
                behavior: SnackBarBehavior.floating,
                margin: const EdgeInsets.all(12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: const BorderSide(color: Color(0xFF00FFCC), width: 1),
                ),
                content: const Row(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      color: Color(0xFF00FFCC),
                      size: 20,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Copied to clipboard: ./scripts/bridge_dwarf.sh\nPaste & run in Linux terminal.',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
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
    _highlightTimer?.cancel();
    _flashStrobeTimer?.cancel();
    HardwareKeyboard.instance.removeHandler(_handleGlobalKeyEvents);
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

  bool _handleGlobalKeyEvents(KeyEvent event) {
    if (event is KeyDownEvent) {
      final bool isCtrlOrCmd = HardwareKeyboard.instance.isControlPressed ||
          HardwareKeyboard.instance.isMetaPressed;
      if (isCtrlOrCmd) {
        if (event.logicalKey == LogicalKeyboardKey.keyS) {
          _copyCurrentJsonBackupShortcut();
          return true;
        } else if (event.logicalKey == LogicalKeyboardKey.keyV) {
          final focusedWidget =
              FocusManager.instance.primaryFocus?.context?.widget;
          if (focusedWidget is! EditableText) {
            _pasteCurrentJsonBackupShortcut();
            return true;
          }
        }
      }
    }
    return false;
  }

  Future<void> _pasteCurrentJsonBackupShortcut() async {
    try {
      final clipboardData = await Clipboard.getData('text/plain');
      final text = clipboardData?.text?.trim() ?? '';
      if (text.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Clipboard is empty!'),
              backgroundColor: Color(0xFFFF007F),
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }

      final Map<String, dynamic> decoded = jsonDecode(text);
      if (decoded.isEmpty ||
          !decoded.keys.any((k) => k.startsWith('pedalboard_'))) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Clipboard does not contain a valid TamperMod JSON configuration.',
              ),
              backgroundColor: Color(0xFFFF007F),
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }

      if (!mounted) return;
      final bool? confirm = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            backgroundColor:
                _isDarkMode ? const Color(0xFF0F141C) : Colors.white,
            title: const Text(
              'CONFIRM RESTORE (Ctrl+V)',
              style: TextStyle(
                color: Color(0xFFFF007F),
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            content: const Text(
              'A valid TamperMod layout configuration was found in the clipboard. Do you want to apply and restore it now?',
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
                  'APPLY & RESTORE',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          );
        },
      );

      if (confirm != true || !mounted) return;

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
          await prefs.setStringList(
            key,
            val.map((e) => e.toString()).toList(),
          );
        }
      }
      await _syncAndLoadLayoutSettings();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.check_circle_outline, color: Colors.black, size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Layout configurations restored from clipboard! (Ctrl+V)',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Colors.black,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF00FFCC),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error restoring JSON via Ctrl+V shortcut: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error restoring JSON: $e'),
            backgroundColor: const Color(0xFFFF007F),
          ),
        );
      }
    }
  }

  Future<void> _copyCurrentJsonBackupShortcut() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final Set<String> keys = prefs.getKeys();
      final Map<String, dynamic> backupData = {};
      for (final key in keys) {
        if (key.startsWith('pedalboard_') ||
            key == 'is_dark_mode' ||
            key == 'custom_curve_presets') {
          backupData[key] = prefs.get(key);
        }
      }
      final jsonStr = jsonEncode(backupData);
      await Clipboard.setData(ClipboardData(text: jsonStr));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.check_circle_outline, color: Colors.black, size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'JSON configuration copied to clipboard! (Ctrl+S)',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Colors.black,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF00FFCC),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error copying JSON via shortcut: $e');
    }
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
                activeCount: _enabledPluginInstances.where((id) => !id.startsWith('__spacer_') && !id.startsWith('__linebreak_')).length,
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
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () {
                    setState(() {
                      _showConnectionPanel = !_showConnectionPanel;
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Column(
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
                                      ).withValues(alpha: 0.85),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Tooltip(
                  message: _showConnectionPanel
                      ? 'Fold Connection Setup bar'
                      : 'Unfold Connection Setup bar',
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _showConnectionPanel = !_showConnectionPanel;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
                      decoration: BoxDecoration(
                        color: _showConnectionPanel
                            ? (_isDarkMode
                                ? const Color(0xFF00FFCC).withValues(alpha: 0.15)
                                : const Color(0xFF00B3FF).withValues(alpha: 0.15))
                            : Colors.transparent,
                        border: Border.all(
                          color: _showConnectionPanel
                              ? (_isDarkMode
                                  ? const Color(0xFF00FFCC).withValues(alpha: 0.4)
                                  : const Color(0xFF00B3FF).withValues(alpha: 0.4))
                              : (_isDarkMode ? Colors.white24 : Colors.black26),
                          width: 1,
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.cable,
                            color: _showConnectionPanel
                                ? (_isDarkMode
                                    ? const Color(0xFF00FFCC)
                                    : const Color(0xFF00B3FF))
                                : (_isDarkMode ? Colors.grey[400] : Colors.grey[700]),
                            size: 15,
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            _showConnectionPanel
                                ? Icons.expand_less
                                : Icons.expand_more,
                            size: 14,
                            color: _showConnectionPanel
                                ? (_isDarkMode
                                    ? const Color(0xFF00FFCC)
                                    : const Color(0xFF00B3FF))
                                : (_isDarkMode ? Colors.grey[400] : Colors.grey[700]),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // View Mode Chips in AppBar
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildAppBarViewChip(
                      label: 'TILES',
                      isSelected: _showControls && !_showWeb,
                      onTap: () {
                        setState(() {
                          _showControls = true;
                          _showWeb = false;
                        });
                      },
                    ),
                    const SizedBox(width: 3),
                    _buildAppBarViewChip(
                      label: 'SPLIT',
                      isSelected: _showControls && _showWeb,
                      onTap: () {
                        setState(() {
                          _showControls = true;
                          _showWeb = true;
                        });
                      },
                    ),
                    const SizedBox(width: 3),
                    _buildAppBarViewChip(
                      label: 'WEB',
                      isSelected: !_showControls && _showWeb,
                      onTap: () {
                        setState(() {
                          _showControls = false;
                          _showWeb = true;
                        });
                      },
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

              // Open/close inline puzzle organizer panel
              IconButton(
                icon: Icon(
                  _isPuzzleOpen ? Icons.extension : Icons.extension_outlined,
                  color: const Color(0xFFFF007F),
                  size: 22,
                ),
                tooltip: 'Puzzle Organizer',
                onPressed: () {
                  setState(() {
                    _isPuzzleOpen = !_isPuzzleOpen;
                  });
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
            child: Row(
              children: [
                // Main content column (shrinks when puzzle panel is open)
                Expanded(
                  child: Column(
                    children: [
                      // Collapsible Toolbar & Connection Setup Bars (Folds both rows)
                      AnimatedSize(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOut,
                        child: _showConnectionPanel
                            ? Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Toolbar (View selectors, Radar, Reload, Theme, Version)
                                  BottomToolbar(
                                    isDarkMode: _isDarkMode,
                                    showControls: _showControls,
                                    showWeb: _showWeb,
                                    isConnected:
                                        _webSocketService.status ==
                                        ConnectionStatus.connected,
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
                                    onIpSelected: (selectedIp) {
                                      _saveIp(selectedIp);
                                      if (selectedIp.startsWith('100.115.92.')) {
                                        _showBridgeInstructionsBanner();
                                      }
                                    },
                                  ),
                                ],
                              )
                            : const SizedBox.shrink(),
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

                // Inline Puzzle Organizer panel — slides in from the right,
                // narrows only the tile board (controls), never touches the WebView.
                // AnimatedAlign + widthFactor avoids OverflowBox layout errors.
                ClipRect(
                  child: AnimatedAlign(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeInOut,
                    alignment: Alignment.centerRight,
                    widthFactor: _isPuzzleOpen ? 1.0 : 0.0,
                    child: SizedBox(
                      width: 270,
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border(
                            left: BorderSide(
                              color: _isDarkMode
                                  ? const Color(0xFFFF007F)
                                  : const Color(0xFFCC0055),
                              width: 1.5,
                            ),
                          ),
                        ),
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
                            setState(() {});
                            _updateAllGlowsInWebView();
                            _saveLayoutSettings();
                          },
                          onHighlightPedal: (pedal) =>
                              _triggerSearchHighlight(pedal.instance, pedal: pedal),
                          onShowColorPicker: _showColorPickerDialog,
                          onCyclePedalSize: _cyclePedalSize,
                          onScrollToCard: _scrollToCard,
                          onBackupRestore: _showBackupRestoreDialog,
                          onAddSpacer: _addSpacer,
                          onDeleteSpacer: _deleteSpacer,
                          onAddLineBreak: _addLineBreak,
                          onDeleteLineBreak: _deleteLineBreak,
                          highlightedInstanceId: _highlightedInstanceId,
                          isFlashStateOn: _isFlashStateOn,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBodyContent(bool isLandscape) {
    if (!_showControls && !_showWeb) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('No view mode selected', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => setState(() => _showControls = true),
              child: const Text('SHOW TILES'),
            ),
          ],
        ),
      );
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
      final String targetIp = _ipController.text.trim();
      final bool isBridge = targetIp.startsWith('100.115.92.');

      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF007F).withOpacity(0.12),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFFF007F).withOpacity(0.4),
                    width: 1.5,
                  ),
                ),
                child: const Icon(
                  Icons.link_off,
                  size: 48,
                  color: Color(0xFFFF007F),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Not connected to MOD Dwarf',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Target IP: $targetIp',
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 20),

              // Troubleshooting advice card
              Container(
                constraints: const BoxConstraints(maxWidth: 480),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _isDarkMode
                      ? const Color(0xFF141A24)
                      : Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _isDarkMode ? Colors.grey[800]! : Colors.grey[400]!,
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.lightbulb_outline, size: 18, color: Color(0xFF00FFCC)),
                        const SizedBox(width: 8),
                        Text(
                          isBridge
                              ? 'Chromebook Bridge Troubleshooting'
                              : 'Connection Troubleshooting',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF00FFCC),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      isBridge
                          ? '1. Ensure the bridge script is active in Crostini Linux terminal.\n'
                            '2. If ChromeOS Wi-Fi or network changed, Android network routing may stall. Run the reset command below in terminal:'
                          : '1. Ensure MOD Dwarf is connected via USB.\n'
                            '2. Turn off Wi-Fi if using direct USB IP (192.168.51.1).',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: _isDarkMode ? Colors.grey[300] : Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Copy Network Reset Command Button
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00FFCC).withOpacity(0.15),
                        foregroundColor: const Color(0xFF00FFCC),
                        side: const BorderSide(color: Color(0xFF00FFCC)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      icon: const Icon(Icons.copy, size: 16),
                      label: const Text(
                        'COPY ANDROID NETWORK FIX COMMAND',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () {
                        Clipboard.setData(const ClipboardData(
                          text: 'adb shell "svc wifi disable; sleep 1; svc wifi enable"',
                        ));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text(
                              'Copied: adb shell "svc wifi disable; sleep 1; svc wifi enable"',
                              style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                            ),
                            backgroundColor: const Color(0xFF00FFCC),
                            behavior: SnackBarBehavior.floating,
                            duration: const Duration(seconds: 4),
                          ),
                        );
                      },
                    ),
                    if (isBridge) ...[
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber.withOpacity(0.12),
                          foregroundColor: Colors.amber,
                          side: const BorderSide(color: Colors.amber),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        icon: const Icon(Icons.terminal, size: 16),
                        label: const Text(
                          'COPY BRIDGE SCRIPT COMMAND',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        onPressed: () {
                          Clipboard.setData(const ClipboardData(
                            text: './scripts/bridge_dwarf.sh',
                          ));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Copied: ./scripts/bridge_dwarf.sh',
                                style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                              ),
                              backgroundColor: Colors.amber,
                              behavior: SnackBarBehavior.floating,
                              duration: Duration(seconds: 4),
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF007F),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text(
                  'RETRY CONNECTION',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                onPressed: _connectWithWifiCheck,
              ),
            ],
          ),
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
            if (instanceId.startsWith('__spacer_')) {
              enabledPlugins.add(PluginInstance(
                instance: instanceId,
                uri: 'spacer',
                title: 'SPACER',
              ));
              continue;
            }
            if (instanceId.startsWith('__linebreak_')) {
              enabledPlugins.add(PluginInstance(
                instance: instanceId,
                uri: 'linebreak',
                title: 'LINE BREAK',
              ));
              continue;
            }
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
          if (plugins.isNotEmpty) {
            enabledPlugins.addAll(plugins);
          } else {
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
                  final bool isSpacer = pedal.instance.startsWith('__spacer_');
                  final bool isLineBreak = pedal.instance.startsWith('__linebreak_');
                  final uriLower = pedal.uri.toLowerCase();
                  final titleLower = pedal.title.toLowerCase();
                  final isLooper =
                      uriLower.contains('alo') || titleLower.contains('alo');
                  final isSwitch =
                      uriLower.contains('switch') ||
                      titleLower.contains('switch');
                  final isGainOrVolume =
                      uriLower.contains('gain') ||
                      uriLower.contains('volume') ||
                      uriLower.contains('amp') ||
                      titleLower.contains('gain') ||
                      titleLower.contains('volume');

                  double cardWidth = regularWidth;
                  double? cardHeight = 240.0;

                  if (isLineBreak) {
                    cardWidth = availableWidth;
                    cardHeight = 18.0;
                  } else if (isSpacer) {
                    if (size == 'compact') {
                      cardWidth = compactWidth;
                      cardHeight = 240.0;
                    } else if (size == 'regular') {
                      cardWidth = regularWidth;
                      cardHeight = 240.0;
                    } else {
                      cardWidth = expandedWidth;
                      cardHeight = 240.0;
                    }
                  } else if (isLooper) {
                    // ALO loopers: check size setting
                    if (size == 'regular') {
                      cardWidth = regularWidth;
                      cardHeight = 240.0;
                    } else {
                      // Default to expanded mode
                      cardWidth = expandedWidth;
                      cardHeight = null; // Auto-expand to fit all content
                    }
                  } else if (isSwitch) {
                    if (size == 'compact') {
                      cardWidth = compactWidth;
                      cardHeight = 240.0;
                    } else if (size == 'regular') {
                      cardWidth = regularWidth;
                      cardHeight = 240.0;
                    } else {
                      cardWidth = expandedWidth;
                      cardHeight = 240.0;
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

                  if (isLineBreak) {
                    cardWidget = Container(
                      width: availableWidth,
                      height: 18.0,
                      alignment: Alignment.center,
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 1.0,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.transparent,
                                    const Color(0xFF00FFCC).withValues(alpha: _isDarkMode ? 0.4 : 0.6),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00FFCC).withValues(alpha: _isDarkMode ? 0.08 : 0.15),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: const Color(0xFF00FFCC).withValues(alpha: 0.35),
                                width: 0.8,
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.wrap_text, size: 10, color: Color(0xFF00FFCC)),
                                SizedBox(width: 4),
                                Text(
                                  'SIGNAL CHAIN ROW BREAK',
                                  style: TextStyle(
                                    fontSize: 8.0,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.0,
                                    color: Color(0xFF00FFCC),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Container(
                              height: 1.0,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(0xFF00FFCC).withValues(alpha: _isDarkMode ? 0.4 : 0.6),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  } else if (isSpacer) {
                    cardWidget = SizedBox(
                      width: cardWidth,
                      height: cardHeight,
                    );
                  } else if (isLooper) {
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
                            _triggerSearchHighlight(pedal.instance, pedal: pedal, shouldScroll: false),
                        onSizeToggled: () => _cyclePedalSize(pedal.instance),
                        onBpmTap: _showBpmDialog,
                        onBypassToggle: (val) {
                          setState(() {
                            pedal.isBypassed = val;
                          });
                          _webSocketService.toggleBypass(
                            instance: pedal.instance,
                            bypass: val,
                          );
                          try {
                            _webViewController.runJavaScript("if (window.tamperSetBypass) window.tamperSetBypass('${pedal.instance}', $val);");
                          } catch (e) {
                            debugPrint('Error invoking tamperSetBypass: $e');
                          }
                        },
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
                            _triggerSearchHighlight(pedal.instance, pedal: pedal, shouldScroll: false),
                        onSizeToggled: () => _cyclePedalSize(pedal.instance),
                        onBpmTap: _showBpmDialog,
                        onBypassToggle: (val) {
                          setState(() {
                            pedal.isBypassed = val;
                          });
                          _webSocketService.toggleBypass(
                            instance: pedal.instance,
                            bypass: val,
                          );
                          try {
                            _webViewController.runJavaScript("if (window.tamperSetBypass) window.tamperSetBypass('${pedal.instance}', $val);");
                          } catch (e) {
                            debugPrint('Error invoking tamperSetBypass: $e');
                          }
                        },
                      );
                    }
                  } else if (isSwitch) {
                    cardWidget = SwitchCard(
                      pedal: pedal,
                      size: size,
                      isDarkMode: _isDarkMode,
                      glowColor: glowColor,
                      displayName: displayName,
                      mode: _switchModes[pedal.instance] ?? 'toggle',
                      pathAName: _switchPathANames[pedal.instance] ?? 'PATH A',
                      pathBName: _switchPathBNames[pedal.instance] ?? 'PATH B',
                      isInverted: _switchInverted[pedal.instance] ?? false,
                      onSizeToggled: () => _cyclePedalSize(pedal.instance),
                      onBypassToggle: (val) {
                        setState(() {
                          pedal.isBypassed = val;
                        });
                        _webSocketService.toggleBypass(
                          instance: pedal.instance,
                          bypass: val,
                        );
                        try {
                          _webViewController.runJavaScript("if (window.tamperSetBypass) window.tamperSetBypass('${pedal.instance}', $val);");
                        } catch (e) {
                          debugPrint('Error invoking tamperSetBypass: $e');
                        }
                      },
                      onRenamePressed: () => _showSwitchConfigDialog(pedal),
                      onHighlightPressed: () =>
                          _triggerSearchHighlight(pedal.instance, pedal: pedal, shouldScroll: false),
                      onColorPickerPressed: () => _showSwitchConfigDialog(pedal),
                      onOpenUri: _openPluginUri,
                      onSwitchPathChanged: (port, val) {
                        setState(() {
                          pedal.parameters[port] = val;
                        });
                        _webSocketService.setParamValue(
                          instance: pedal.instance,
                          port: port,
                          value: val,
                        );
                        try {
                          _webViewController.runJavaScript("if (window.tamperSetParam) window.tamperSetParam('${pedal.instance}', '$port', $val);");
                        } catch (e) {
                          debugPrint('Error invoking tamperSetParam: $e');
                        }
                      },
                    );
                  } else if (isGainOrVolume) {
                    final double? serverVal = (pedal.gainPortSymbol != null ? pedal.parameters[pedal.gainPortSymbol] : null);
                    final bool isMuted = _isMuted(pedal);
                    final double currentValue = (_fadeTimers[pedal.instance] != null)
                        ? (_localVolumes[pedal.instance] ?? serverVal ?? 0.0)
                        : (isMuted
                            ? (_mutedVolumes[pedal.instance] ?? serverVal ?? _localVolumes[pedal.instance] ?? 0.0)
                            : (serverVal ?? _localVolumes[pedal.instance] ?? 0.0));
                    final bool isFading = (_fadeTimers[pedal.instance] != null) || (_fadePaused[pedal.instance] == true);
                    final bool isFadePaused = _fadePaused[pedal.instance] ?? false;
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
                      liveMeterValue: _scrapedPedalDisplays[pedal.instance] ??
                          _scrapedPedalDisplays[pedal.instance.replaceAll('/graph/', '')] ??
                          pedal.liveMeterValue,
                      isMuted: _isMuted(pedal),
                      isFading: isFading,
                      isFadingIn: isFadingIn,
                      isFadingOut: isFadingOut,
                      fadeProgress: _fadeProgress[pedal.instance] ?? 0.0,
                      mode: _gainCardModes[pedal.instance] ?? 'fade',
                      onModeChanged: (newMode) {
                        setState(() {
                          _gainCardModes[pedal.instance] = newMode;
                        });
                        _saveLayoutSettings();
                      },
                      isFadePaused: isFadePaused,
                      onPauseResumeFade: () => _pauseResumeFade(pedal),
                      onStopFade: () => _stopFade(pedal),
                      rangeStart: rangeStart,
                      rangeEnd: rangeEnd,
                      fadeShape: _fadeShapes[pedal.instance] ?? 'Linear',
                      customParams:
                          _fadeCustomParams[pedal.instance] ??
                          {'h1x': 0.25, 'h1y': 0.1, 'mx': 0.5, 'my': 0.5, 'h2x': 0.75, 'h2y': 0.9},
                      customParamsOut:
                          _fadeCustomParamsOut[pedal.instance] ??
                          VectorBezierCurve.mirror(_fadeCustomParams[pedal.instance] ?? {'h1x': 0.25, 'h1y': 0.1, 'mx': 0.5, 'my': 0.5, 'h2x': 0.75, 'h2y': 0.9}),
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
                          final double fixedVal = double.parse(newValue.toStringAsFixed(2));
                          _webSocketService.setParamValue(
                            instance: pedal.instance,
                            port: pedal.gainPortSymbol!,
                            value: fixedVal,
                          );
                          try {
                            _webViewController.runJavaScript("if (window.tamperSetParam) window.tamperSetParam('${pedal.instance}', '${pedal.gainPortSymbol}', $fixedVal);");
                          } catch (e) {
                            debugPrint('Error invoking tamperSetParam on gain change: $e');
                          }
                        }
                      },
                      onMuteToggled: () => _toggleMute(pedal),
                      onRenamePressed: () => _showRenameDialog(pedal),
                      onColorPickerPressed: () => _showColorPickerDialog(pedal),
                      onHighlightPressed: () =>
                          _triggerSearchHighlight(pedal.instance, pedal: pedal, shouldScroll: false),
                      onSizeToggled: () {
                        setState(() {
                          final current =
                              _pedalSizes[pedal.instance] ?? 'regular';
                          final next = current == 'compact'
                              ? 'regular'
                              : current == 'regular'
                                  ? 'expanded'
                                  : 'compact';
                          _pedalSizes[pedal.instance] = next;
                        });
                        _saveLayoutSettings();
                      },
                      onBypassToggle: (val) {
                        _webSocketService.toggleBypass(
                          instance: pedal.instance,
                          bypass: val,
                        );
                        try {
                          _webViewController.runJavaScript("if (window.tamperSetBypass) window.tamperSetBypass('${pedal.instance}', $val);");
                        } catch (e) {
                          debugPrint('Error invoking tamperSetBypass: $e');
                        }
                      },
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
                      customPresets: _savedCustomCurvePresets,
                      onCustomPresetsChanged: (newPresets) {
                        setState(() {
                          _savedCustomCurvePresets.clear();
                          _savedCustomCurvePresets.addAll(newPresets);
                        });
                        _saveLayoutSettings();
                      },
                      onCustomCurveParamsChanged: (params) {
                        setState(() {
                          _fadeCustomParams[pedal.instance] = params;
                        });
                        _saveLayoutSettings();
                      },
                      onCustomCurveParamsOutChanged: (params) {
                        setState(() {
                          _fadeCustomParamsOut[pedal.instance] = params;
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
                      visibleParams: _customCardVisibleParams[pedal.instance] ?? [],
                      visibleCompactParams: _customCardVisibleCompactParams[pedal.instance] ?? [],
                      onBypassToggle: (val) {
                        _webSocketService.toggleBypass(
                          instance: pedal.instance,
                          bypass: val,
                        );
                        try {
                          _webViewController.runJavaScript("if (window.tamperSetBypass) window.tamperSetBypass('${pedal.instance}', $val);");
                        } catch (e) {
                          debugPrint('Error invoking tamperSetBypass: $e');
                        }
                      },
                      onRenamePressed: () => _showRenameDialog(pedal),
                      onHighlightPressed: () =>
                          _triggerSearchHighlight(pedal.instance, pedal: pedal, shouldScroll: false),
                      onColorPickerPressed: () => _showColorPickerDialog(pedal),
                      onSizeToggled: () {
                        setState(() {
                          final current = _pedalSizes[pedal.instance] ?? 'regular';
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
                      onParamChanged: (port, val) {
                        setState(() {
                          pedal.parameters[port] = val;
                        });
                        _webSocketService.setParamValue(
                          instance: pedal.instance,
                          port: port,
                          value: val,
                        );
                      },
                      onParamVisibilityToggled: (symbol, visible) {
                        setState(() {
                          final list = _customCardVisibleParams[pedal.instance] ?? [];
                          if (visible) {
                            if (!list.contains(symbol)) list.add(symbol);
                          } else {
                            list.remove(symbol);
                          }
                          _customCardVisibleParams[pedal.instance] = list;
                        });
                        _saveLayoutSettings();
                      },
                      onParamVisibilityCompactToggled: (symbol, visible) {
                        setState(() {
                          final list = _customCardVisibleCompactParams[pedal.instance] ?? [];
                          if (visible) {
                            if (!list.contains(symbol)) list.add(symbol);
                          } else {
                            list.remove(symbol);
                          }
                          _customCardVisibleCompactParams[pedal.instance] = list;
                        });
                        _saveLayoutSettings();
                      },
                      onOpenUri: _openPluginUri,
                    );
                  }

                  final bool isHighlighted = _highlightedInstanceId == pedal.instance;

                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    key: _getCardKey(pedal.instance),
                    width: cardWidth,
                    height: cardHeight,
                    decoration: isHighlighted
                        ? BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _isFlashStateOn ? Colors.white : glowColor,
                              width: _isFlashStateOn ? 3.5 : 1.5,
                            ),
                            boxShadow: _isFlashStateOn
                                ? [
                                    BoxShadow(
                                      color: Colors.white.withValues(alpha: 0.95),
                                      blurRadius: 20,
                                      spreadRadius: 4,
                                    ),
                                    BoxShadow(
                                      color: glowColor.withValues(alpha: 0.95),
                                      blurRadius: 36,
                                      spreadRadius: 8,
                                    ),
                                  ]
                                : [
                                    BoxShadow(
                                      color: glowColor.withValues(alpha: 0.4),
                                      blurRadius: 8,
                                      spreadRadius: 1,
                                    ),
                                  ],
                          )
                        : null,
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
      if (instanceId.startsWith('__spacer_') || instanceId.startsWith('__linebreak_')) continue;
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
    if (instId.startsWith('__spacer_') || instId.startsWith('__linebreak_')) return;
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
          
          // Blink for 5 seconds (each cycle takes 400ms: 200ms white, 200ms default/off)
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
            if (flashCount > 24) { // 12.5 complete blinking cycles (5 seconds)
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

  void _showSwitchConfigDialog(PluginInstance pedal) {
    final String instId = pedal.instance;
    final String currentTitle = _customTitles[instId] ?? pedal.title;
    final titleController = TextEditingController(text: currentTitle);

    String currentMode = _switchModes[instId] ?? 'toggle';
    final pathAController = TextEditingController(
      text: _switchPathANames[instId] ?? 'PATH A',
    );
    final pathBController = TextEditingController(
      text: _switchPathBNames[instId] ?? 'PATH B',
    );
    bool isInverted = _switchInverted[instId] ?? false;

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
              title: Row(
                children: [
                  Icon(
                    Icons.tune,
                    color: _isDarkMode
                        ? const Color(0xFF00FFCC)
                        : const Color(0xFF00B3FF),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'SWITCH SETTINGS',
                    style: TextStyle(
                      color: _isDarkMode
                          ? const Color(0xFF00FFCC)
                          : const Color(0xFF00B3FF),
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Display Title
                      TextField(
                        controller: titleController,
                        decoration: InputDecoration(
                          labelText: 'Custom Display Name',
                          labelStyle: TextStyle(
                            color: _isDarkMode ? Colors.grey[400] : Colors.grey[700],
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
                      ),
                      const SizedBox(height: 18),

                      // 2. Switch Layout Mode Selector
                      Text(
                        'SWITCH BEHAVIOR / LAYOUT',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _isDarkMode ? Colors.grey[400] : Colors.grey[600],
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: Icon(
                                Icons.toggle_on,
                                size: 16,
                                color: currentMode == 'toggle'
                                    ? Colors.black
                                    : (_isDarkMode ? Colors.grey[400] : Colors.grey[700]),
                              ),
                              label: const Text(
                                'ON / OFF TOGGLE',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: currentMode == 'toggle'
                                    ? (_isDarkMode
                                        ? const Color(0xFF00FFCC)
                                        : const Color(0xFF00B3FF))
                                    : (_isDarkMode ? Colors.grey[900] : Colors.grey[200]),
                                foregroundColor: currentMode == 'toggle'
                                    ? Colors.black
                                    : (_isDarkMode ? Colors.white : Colors.black87),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: () {
                                setDialogState(() {
                                  currentMode = 'toggle';
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: Icon(
                                Icons.alt_route,
                                size: 16,
                                color: currentMode == 'route'
                                    ? Colors.black
                                    : (_isDarkMode ? Colors.grey[400] : Colors.grey[700]),
                              ),
                              label: const Text(
                                '2-PATH ROUTE',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: currentMode == 'route'
                                    ? (_isDarkMode
                                        ? const Color(0xFF00FFCC)
                                        : const Color(0xFF00B3FF))
                                    : (_isDarkMode ? Colors.grey[900] : Colors.grey[200]),
                                foregroundColor: currentMode == 'route'
                                    ? Colors.black
                                    : (_isDarkMode ? Colors.white : Colors.black87),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: () {
                                setDialogState(() {
                                  currentMode = 'route';
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // 3. Conditional Mode Options
                      if (currentMode == 'route') ...[
                        Text(
                          '2-PATH CONFIGURATION',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _isDarkMode ? Colors.grey[400] : Colors.grey[600],
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: pathAController,
                          decoration: InputDecoration(
                            labelText: 'Path A Name (Down / 0.0)',
                            helperText: 'e.g. CLEAN, THROUGH, IN A',
                            helperStyle: const TextStyle(fontSize: 10),
                            labelStyle: TextStyle(
                              color: _isDarkMode ? Colors.grey[400] : Colors.grey[700],
                            ),
                            enabledBorder: const UnderlineInputBorder(
                              borderSide: BorderSide(color: Colors.grey),
                            ),
                          ),
                          style: TextStyle(
                            color: _isDarkMode ? Colors.white : Colors.black,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: pathBController,
                          decoration: InputDecoration(
                            labelText: 'Path B Name (Up / 1.0)',
                            helperText: 'e.g. DISTRO, HEAVY, IN B',
                            helperStyle: const TextStyle(fontSize: 10),
                            labelStyle: TextStyle(
                              color: _isDarkMode ? Colors.grey[400] : Colors.grey[700],
                            ),
                            enabledBorder: const UnderlineInputBorder(
                              borderSide: BorderSide(color: Colors.grey),
                            ),
                          ),
                          style: TextStyle(
                            color: _isDarkMode ? Colors.white : Colors.black,
                          ),
                        ),
                      ] else ...[
                        // Toggle Mode Options: Active definition
                        Text(
                          'ACTIVE STATE DEFINITION',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _isDarkMode ? Colors.grey[400] : Colors.grey[600],
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: ChoiceChip(
                                label: const Text('Normal (1 = ON)'),
                                selected: !isInverted,
                                onSelected: (sel) {
                                  if (sel) {
                                    setDialogState(() {
                                      isInverted = false;
                                    });
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ChoiceChip(
                                label: const Text('Inverted (0 = ON)'),
                                selected: isInverted,
                                onSelected: (sel) {
                                  if (sel) {
                                    setDialogState(() {
                                      isInverted = true;
                                    });
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 18),

                      // 4. Color Picker Section
                      Text(
                        'GLOW COLOR',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _isDarkMode ? Colors.grey[400] : Colors.grey[600],
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        alignment: WrapAlignment.start,
                        spacing: 8,
                        runSpacing: 8,
                        children: kNeonColors.map((hex) {
                          final Color dotColor = _hexToColor(hex);
                          final bool isSelected =
                              hex.toUpperCase() == selectedColorHex.toUpperCase();
                          return GestureDetector(
                            onTap: () {
                              setDialogState(() {
                                selectedColorHex = hex;
                              });
                            },
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: dotColor,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected
                                      ? (_isDarkMode ? Colors.white : Colors.black)
                                      : Colors.transparent,
                                  width: 2.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: dotColor.withOpacity(
                                      isSelected ? 0.6 : 0.2,
                                    ),
                                    blurRadius: isSelected ? 10 : 4,
                                    spreadRadius: isSelected ? 2 : 1,
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
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
                    final trimmed = titleController.text.trim();
                    setState(() {
                      if (trimmed.isNotEmpty) {
                        _customTitles[instId] = trimmed;
                      } else {
                        _customTitles.remove(instId);
                      }
                      _switchModes[instId] = currentMode;
                      _switchPathANames[instId] = pathAController.text.trim().isNotEmpty
                          ? pathAController.text.trim()
                          : 'PATH A';
                      _switchPathBNames[instId] = pathBController.text.trim().isNotEmpty
                          ? pathBController.text.trim()
                          : 'PATH B';
                      _switchInverted[instId] = isInverted;
                      _pedalGlowColors[instId] = selectedColorHex;
                    });
                    _saveLayoutSettings();
                    _updateAllGlowsInWebView();
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

  Widget _buildAppBarViewChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? (_isDarkMode
                  ? const Color(0xFF00FFCC).withValues(alpha: 0.2)
                  : const Color(0xFF00B3FF).withValues(alpha: 0.2))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isSelected
                ? (_isDarkMode ? const Color(0xFF00FFCC) : const Color(0xFF00B3FF))
                : (_isDarkMode ? Colors.white24 : Colors.black26),
            width: isSelected ? 1.2 : 0.8,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w900,
            color: isSelected
                ? (_isDarkMode ? const Color(0xFF00FFCC) : const Color(0xFF00B3FF))
                : (_isDarkMode ? Colors.grey[400] : Colors.grey[700]),
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Future<void> _loadThemeSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedDark = prefs.getBool('is_dark_mode');
      if (mounted) {
        setState(() {
          if (savedDark != null) _isDarkMode = savedDark;
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

  Future<bool> _checkIfChromeOs() async {
    if (!Platform.isAndroid) return false;
    try {
      final result = await const MethodChannel('com.example.mod_controller/device')
          .invokeMethod<Map<dynamic, dynamic>>('getDeviceInfo');
      if (result != null) {
        return (result['isChromeOs'] == true) || (result['isHatch'] == true);
      }
    } catch (e) {
      debugPrint('Error checking device info: $e');
    }
    return false;
  }

  Future<void> _loadSavedIp() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedIp = prefs.getString('saved_mod_dwarf_ip');
      if (savedIp != null && savedIp.isNotEmpty && mounted) {
        setState(() {
          _ipController.text = savedIp;
        });
        if (_webSocketService.status == ConnectionStatus.disconnected) {
          _webSocketService.connect(ip: savedIp);
          _webViewController.loadRequest(Uri.parse('http://$savedIp'));
        }
      } else {
        // No saved IP: auto-detect if running on ChromeOS / Hatch
        final bool isChromeOs = await _checkIfChromeOs();
        if (isChromeOs && mounted) {
          setState(() {
            _ipController.text = '100.115.92.201';
          });
          if (_webSocketService.status == ConnectionStatus.disconnected) {
            _webSocketService.connect(ip: '100.115.92.201');
            _webViewController.loadRequest(Uri.parse('http://100.115.92.201'));
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading saved IP: $e');
    }
  }

  Future<void> _saveIp(String ip) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('saved_mod_dwarf_ip', ip);
    } catch (e) {
      debugPrint('Error saving IP: $e');
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

  String? _findBestMatchingPedalboardKey(
    SharedPreferences prefs,
    List<String> currentIds,
  ) {
    final Set<String> allKeys = prefs.getKeys();
    String? bestKey;
    int bestScore = 0;

    for (final k in allKeys) {
      if (k.startsWith('pedalboard_') && k.endsWith('_order')) {
        final candidateKey = k.substring(0, k.length - '_order'.length);
        final List<String>? candidateOrder = prefs.getStringList(k);
        if (candidateOrder == null || candidateOrder.isEmpty) continue;

        int matchingCount = 0;
        for (final id in candidateOrder) {
          if (currentIds.contains(id)) {
            matchingCount++;
          }
        }

        if (matchingCount > bestScore) {
          bestScore = matchingCount;
          bestKey = candidateKey;
        }
      }
    }

    return bestScore > 0 ? bestKey : null;
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

    final String? customCardVisible = prefs.getString('${oldKey}_custom_card_visible_params');
    if (customCardVisible != null) await prefs.setString('${newKey}_custom_card_visible_params', customCardVisible);

    final String? customCardVisibleCompact = prefs.getString('${oldKey}_custom_card_visible_compact_params');
    if (customCardVisibleCompact != null) await prefs.setString('${newKey}_custom_card_visible_compact_params', customCardVisibleCompact);

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
    await prefs.remove('${oldKey}_custom_card_visible_params');
    await prefs.remove('${oldKey}_custom_card_visible_compact_params');
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
    await prefs.remove('${oldKey}_custom_card_visible_params');
    await prefs.remove('${oldKey}_custom_card_visible_compact_params');
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
      await prefs.setString('${key}_custom_card_visible_params', jsonEncode(_customCardVisibleParams));
      await prefs.setString('${key}_custom_card_visible_compact_params', jsonEncode(_customCardVisibleCompactParams));
      await prefs.setString('${key}_switch_modes', jsonEncode(_switchModes));
      await prefs.setString('${key}_switch_path_a_names', jsonEncode(_switchPathANames));
      await prefs.setString('${key}_switch_path_b_names', jsonEncode(_switchPathBNames));
      await prefs.setString('${key}_switch_inverted', jsonEncode(_switchInverted));
      await prefs.setString('${key}_gain_card_modes', jsonEncode(_gainCardModes));
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
      final customOutEncoded = _fadeCustomParamsOut.map(
        (k, v) => MapEntry(k, jsonEncode(v)),
      );
      await prefs.setString(
        '${key}_fadeCustomParamsOut',
        jsonEncode(customOutEncoded),
      );
      final customPresetsEncoded = _savedCustomCurvePresets.map(
        (k, v) => MapEntry(k, jsonEncode(v)),
      );
      await prefs.setString(
        'custom_curve_presets',
        jsonEncode(customPresetsEncoded),
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
        if (key.startsWith('pedalboard_') || key == 'is_dark_mode' || key == 'custom_curve_presets') {
          final value = prefs.get(key);
          backupData[key] = value;
        }
      }

      final jsonString = jsonEncode(backupData);
      final tempDir = Directory.systemTemp;
      final now = DateTime.now();
      final timestamp =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}_'
          '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
      final fileName = 'tampermod_backup_$timestamp.json';
      final tempFile = File('${tempDir.path}/$fileName');
      await tempFile.writeAsString(jsonString);

      await Share.shareXFiles(
        [XFile(tempFile.path)],
        subject: 'TamperMod Backup ($timestamp)',
        text: 'TamperMod configurations backup JSON file ($timestamp).',
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

                      // Direct Raw Text Options (No expansion required)
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Icon(
                            Icons.code_rounded,
                            size: 14,
                            color: _isDarkMode ? const Color(0xFF00FFCC) : const Color(0xFF00B3FF),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'CLIPBOARD & RAW JSON BACKUP',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.0,
                              color: _isDarkMode ? Colors.grey[300] : Colors.grey[800],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: jsonTextController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'Paste layout backup JSON string here...',
                          hintStyle: const TextStyle(fontSize: 10.5, color: Colors.grey),
                          fillColor: _isDarkMode ? const Color(0xFF070A0F) : Colors.grey[50],
                          filled: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: _isDarkMode ? Colors.grey[800]! : Colors.grey[300]!,
                            ),
                          ),
                        ),
                        style: const TextStyle(fontSize: 9.5, fontFamily: 'monospace'),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00FFCC),
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              textStyle: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold),
                            ),
                            icon: const Icon(Icons.copy_rounded, size: 14),
                            label: const Text('COPY JSON'),
                            onPressed: () async {
                              try {
                                final prefs = await SharedPreferences.getInstance();
                                final Set<String> keys = prefs.getKeys();
                                final Map<String, dynamic> backupData = {};
                                for (final key in keys) {
                                  if (key.startsWith('pedalboard_') || key == 'is_dark_mode' || key == 'custom_curve_presets') {
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
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              textStyle: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold),
                            ),
                            icon: const Icon(Icons.paste_rounded, size: 14),
                            label: const Text('PASTE & RESTORE'),
                            onPressed: () async {
                              String text = jsonTextController.text.trim();
                              if (text.isEmpty) {
                                final clipboardData = await Clipboard.getData('text/plain');
                                if (clipboardData?.text != null && clipboardData!.text!.isNotEmpty) {
                                  text = clipboardData.text!.trim();
                                  jsonTextController.text = text;
                                }
                              }
                              if (text.isEmpty) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Please paste or copy JSON first!'),
                                      backgroundColor: Color(0xFFFF007F),
                                    ),
                                  );
                                }
                                return;
                              }
                              if (!context.mounted) return;
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

  void _addSpacer() {
    final String spacerId = '__spacer_${DateTime.now().millisecondsSinceEpoch}';
    setState(() {
      _orderedPluginInstances.add(spacerId);
      _enabledPluginInstances.add(spacerId);
      _pedalSizes[spacerId] = 'regular';
    });
    _saveLayoutSettings();
  }

  void _deleteSpacer(String spacerId) {
    setState(() {
      _orderedPluginInstances.remove(spacerId);
      _enabledPluginInstances.remove(spacerId);
      _pedalSizes.remove(spacerId);
    });
    _saveLayoutSettings();
  }

  void _addLineBreak() {
    final String lineBreakId =
        '__linebreak_${DateTime.now().millisecondsSinceEpoch}';
    setState(() {
      _orderedPluginInstances.add(lineBreakId);
      _enabledPluginInstances.add(lineBreakId);
      _pedalSizes[lineBreakId] = 'expanded';
    });
    _saveLayoutSettings();
  }

  void _deleteLineBreak(String lineBreakId) {
    setState(() {
      _orderedPluginInstances.remove(lineBreakId);
      _enabledPluginInstances.remove(lineBreakId);
      _pedalSizes.remove(lineBreakId);
    });
    _saveLayoutSettings();
  }

  void _handlePedalSearchClick(String rawInstanceId) {
    debugPrint('PedalClickChannel received rawInstanceId: $rawInstanceId');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _triggerSearchHighlight(rawInstanceId, shouldScroll: true);
    });
  }

  void _triggerSearchHighlight(
    String rawTargetId, {
    PluginInstance? pedal,
    bool shouldScroll = true,
  }) {
    final plugins = _webSocketService.allPlugins.value;
    PluginInstance? matchingPedal = pedal;
    if (matchingPedal == null) {
      final String cleanRaw = rawTargetId
          .replaceAll('/graph/', '')
          .replaceAll('/', '')
          .toLowerCase()
          .trim();
      for (final p in plugins) {
        final String cleanP = p.instance
            .replaceAll('/graph/', '')
            .replaceAll('/', '')
            .toLowerCase()
            .trim();
        if (p.instance == rawTargetId ||
            cleanP == cleanRaw ||
            p.instance.toLowerCase().endsWith(cleanRaw) ||
            rawTargetId.toLowerCase().endsWith(cleanP) ||
            p.instance.endsWith('/${rawTargetId.split('/').last}') ||
            rawTargetId.endsWith('/${p.instance.split('/').last}')) {
          matchingPedal = p;
          break;
        }
      }
    }

    final String targetId = matchingPedal?.instance ?? rawTargetId;
    debugPrint('triggerSearchHighlight targetId: $targetId (shouldScroll: $shouldScroll)');

    // Blink physical pedal in WebView for 5 seconds
    if (matchingPedal != null) {
      _highlightPedalInWebView(matchingPedal);
    }

    // Scroll dashboard card into view ONLY when requested (e.g. from tag click, not card target button)
    if (shouldScroll) {
      _scrollToCard(targetId);
    }

    // Trigger synchronized flashing strobe on dashboard card and puzzle tile for 5 seconds
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _highlightedInstanceId = targetId;
        _isFlashStateOn = true;
      });
    });

    _highlightTimer?.cancel();
    _flashStrobeTimer?.cancel();

    // Pulse flash state every 250ms for an active breathing strobe safely post-frame
    _flashStrobeTimer = Timer.periodic(const Duration(milliseconds: 250), (timer) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _highlightedInstanceId != null) {
          setState(() {
            _isFlashStateOn = !_isFlashStateOn;
          });
        }
      });
    });

    _highlightTimer = Timer(const Duration(milliseconds: 5000), () {
      _flashStrobeTimer?.cancel();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            if (_highlightedInstanceId == targetId) {
              _highlightedInstanceId = null;
              _isFlashStateOn = false;
            }
          });
        }
      });
    });
  }

  void _scrollToCard(String instanceId) {
    if (!_showControls) {
      setState(() {
        _showControls = true;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToCard(instanceId);
      });
      return;
    }

    final key = _cardKeys[instanceId];
    final targetContext = key?.currentContext;
    if (targetContext != null) {
      Scrollable.ensureVisible(
        targetContext,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOutCubic,
        alignment: 0.0,
      );
    }
  }
}
