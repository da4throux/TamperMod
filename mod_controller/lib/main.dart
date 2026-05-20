import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/websocket_service.dart';
import 'models/plugin_instance.dart';
import 'services/looper_controller.dart';
import 'models/module_help_data.dart';

// Global application version tracking constant
const String kAppVersion = '1.2.5';



// ─── Custom S-Curve for fade interpolation ────────────────────────────────
/// A [Curve] defined by a midpoint (cx, cy) and a blend factor [slope].
/// slope=0 → pure linear, slope=1 → pure easeInOut-like.
class _CustomSCurve extends Curve {
  final double cx;
  final double cy;
  final double slope;

  const _CustomSCurve({this.cx = 0.5, this.cy = 0.5, this.slope = 1.0});

  @override
  double transformInternal(double t) {
    // Piecewise linear mid-point shifted by cx/cy
    final double linear = t < cx
        ? (cx > 0 ? (cy / cx) * t : 0.0)
        : (cx < 1 ? cy + ((1.0 - cy) / (1.0 - cx)) * (t - cx) : 1.0);
    // Blend with easeInOut using slope as the weight
    final double eased = Curves.easeInOut.transform(t);
    final double s = slope.clamp(0.0, 1.0);
    return (linear * (1 - s) + eased * s).clamp(0.0, 1.0);
  }
}

// ─── Live fade curve visualizer painter ───────────────────────────────────
class _FadeCurvePainter extends CustomPainter {
  final Color accentColor;
  final Curve curve;
  final double progress;       // 0.0–1.0, where the moving dot is
  final int bars;
  final double rangeStart;     // 0.0–1.0 fractional
  final double rangeEnd;       // 0.0–1.0 fractional

  _FadeCurvePainter({
    required this.accentColor,
    required this.curve,
    required this.progress,
    required this.bars,
    required this.rangeStart,
    required this.rangeEnd,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const double padL = 28, padR = 12, padT = 8, padB = 24;
    final double w = size.width - padL - padR;
    final double h = size.height - padT - padB;

    // Background
    final bgPaint = Paint()..color = const Color(0xFF0A0D12);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        const Radius.circular(10),
      ),
      bgPaint,
    );

    // Grid lines
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.06)
      ..strokeWidth = 0.5;
    for (int i = 0; i <= bars; i++) {
      final double x = padL + (i / bars) * w;
      canvas.drawLine(Offset(x, padT), Offset(x, padT + h), gridPaint);
    }
    for (int i = 0; i <= 4; i++) {
      final double y = padT + (i / 4) * h;
      canvas.drawLine(Offset(padL, y), Offset(padL + w, y), gridPaint);
    }

    // Range dashed lines
    final rangePaint = Paint()
      ..color = accentColor.withOpacity(0.35)
      ..strokeWidth = 1.0;
    final double yStart = padT + (1.0 - rangeStart) * h;
    final double yEnd   = padT + (1.0 - rangeEnd) * h;
    _drawDashed(canvas, Offset(padL, yStart), Offset(padL + w, yStart), rangePaint);
    _drawDashed(canvas, Offset(padL, yEnd),   Offset(padL + w, yEnd),   rangePaint);

    // Curve line
    final curvePaint = Paint()
      ..color = accentColor
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final path = Path();
    const int steps = 120;
    for (int i = 0; i <= steps; i++) {
      final double t = i / steps;
      final double ct = curve.transform(t);
      // ct=0 → bottom (muted), ct=1 → top (full)
      final double px = padL + t * w;
      final double py = padT + (1.0 - ct) * h;
      if (i == 0) {
        path.moveTo(px, py);
      } else {
        path.lineTo(px, py);
      }
    }
    canvas.drawPath(path, curvePaint);

    // Moving dot
    if (progress > 0.0 && progress < 1.0) {
      final double ct = curve.transform(progress);
      final double dotX = padL + progress * w;
      final double dotY = padT + (1.0 - ct) * h;
      // Glow
      canvas.drawCircle(
        Offset(dotX, dotY),
        9,
        Paint()..color = accentColor.withOpacity(0.3),
      );
      // Core dot
      canvas.drawCircle(
        Offset(dotX, dotY),
        5,
        Paint()..color = accentColor,
      );
    }

    // Axis labels
    final labelStyle = TextStyle(
      color: Colors.grey[600],
      fontSize: 9,
    );
    // Bar ticks on X
    for (int i = 0; i <= bars; i++) {
      final double x = padL + (i / bars) * w;
      _drawText(canvas, '$i', Offset(x - 4, padT + h + 4), labelStyle);
    }
    // Y labels
    _drawText(canvas, '100%', Offset(0, padT - 2), labelStyle);
    _drawText(canvas, '0%', Offset(4, padT + h - 6), labelStyle);
  }

  void _drawDashed(Canvas canvas, Offset start, Offset end, Paint paint) {
    const double dashLen = 4, gapLen = 4;
    final double dx = end.dx - start.dx;
    final double dy = end.dy - start.dy;
    final double len = (end - start).distance;
    final double stepX = dx / len * (dashLen + gapLen);
    final double stepY = dy / len * (dashLen + gapLen);
    double drawn = 0;
    double ox = start.dx, oy = start.dy;
    while (drawn < len) {
      final double dashEnd = (drawn + dashLen).clamp(0, len);
      final double ratio = dashEnd / len;
      canvas.drawLine(
        Offset(ox, oy),
        Offset(start.dx + dx * ratio, start.dy + dy * ratio),
        paint,
      );
      drawn += dashLen + gapLen;
      ox += stepX;
      oy += stepY;
    }
  }

  void _drawText(Canvas canvas, String text, Offset offset, TextStyle style) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(_FadeCurvePainter old) =>
      old.progress != progress ||
      old.rangeStart != rangeStart ||
      old.rangeEnd != rangeEnd ||
      old.curve != curve ||
      old.accentColor != accentColor;
}

// ─── Mini range indicator painter (compact/regular cards) ─────────────────
class _MiniRangePainter extends CustomPainter {
  final Color accentColor;
  final double rangeStart; // 0.0–1.0
  final double rangeEnd;   // 0.0–1.0

  _MiniRangePainter({
    required this.accentColor,
    required this.rangeStart,
    required this.rangeEnd,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const double trackW = 4.0;
    final double cx = size.width / 2;
    const double padY = 4.0;
    final double trackH = size.height - padY * 2;

    // Background track
    final bgPaint = Paint()
      ..color = accentColor.withOpacity(0.12)
      ..strokeWidth = trackW
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(cx, padY), Offset(cx, padY + trackH), bgPaint);

    // Active range highlight
    final activePaint = Paint()
      ..color = accentColor.withOpacity(0.5)
      ..strokeWidth = trackW
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    // Note: rangeStart=0 = bottom (muted), rangeEnd=1 = top (full volume)
    // Draw from bottom (muted) upwards
    final double yStart = padY + (1.0 - rangeEnd) * trackH;
    final double yEnd   = padY + (1.0 - rangeStart) * trackH;
    canvas.drawLine(Offset(cx, yStart), Offset(cx, yEnd), activePaint);

    // Triangle handles
    final triPaint = Paint()..color = accentColor;
    // Start triangle (pointing right, at rangeStart)
    final double ys = padY + (1.0 - rangeStart) * trackH;
    final path1 = Path();
    path1.moveTo(cx, ys);
    path1.lineTo(cx + 6, ys - 4);
    path1.lineTo(cx + 6, ys + 4);
    path1.close();
    canvas.drawPath(path1, triPaint);

    // End triangle (pointing right, at rangeEnd)
    final double ye = padY + (1.0 - rangeEnd) * trackH;
    final path2 = Path();
    path2.moveTo(cx, ye);
    path2.lineTo(cx + 6, ye - 4);
    path2.lineTo(cx + 6, ye + 4);
    path2.close();
    canvas.drawPath(path2, triPaint);
  }

  @override
  bool shouldRepaint(_MiniRangePainter old) =>
      old.rangeStart != rangeStart ||
      old.rangeEnd != rangeEnd ||
      old.accentColor != accentColor;
}

enum ViewMode { split, controls, web }

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  WakelockPlus.enable();

  runApp(const ModControllerApp());
}

class ModControllerApp extends StatelessWidget {
  const ModControllerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TamperMod - Live Remote',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0B0E14),
        cardColor: const Color(0xFF161B22),
        primaryColor: const Color(0xFF00FFCC),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00FFCC),
          secondary: Color(0xFFFF007F), // Fuchsia / Neon Pink
          surface: Color(0xFF161B22),
          background: Color(0xFF0B0E14),
        ),
        textTheme: const TextTheme(
          headlineMedium: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
          titleLarge: TextStyle(
            color: Color(0xFF00FFCC),
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
      ),
      home: const DashboardScreen(),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

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
  final Map<String, double> _fadeRangeEnd   = {};

  // Per-pedal fade shape: 'linear' | 'easeInOut' | 'easeIn' | 'easeOut' | 'custom'
  final Map<String, String> _fadeShapes = {};

  // Per-pedal custom S-curve params: cx, cy, slope
  final Map<String, Map<String, double>> _fadeCustomParams = {};

  // Live fade progress [0.0–1.0] — transient, not persisted
  final Map<String, double> _fadeProgress = {};

  // Custom User Ordering and Visibility List
  List<String> _enabledPluginInstances = [];

  // Neon Colors Palette for permanent visual cues
  static const List<String> kNeonColors = [
    '#00FFCC', // Turquoise
    '#FF0055', // Pink
    '#9D00FF', // Purple
    '#00FF66', // Green
    '#FF7700', // Orange
  ];

  final ScrollController _cardsScrollController = ScrollController();
  final Map<String, String> _pedalGlowColors = {};
  final Map<String, bool> _pedalGlowEnabled = {};
  final Map<String, String> _pedalSizes = {};

  Color _hexToColor(String hex) {
    final String cleanHex = hex.replaceAll('#', '');
    if (cleanHex.length == 6) {
      return Color(int.parse('FF$cleanHex', radix: 16));
    }
    return const Color(0xFF00FFCC);
  }

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
      if (_looperController != null && _looperController.activeLooper != null) {
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

  // Fading and BPM Parameter State
  double _bpm = 120.0;
  int _fadeBars =
      8; // Default fade speed period in bars (configurable: 1, 2, 4, 8, 16)

  final Map<String, double> _preFadeVolumes = {};
  final Map<String, Timer?> _fadeTimers = {};
  final Map<String, bool> _fadeDirections =
      {}; // true for Fade In, false for Fade Out

  // Tap-tempo times keeper
  final List<DateTime> _tapTimes = [];

  // User custom display titles for plugin cards (renaming support)
  final Map<String, String> _customTitles = {};

  bool _isMuted(PluginInstance pedal) {
    final double currentValue = _localVolumes[pedal.instance] ??
        (pedal.gainPortSymbol != null ? pedal.parameters[pedal.gainPortSymbol] : null) ??
        0.0;
    return currentValue == pedal.minGain;
  }

  void _toggleMute(PluginInstance pedal) {
    final String instanceId = pedal.instance;
    final double currentValue = _localVolumes[instanceId] ??
        (pedal.gainPortSymbol != null ? pedal.parameters[pedal.gainPortSymbol] : null) ??
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
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            // Apply all permanent glows automatically when the page is finished loading!
            _updateAllGlowsInWebView();
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

    final key = _getPedalboardKey();
    final List<String> currentIds = plugins.map((p) => p.instance).toList();

    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String>? savedOrder = prefs.getStringList('${key}_order');
      final List<String>? savedEnabled = prefs.getStringList('${key}_enabled');
      final String? savedColorsJson = prefs.getString('${key}_colors');
      final String? savedSizesJson = prefs.getString('${key}_sizes');

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
        final nonLoopers = plugins.where((p) {
          final uriLower = p.uri.toLowerCase();
          final titleLower = p.title.toLowerCase();
          return !(uriLower.contains('alo') || titleLower.contains('alo'));
        }).map((p) => p.instance).toList();

        final loopers = plugins.where((p) {
          final uriLower = p.uri.toLowerCase();
          final titleLower = p.title.toLowerCase();
          return uriLower.contains('alo') || titleLower.contains('alo');
        }).map((p) => p.instance).toList();

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
      newEnabled.sort((a, b) => newOrder.indexOf(a).compareTo(newOrder.indexOf(b)));


      // 3. Colors
      if (savedColorsJson != null) {
        final Map<String, dynamic> decoded = jsonDecode(savedColorsJson);
        decoded.forEach((k, v) {
          _pedalGlowColors[k] = v.toString();
        });
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

      if (mounted) {
        setState(() {
          _orderedPluginInstances = newOrder;
          _enabledPluginInstances = newEnabled;
          _pedalSizes.clear();
          _pedalSizes.addAll(newSizes);
        });
        _updateAllGlowsInWebView();
      }

      // 5. Fade range cursors
      final String? savedFadeStart  = prefs.getString('${key}_fadeRangeStart');
      final String? savedFadeEnd    = prefs.getString('${key}_fadeRangeEnd');
      final String? savedFadeShapes = prefs.getString('${key}_fadeShapes');
      final String? savedFadeCustom = prefs.getString('${key}_fadeCustomParams');
      if (savedFadeStart != null) {
        final Map<String, dynamic> dec = jsonDecode(savedFadeStart);
        dec.forEach((k, v) => _fadeRangeStart[k] = (v as num).toDouble());
      }
      if (savedFadeEnd != null) {
        final Map<String, dynamic> dec = jsonDecode(savedFadeEnd);
        dec.forEach((k, v) => _fadeRangeEnd[k] = (v as num).toDouble());
      }
      if (savedFadeShapes != null) {
        final Map<String, dynamic> dec = jsonDecode(savedFadeShapes);
        dec.forEach((k, v) => _fadeShapes[k] = v.toString());
      }
      if (savedFadeCustom != null) {
        final Map<String, dynamic> outer = jsonDecode(savedFadeCustom);
        outer.forEach((k, v) {
          final Map<String, dynamic> inner = jsonDecode(v.toString());
          _fadeCustomParams[k] = inner.map(
            (ik, iv) => MapEntry(ik, (iv as num).toDouble()),
          );
        });
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

  Future<void> _syncNow() async {
    final ip = _ipController.text;
    if (ip.isEmpty) return;

    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 2);
      final request = await client.postUrl(
        Uri.parse('http://$ip/pedalboard/transport/sync/none'),
      );
      final response = await request.close();
      debugPrint('Sync POST Response status code: ${response.statusCode}');

      // Also send rolling command via websocket
      _webSocketService.sendRawMessage('transport-rolling 1');
    } catch (e) {
      debugPrint('Error during Sync POST: $e');
      // Fallback: send websocket command anyway
      _webSocketService.sendRawMessage('transport-rolling 1');
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
    final controller = TextEditingController(text: _bpm.toStringAsFixed(1));
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
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Tempo (BPM)',
              labelStyle: TextStyle(
                color: _isDarkMode ? Colors.grey : Colors.grey[750],
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
                final double? newBpm = double.tryParse(controller.text);
                if (newBpm != null && newBpm > 20.0 && newBpm < 300.0) {
                  _webSocketService.setBpm(newBpm);
                }
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
    final double rangeEndFrac   = _fadeRangeEnd[pedal.instance]   ?? 1.0;

    // Convert fractional range to actual dB values
    final double fadeMin = minRange + rangeStartFrac * (maxRange - minRange);
    final double fadeMax = minRange + rangeEndFrac   * (maxRange - minRange);

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
        selectedCurve = _CustomSCurve(
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
      _fadeProgress[pedal.instance]   = 0.0;
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
            _fadeTimers[pedal.instance]   = null;
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
    final statusBarHeight = MediaQuery.of(context).padding.top;

    return ListenableBuilder(
      listenable: _webSocketService,
      builder: (context, _) {
        final screenWidth = MediaQuery.of(context).size.width;
        final orientation = MediaQuery.of(context).orientation;
        final isLandscape = orientation == Orientation.landscape;

        return Scaffold(
          // Right-aligned settings drawer, strategically padded below AppBar to keep a continuous border line
          endDrawer: Drawer(
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: Container(
              margin: EdgeInsets.only(top: kToolbarHeight + statusBarHeight),
              decoration: BoxDecoration(
                color: _isDarkMode ? const Color(0xFF0F141C) : Colors.white,
                border: Border(
                  left: BorderSide(
                    color: _isDarkMode
                        ? const Color(0xFF00FFCC)
                        : const Color(0xFF00B3FF),
                    width: 1.5,
                  ),
                  top: BorderSide(
                    color: _isDarkMode
                        ? const Color(0xFF00FFCC)
                        : const Color(0xFF00B3FF),
                    width: 1.5,
                  ),
                ),
              ),
              child: _buildDrawerContent(),
            ),
          ),

          // Continuous Left-aligned navigation and metrics drawer
          drawer: Drawer(
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: Container(
              decoration: BoxDecoration(
                color: _isDarkMode ? const Color(0xFF0F141C) : Colors.white,
                border: Border(
                  right: BorderSide(
                    color: _isDarkMode
                        ? const Color(0xFF00FFCC)
                        : const Color(0xFF00B3FF),
                    width: 1.5,
                  ),
                ),
              ),
              child: _buildLeftDrawerContent(),
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
              if (screenWidth > 580) _buildBpmControllerWidget(),
              const SizedBox(width: 8),

              // Open Settings Drawer
              Builder(
                builder: (context) => IconButton(
                  icon: const Icon(
                    Icons.settings_outlined,
                    color: Color(0xFFFF007F),
                    size: 22,
                  ),
                  tooltip: 'Workspace Settings',
                  onPressed: () {
                    Scaffold.of(context).openEndDrawer();
                  },
                ),
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
                _buildBottomToolbar(),

                // Inline Connection / IP bar
                _buildConnectionPanel(),

                // BPM inline widget on tiny screens to avoid AppBar overcrowding
                if (screenWidth <= 580)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    child: _buildBpmControllerWidget(),
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

  Widget _buildBpmControllerWidget() {
    final double seconds = (60 / _bpm) * 4 * _fadeBars;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _isDarkMode
            ? Colors.black.withOpacity(0.35)
            : Colors.grey[300]!.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color:
              (_isDarkMode ? const Color(0xFF00FFCC) : const Color(0xFF00B3FF))
                  .withOpacity(0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Fuchsia Tap Tempo Button
          GestureDetector(
            onTap: _onTapTempo,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFF007F).withOpacity(0.12),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: const Color(0xFFFF007F).withOpacity(0.4),
                ),
              ),
              child: const Text(
                'TAP',
                style: TextStyle(
                  color: Color(0xFFFF007F),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Editable BPM readout
          GestureDetector(
            onTap: _showBpmDialog,
            child: Text(
              '${_bpm.toStringAsFixed(1)} BPM',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
                color: _isDarkMode
                    ? const Color(0xFF00FFCC)
                    : const Color(0xFF0099FF),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Dropdown selector for Fade Beats length
          DropdownButton<int>(
            value: _fadeBars,
            dropdownColor: _isDarkMode ? const Color(0xFF0F141C) : Colors.white,
            underline: const SizedBox(),
            icon: const Icon(
              Icons.arrow_drop_down,
              color: Colors.grey,
              size: 16,
            ),
            style: TextStyle(
              color: _isDarkMode ? Colors.white : Colors.black,
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
            ),
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  _fadeBars = val;
                });
              }
            },
            items: [1, 2, 4, 8, 16].map((b) {
              return DropdownMenuItem<int>(
                value: b,
                child: Text('$b Bar${b > 1 ? "s" : ""}'),
              );
            }).toList(),
          ),
          const SizedBox(width: 4),

          // Live duration calculation text
          Text(
            '(${seconds.toStringAsFixed(1)}s)',
            style: TextStyle(
              fontSize: 10,
              color: _isDarkMode ? Colors.grey[500] : Colors.grey[700],
            ),
          ),

          // Vertical divider
          Container(
            height: 20,
            width: 1,
            color: Colors.grey.withOpacity(0.4),
            margin: const EdgeInsets.symmetric(horizontal: 10),
          ),

          // Play/Stop Button
          ValueListenableBuilder<bool>(
            valueListenable: _webSocketService.isTransportRolling,
            builder: (context, isRolling, _) {
              return IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Icon(
                  isRolling ? Icons.stop : Icons.play_arrow,
                  color: isRolling
                      ? const Color(0xFFFF0055)
                      : (_isDarkMode
                            ? const Color(0xFF00FFCC)
                            : const Color(0xFF00B3FF)),
                  size: 20,
                ),
                tooltip: isRolling ? 'Stop Transport' : 'Play Transport',
                onPressed: () {
                  _webSocketService.setRolling(!isRolling);
                },
              );
            },
          ),
          const SizedBox(width: 10),

          // Sync Mode Dropdown
          ValueListenableBuilder<int>(
            valueListenable: _webSocketService.transportSyncMode,
            builder: (context, syncMode, _) {
              return DropdownButton<int>(
                value: (syncMode >= 0 && syncMode <= 2) ? syncMode : 0,
                dropdownColor: _isDarkMode
                    ? const Color(0xFF0F141C)
                    : Colors.white,
                underline: const SizedBox(),
                icon: const Icon(Icons.sync, color: Colors.grey, size: 14),
                style: TextStyle(
                  color: _isDarkMode ? Colors.white : Colors.black,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
                onChanged: (val) {
                  if (val != null) {
                    _setTransportSyncMode(val);
                  }
                },
                items: const [
                  DropdownMenuItem<int>(value: 0, child: Text('INTERNAL')),
                  DropdownMenuItem<int>(value: 1, child: Text('MIDI')),
                  DropdownMenuItem<int>(value: 2, child: Text('LINK')),
                ],
              );
            },
          ),
        ],
      ),
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
                  // 240px prevents the FADE row from overflowing the card boundary
                  double cardHeight = 240.0;

                  if (isLooper) {
                    cardWidth = expandedWidth;
                    cardHeight = 450.0;
                  } else {
                    if (size == 'compact') {
                      cardWidth = compactWidth;
                      cardHeight = 110.0;
                    } else if (size == 'regular') {
                      cardWidth = regularWidth;
                      cardHeight = 240.0;
                    } else {
                      // Expanded gain card — taller to accommodate range selector + visualizer
                      cardWidth = expandedWidth;
                      cardHeight = 520.0;
                    }
                  }

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
                    cardWidget = _buildLooperControlPanel(pedal);
                  } else if (isSwitch) {
                    cardWidget = _buildSwitchCard(pedal, size);
                  } else if (isGainOrVolume) {
                    cardWidget = _buildGainCard(pedal, size);
                  } else {
                    cardWidget = _buildPlaceholderCard(pedal, size);
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

  Widget _buildGainCard(PluginInstance pedal, String size) {
    final double currentValue =
        _localVolumes[pedal.instance] ??
        (pedal.gainPortSymbol != null
            ? pedal.parameters[pedal.gainPortSymbol]
            : null) ??
        0.0;

    final double minRange = pedal.minGain;
    final double maxRange = pedal.maxGain;
    final double clampedValue = currentValue.clamp(minRange, maxRange);
    final bool isBypassed = pedal.isBypassed;

    final String colorHex =
        _pedalGlowColors[pedal.instance] ?? _getDefaultColorForPedal(pedal);
    final Color glowColor = _hexToColor(colorHex);
    final Color accentColor = isBypassed ? Colors.grey[600]! : glowColor;
    final bool isMuted = _isMuted(pedal);
    final double cardOpacity = isBypassed ? 0.70 : 1.0;

    final bool isFading = _fadeTimers[pedal.instance] != null;
    final bool isFadingIn  = isFading && (_fadeDirections[pedal.instance] == true);
    final bool isFadingOut = isFading && (_fadeDirections[pedal.instance] == false);

    // Range cursor fractions
    final double rangeStart = _fadeRangeStart[pedal.instance] ?? 0.0;
    final double rangeEnd   = _fadeRangeEnd[pedal.instance]   ?? 1.0;

    // ── Shared slider builder ────────────────────────────────────────
    Widget buildVolumeSlider({bool compact = false}) {
      return SliderTheme(
        data: SliderTheme.of(context).copyWith(
          activeTrackColor: accentColor,
          inactiveTrackColor: _isDarkMode ? Colors.grey[850] : Colors.grey[300],
          trackHeight: compact ? 4.0 : 12.0,
          thumbColor: isBypassed
              ? Colors.grey[400]
              : (_isDarkMode ? Colors.white : Colors.grey[100]),
          thumbShape: RoundSliderThumbShape(
            enabledThumbRadius: compact ? 6.0 : 15.0,
          ),
          overlayColor: accentColor.withOpacity(0.2),
          overlayShape: RoundSliderOverlayShape(
            overlayRadius: compact ? 12.0 : 28.0,
          ),
        ),
        child: Slider(
          value: clampedValue,
          min: minRange,
          max: maxRange,
          onChanged: (newValue) {
            _fadeTimers[pedal.instance]?.cancel();
            if (_mutedVolumes.containsKey(pedal.instance)) {
              _mutedVolumes.remove(pedal.instance);
            }
            setState(() {
              _fadeTimers[pedal.instance]  = null;
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
        ),
      );
    }

    // ── Mini range indicator (compact / regular) ─────────────────────
    Widget buildMiniRangeIndicator() {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 32,
            child: CustomPaint(
              painter: _MiniRangePainter(
                accentColor: accentColor,
                rangeStart: rangeStart,
                rangeEnd: rangeEnd,
              ),
              child: const SizedBox.expand(),
            ),
          ),
          Text(
            '${(rangeStart * 100).round()}–${(rangeEnd * 100).round()}%',
            style: TextStyle(
              fontSize: 8,
              color: accentColor.withOpacity(0.7),
              fontFamily: 'monospace',
            ),
          ),
        ],
      );
    }

    // ── Mute speaker icon ────────────────────────────────────────────
    Widget buildMuteIcon({double size = 22}) {
      return GestureDetector(
        onTap: () => _toggleMute(pedal),
        child: Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Icon(
            isMuted ? Icons.volume_off : Icons.volume_up,
            color: isMuted ? const Color(0xFFFF007F) : accentColor,
            size: size,
          ),
        ),
      );
    }

    // ── Fixed-width dB value box ─────────────────────────────────────
    Widget buildDbBox({double fontSize = 14}) {
      return SizedBox(
        width: 72,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
          decoration: BoxDecoration(
            color: _isDarkMode ? Colors.black : Colors.grey[900],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: accentColor.withOpacity(0.5)),
          ),
          child: Text(
            '${clampedValue >= 0 ? "+" : ""}${clampedValue.toStringAsFixed(1)} dB',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w900,
              color: accentColor,
              fontFamily: 'monospace',
            ),
          ),
        ),
      );
    }

    // ── Size-toggle icon ─────────────────────────────────────────────
    Widget buildSizeToggle() {
      return GestureDetector(
        onTap: () {
          final String current = _pedalSizes[pedal.instance] ?? 'regular';
          final String next = current == 'compact'
              ? 'regular'
              : current == 'regular'
                  ? 'expanded'
                  : 'compact';
          setState(() { _pedalSizes[pedal.instance] = next; });
          _saveLayoutSettings();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Icon(
            Icons.aspect_ratio,
            size: 14,
            color: _isDarkMode ? Colors.grey[500] : Colors.grey[600],
          ),
        ),
      );
    }

    // ── Card shell ───────────────────────────────────────────────────
    return GestureDetector(
      onLongPress: () => _showColorPickerDialog(pedal),
      child: Opacity(
        opacity: cardOpacity,
        child: Container(
          decoration: BoxDecoration(
            color: _isDarkMode ? const Color(0xFF161B22) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: glowColor.withOpacity(isBypassed ? 0.25 : 0.6),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: glowColor.withOpacity(isBypassed ? 0.0 : 0.85),
                blurRadius: 8,
                spreadRadius: 2,
              ),
              BoxShadow(
                color: glowColor.withOpacity(
                  isBypassed ? 0.0 : (_isDarkMode ? 0.20 : 0.35),
                ),
                blurRadius: 80,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(size == 'compact' ? 10.0 : 16.0),

            // ════════════════════════════════════════════
            //  COMPACT VIEW
            // ════════════════════════════════════════════
            child: size == 'compact'
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Row 1: Name | size-toggle | dB
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => _highlightPedalInWebView(pedal),
                              onLongPress: () => _showRenameDialog(pedal),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      (_customTitles[pedal.instance] ?? pedal.title).toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w900,
                                        color: accentColor,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  buildSizeToggle(),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${clampedValue >= 0 ? "+" : ""}${clampedValue.toStringAsFixed(1)} dB',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: accentColor,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      // Row 2: Slider | Mute icon
                      Row(
                        children: [
                          Expanded(child: buildVolumeSlider(compact: true)),
                          const SizedBox(width: 4),
                          buildMuteIcon(size: 18),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // Row 3: [IN/OUT stacked] | mini range indicator
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            flex: 3,
                            child: Column(
                              children: [
                                _buildFadeButton(
                                  label: 'IN',
                                  icon: Icons.trending_up,
                                  isBypassed: isBypassed,
                                  onTap: () => _triggerFade(pedal, fadeIn: true),
                                  accentColor: accentColor,
                                  isFading: isFadingIn,
                                  isCompact: true,
                                ),
                                const SizedBox(height: 2),
                                _buildFadeButton(
                                  label: 'OUT',
                                  icon: Icons.trending_down,
                                  isBypassed: isBypassed,
                                  onTap: () => _triggerFade(pedal, fadeIn: false),
                                  accentColor: accentColor,
                                  isFading: isFadingOut,
                                  isCompact: true,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            flex: 1,
                            child: buildMiniRangeIndicator(),
                          ),
                        ],
                      ),
                    ],
                  )

                // ════════════════════════════════════════════
                //  REGULAR VIEW
                // ════════════════════════════════════════════
                : size == 'regular'
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Row 1 header
                          Row(
                            children: [
                              // Title: tap = highlight, long press = rename
                              Expanded(
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () => _highlightPedalInWebView(pedal),
                                  onLongPress: () => _showRenameDialog(pedal),
                                  child: Text(
                                    (_customTitles[pedal.instance] ?? pedal.title).toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w900,
                                      color: accentColor,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ),
                              // Help icon
                              GestureDetector(
                                onTap: () => _showModuleHelpSheet(context, 'gain'),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  child: Icon(Icons.help_outline, size: 14, color: accentColor.withOpacity(0.7)),
                                ),
                              ),
                              // Size toggle
                              buildSizeToggle(),
                              const SizedBox(width: 4),
                              // Fixed-width dB box
                              buildDbBox(),
                              const SizedBox(width: 4),
                              // Speaker mute icon
                              buildMuteIcon(),
                            ],
                          ),
                          const Spacer(),
                          // URI subtitle
                          GestureDetector(
                            onTap: () => _openPluginUri(pedal.uri),
                            child: Text(
                              pedal.uri,
                              style: TextStyle(
                                fontSize: 8.5,
                                color: _isDarkMode
                                    ? const Color(0xFF00FFCC)
                                    : const Color(0xFF00B3FF),
                                decoration: TextDecoration.underline,
                                fontFamily: 'monospace',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          // Volume slider row
                          Row(
                            children: [
                              Icon(Icons.volume_mute,
                                  color: _isDarkMode
                                      ? Colors.grey[isBypassed ? 700 : 600]
                                      : Colors.grey[isBypassed ? 600 : 700],
                                  size: 20),
                              Expanded(child: buildVolumeSlider()),
                              Icon(Icons.volume_up, color: accentColor, size: 20),
                            ],
                          ),
                          const SizedBox(height: 2),
                          // Min / range bar / max row
                          Row(
                            children: [
                              Text(
                                '${minRange.toStringAsFixed(1)} dB',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: _isDarkMode
                                      ? Colors.grey[isBypassed ? 750 : 650]
                                      : Colors.grey[isBypassed ? 600 : 700],
                                ),
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  child: buildMiniRangeIndicator(),
                                ),
                              ),
                              Text(
                                '${maxRange >= 0 ? "+" : ""}${maxRange.toStringAsFixed(1)} dB',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: _isDarkMode
                                      ? Colors.grey[isBypassed ? 750 : 650]
                                      : Colors.grey[isBypassed ? 600 : 700],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Fade buttons row
                          Row(
                            children: [
                              _buildFadeButton(
                                label: 'FADE IN',
                                icon: Icons.trending_up,
                                isBypassed: isBypassed,
                                onTap: () => _triggerFade(pedal, fadeIn: true),
                                accentColor: accentColor,
                                isFading: isFadingIn,
                              ),
                              _buildFadeButton(
                                label: 'FADE OUT',
                                icon: Icons.trending_down,
                                isBypassed: isBypassed,
                                onTap: () => _triggerFade(pedal, fadeIn: false),
                                accentColor: accentColor,
                                isFading: isFadingOut,
                              ),
                            ],
                          ),
                        ],
                      )

                    // ════════════════════════════════════════════
                    //  EXPANDED VIEW
                    // ════════════════════════════════════════════
                    : _buildExpandedGainCard(
                        pedal: pedal,
                        minRange: minRange,
                        maxRange: maxRange,
                        clampedValue: clampedValue,
                        isBypassed: isBypassed,
                        accentColor: accentColor,
                        isMuted: isMuted,
                        isFadingIn: isFadingIn,
                        isFadingOut: isFadingOut,
                        rangeStart: rangeStart,
                        rangeEnd: rangeEnd,
                        buildVolumeSlider: buildVolumeSlider,
                        buildMuteIcon: buildMuteIcon,
                        buildDbBox: buildDbBox,
                        buildSizeToggle: buildSizeToggle,
                      ),
          ),
        ),
      ),
    );
  }

  /// Expanded gain card body (extracted for readability).
  Widget _buildExpandedGainCard({
    required PluginInstance pedal,
    required double minRange,
    required double maxRange,
    required double clampedValue,
    required bool isBypassed,
    required Color accentColor,
    required bool isMuted,
    required bool isFadingIn,
    required bool isFadingOut,
    required double rangeStart,
    required double rangeEnd,
    required Widget Function({bool compact}) buildVolumeSlider,
    required Widget Function({double size}) buildMuteIcon,
    required Widget Function({double fontSize}) buildDbBox,
    required Widget Function() buildSizeToggle,
  }) {
    // Resolve the selected curve for display
    final String shapeName = _fadeShapes[pedal.instance] ?? 'easeInOut';
    final Curve displayCurve;
    switch (shapeName) {
      case 'linear':   displayCurve = Curves.linear;  break;
      case 'easeIn':   displayCurve = Curves.easeIn;  break;
      case 'easeOut':  displayCurve = Curves.easeOut; break;
      case 'custom':
        final p = _fadeCustomParams[pedal.instance] ?? {};
        displayCurve = _CustomSCurve(
          cx: p['cx'] ?? 0.5,
          cy: p['cy'] ?? 0.5,
          slope: p['slope'] ?? 1.0,
        );
        break;
      default:         displayCurve = Curves.easeInOut;
    }

    final double fadeProgress = _fadeProgress[pedal.instance] ?? 0.0;

    // Custom params (with defaults)
    final Map<String, double> customP =
        _fadeCustomParams[pedal.instance] ?? {'cx': 0.5, 'cy': 0.5, 'slope': 1.0};

    const List<Map<String, String>> shapeOptions = [
      {'key': 'linear',    'label': 'LINEAR'},
      {'key': 'easeInOut', 'label': 'S1'},
      {'key': 'easeIn',    'label': 'S2'},
      {'key': 'easeOut',   'label': 'S3'},
      {'key': 'custom',    'label': 'CUSTOM'},
    ];

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _highlightPedalInWebView(pedal),
                  onLongPress: () => _showRenameDialog(pedal),
                  child: Text(
                    (_customTitles[pedal.instance] ?? pedal.title).toUpperCase(),
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: accentColor,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => _showModuleHelpSheet(context, 'gain'),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(Icons.help_outline, size: 14, color: accentColor.withOpacity(0.7)),
                ),
              ),
              buildSizeToggle(),
              const SizedBox(width: 4),
              buildDbBox(),
              const SizedBox(width: 4),
              buildMuteIcon(),
            ],
          ),
          const SizedBox(height: 4),
          // URI
          GestureDetector(
            onTap: () => _openPluginUri(pedal.uri),
            child: Text(
              pedal.uri,
              style: TextStyle(
                fontSize: 8.5,
                color: _isDarkMode ? const Color(0xFF00FFCC) : const Color(0xFF00B3FF),
                decoration: TextDecoration.underline,
                fontFamily: 'monospace',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(height: 8),

          // ── Volume slider ───────────────────────────────────────────
          Row(
            children: [
              Icon(Icons.volume_mute,
                  color: _isDarkMode
                      ? Colors.grey[isBypassed ? 700 : 600]
                      : Colors.grey[isBypassed ? 600 : 700],
                  size: 20),
              Expanded(child: buildVolumeSlider()),
              Icon(Icons.volume_up, color: accentColor, size: 20),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${minRange.toStringAsFixed(1)} dB',
                  style: TextStyle(fontSize: 10, color: Colors.grey[600])),
              Text('${maxRange >= 0 ? "+" : ""}${maxRange.toStringAsFixed(1)} dB',
                  style: TextStyle(fontSize: 10, color: Colors.grey[600])),
            ],
          ),
          const SizedBox(height: 10),

          // ── Fade Range Selector ─────────────────────────────────────
          Text('FADE RANGE',
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700,
                  color: accentColor.withOpacity(0.7), letterSpacing: 1.2)),
          const SizedBox(height: 2),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: accentColor.withOpacity(0.6),
              inactiveTrackColor: accentColor.withOpacity(0.15),
              thumbColor: accentColor,
              overlayColor: accentColor.withOpacity(0.15),
              rangeThumbShape: const RoundRangeSliderThumbShape(enabledThumbRadius: 10),
              trackHeight: 5,
            ),
            child: RangeSlider(
              values: RangeValues(rangeStart, rangeEnd),
              min: 0.0,
              max: 1.0,
              divisions: 20,
              labels: RangeLabels(
                '${(rangeStart * 100).round()}%',
                '${(rangeEnd * 100).round()}%',
              ),
              onChanged: (RangeValues vals) {
                if (vals.end - vals.start < 0.05) return;
                setState(() {
                  _fadeRangeStart[pedal.instance] = vals.start;
                  _fadeRangeEnd[pedal.instance]   = vals.end;
                });
                _saveLayoutSettings();
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Start: ${(minRange + rangeStart * (maxRange - minRange)).toStringAsFixed(1)} dB',
                style: TextStyle(fontSize: 9, color: accentColor.withOpacity(0.8), fontFamily: 'monospace'),
              ),
              Text(
                'End: ${(minRange + rangeEnd * (maxRange - minRange)).toStringAsFixed(1)} dB',
                style: TextStyle(fontSize: 9, color: accentColor.withOpacity(0.8), fontFamily: 'monospace'),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // ── Fade Shape Selector ─────────────────────────────────────
          Text('FADE SHAPE',
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700,
                  color: accentColor.withOpacity(0.7), letterSpacing: 1.2)),
          const SizedBox(height: 4),
          Row(
            children: shapeOptions.map((opt) {
              final bool isSelected = shapeName == opt['key'];
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() { _fadeShapes[pedal.instance] = opt['key']!; });
                    _saveLayoutSettings();
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? accentColor.withOpacity(0.2)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isSelected ? accentColor : Colors.grey[700]!,
                        width: isSelected ? 1.5 : 1.0,
                      ),
                    ),
                    child: Text(
                      opt['label']!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: isSelected ? accentColor : Colors.grey[500],
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          // ── Custom S-Curve sliders ──────────────────────────────────
          if (shapeName == 'custom') ...[
            const SizedBox(height: 8),
            Text('CUSTOM CURVE',
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700,
                    color: accentColor.withOpacity(0.7), letterSpacing: 1.2)),
            const SizedBox(height: 4),
            ...['cx', 'cy', 'slope'].map((param) {
              final double val = customP[param] ?? 0.5;
              final Map<String, String> labels = {
                'cx': 'CENTER X', 'cy': 'CENTER Y', 'slope': 'BLEND',
              };
              return Row(
                children: [
                  SizedBox(
                    width: 60,
                    child: Text(labels[param]!,
                        style: TextStyle(fontSize: 8, color: Colors.grey[500])),
                  ),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: accentColor.withOpacity(0.7),
                        inactiveTrackColor: accentColor.withOpacity(0.15),
                        thumbColor: accentColor,
                        trackHeight: 3,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                      ),
                      child: Slider(
                        value: val,
                        min: 0.0,
                        max: 1.0,
                        onChanged: (v) {
                          setState(() {
                            _fadeCustomParams[pedal.instance] = {
                              ...customP,
                              param: v,
                            };
                          });
                          _saveLayoutSettings();
                        },
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 32,
                    child: Text(val.toStringAsFixed(2),
                        style: TextStyle(fontSize: 9, fontFamily: 'monospace',
                            color: accentColor.withOpacity(0.8))),
                  ),
                ],
              );
            }),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: () {
                  final String json = jsonEncode({
                    'shape': 'custom',
                    ...customP,
                  });
                  Clipboard.setData(ClipboardData(text: json));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Custom curve copied to clipboard'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    border: Border.all(color: accentColor.withOpacity(0.5)),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'EXPORT',
                    style: TextStyle(fontSize: 9, color: accentColor, letterSpacing: 1),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),

          // ── Live Fade Curve Visualizer ──────────────────────────────
          SizedBox(
            height: 120,
            child: CustomPaint(
              painter: _FadeCurvePainter(
                accentColor: accentColor,
                curve: displayCurve,
                progress: fadeProgress,
                bars: _fadeBars,
                rangeStart: rangeStart,
                rangeEnd: rangeEnd,
              ),
              child: const SizedBox.expand(),
            ),
          ),
          const SizedBox(height: 8),

          // ── Fade buttons ────────────────────────────────────────────
          Row(
            children: [
              _buildFadeButton(
                label: 'FADE IN',
                icon: Icons.trending_up,
                isBypassed: isBypassed,
                onTap: () => _triggerFade(pedal, fadeIn: true),
                accentColor: accentColor,
                isFading: isFadingIn,
              ),
              _buildFadeButton(
                label: 'FADE OUT',
                icon: Icons.trending_down,
                isBypassed: isBypassed,
                onTap: () => _triggerFade(pedal, fadeIn: false),
                accentColor: accentColor,
                isFading: isFadingOut,
              ),
            ],
          ),
        ],
      ),
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
      debugPrint('Error running board sync blink: \$e');
    }
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
      debugPrint('Error highlighting pedal in WebView: \$e');
    }
  }

  void _showRenameDialog(PluginInstance pedal) {
    final currentTitle = _customTitles[pedal.instance] ?? pedal.title;
    final controller = TextEditingController(text: currentTitle);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: _isDarkMode ? const Color(0xFF0F141C) : Colors.white,
          title: Text(
            'RENAME PEDAL',
            style: TextStyle(
              color: _isDarkMode
                  ? const Color(0xFF00FFCC)
                  : const Color(0xFF00B3FF),
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
              fontSize: 16,
            ),
          ),
          content: TextField(
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
            style: TextStyle(color: _isDarkMode ? Colors.white : Colors.black),
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
                backgroundColor: _isDarkMode
                    ? const Color(0xFF00FFCC)
                    : const Color(0xFF00B3FF),
                foregroundColor: _isDarkMode ? Colors.black : Colors.white,
              ),
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  setState(() {
                    _customTitles[pedal.instance] = controller.text.trim();
                  });
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
                // Check looper as well
                if (_looperController.activeLooper != null) {
                  final String looperId =
                      _looperController.activeLooper!.instance;
                  final String looperColor = _pedalGlowColors[looperId] ?? '';
                  if (looperColor.isNotEmpty &&
                      looperColor.toUpperCase() == hex.toUpperCase()) {
                    usageCount++;
                  } else if (looperColor.isEmpty &&
                      hex.toUpperCase() == '#FF0055') {
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

  String? _getSwitchPortSymbol(PluginInstance pedal) {
    for (final symbol in pedal.parameters.keys) {
      final s = symbol.toLowerCase();
      if (s.contains('select') ||
          s.contains('out') ||
          s.contains('route') ||
          s.contains('switch') ||
          s.contains('channel') ||
          s.contains('param')) {
        return symbol;
      }
    }
    return pedal.parameters.isNotEmpty ? pedal.parameters.keys.first : null;
  }

  void _setSwitchPath(PluginInstance pedal, String port, double value) {
    _webSocketService.setParamValue(
      instance: pedal.instance,
      port: port,
      value: value,
    );
    setState(() {
      pedal.parameters[port] = value;
    });
  }

  Widget _buildSwitchCard(PluginInstance pedal, String size) {
    final bool isBypassed = pedal.isBypassed;
    final String displayName = _customTitles[pedal.instance] ?? pedal.title;

    // Detect the routing parameter and its value
    final String? switchPort = _getSwitchPortSymbol(pedal);
    final double currentValue = switchPort != null
        ? (pedal.parameters[switchPort] ?? 0.0)
        : 0.0;

    // Typically: 0 = Path A, 1 = Path B
    final bool isPathB = currentValue >= 0.5;

    // Read the custom glow configuration
    final String colorHex =
        _pedalGlowColors[pedal.instance] ?? _getDefaultColorForPedal(pedal);
    final Color glowColor = _hexToColor(colorHex);

    // Design states based on active status and chosen neon color
    final Color accentColor = isBypassed ? Colors.grey[600]! : glowColor;

    final Color powerIconColor = isBypassed
        ? const Color(0xFFFF007F)
        : glowColor;

    return GestureDetector(
      onLongPress: () => _showColorPickerDialog(pedal),
      child: Opacity(
        opacity: isBypassed ? 0.70 : 1.0,
        child: Container(
          decoration: BoxDecoration(
            color: _isDarkMode ? const Color(0xFF161B22) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: glowColor.withOpacity(isBypassed ? 0.25 : 0.6),
              width: 1.5,
            ),
            boxShadow: [
              // 1. Very bright glow just around the device (small spread/blur)
              BoxShadow(
                color: glowColor.withOpacity(isBypassed ? 0.0 : 0.85),
                blurRadius: 8,
                spreadRadius: 2,
              ),
              // 2. Softer glow that goes further away
              BoxShadow(
                color: glowColor.withOpacity(
                  isBypassed ? 0.0 : (_isDarkMode ? 0.20 : 0.35),
                ),
                blurRadius: 80,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(size == 'compact' ? 10.0 : 16.0),
            child: size == 'compact'
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => _highlightPedalInWebView(pedal),
                              child: Text(
                                displayName.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w900,
                                  color: accentColor,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.edit,
                              size: 12,
                              color: _isDarkMode
                                  ? Colors.grey[500]
                                  : Colors.grey[600],
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => _showRenameDialog(pedal),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: Icon(
                              Icons.help_outline,
                              size: 12,
                              color: accentColor.withOpacity(0.8),
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () =>
                                _showModuleHelpSheet(context, 'switch'),
                          ),
                          const SizedBox(width: 8),
                          // Compact Power Switch
                          GestureDetector(
                            onTap: () {
                              _webSocketService.toggleBypass(
                                instance: pedal.instance,
                                bypass: !isBypassed,
                              );
                            },
                            child: Icon(
                              Icons.power_settings_new,
                              color: powerIconColor,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      // Path selector A/B row
                      Row(
                        children: [
                          Icon(
                            Icons.alt_route,
                            color: _isDarkMode
                                ? Colors.grey[isBypassed ? 700 : 600]
                                : Colors.grey[isBypassed ? 600 : 700],
                            size: 14,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Switch: ${switchPort ?? "None"}',
                              style: TextStyle(
                                fontSize: 9.5,
                                color: _isDarkMode
                                    ? Colors.grey[400]
                                    : Colors.grey[600],
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isBypassed
                                  ? Colors.grey[800]
                                  : (isPathB
                                        ? const Color(
                                            0xFFFF007F,
                                          ).withOpacity(0.12)
                                        : const Color(
                                            0xFF00FFCC,
                                          ).withOpacity(0.12)),
                              foregroundColor: isBypassed
                                  ? Colors.grey
                                  : (isPathB
                                        ? const Color(0xFFFF007F)
                                        : const Color(0xFF00FFCC)),
                              side: BorderSide(
                                color: isBypassed
                                    ? Colors.grey[700]!
                                    : (isPathB
                                          ? const Color(0xFFFF007F)
                                          : const Color(0xFF00FFCC)),
                                width: 1.0,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              minimumSize: const Size(60, 24),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            onPressed: isBypassed || switchPort == null
                                ? null
                                : () {
                                    _webSocketService.setParamValue(
                                      instance: pedal.instance,
                                      port: switchPort,
                                      value: isPathB ? 0.0 : 1.0,
                                    );
                                  },
                            child: Text(
                              isPathB ? 'PATH B' : 'PATH A',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => _highlightPedalInWebView(pedal),
                              child: Tooltip(
                                message: 'Tap to locate in Web interface',
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            displayName.toUpperCase(),
                                            style: TextStyle(
                                              fontSize: 17,
                                              fontWeight: FontWeight.w900,
                                              color: accentColor,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          icon: Icon(
                                            Icons.edit,
                                            size: 14,
                                            color: _isDarkMode
                                                ? Colors.grey[500]
                                                : Colors.grey[600],
                                          ),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          onPressed: () =>
                                              _showRenameDialog(pedal),
                                        ),
                                        const SizedBox(width: 8),
                                        IconButton(
                                          icon: Icon(
                                            Icons.help_outline,
                                            size: 14,
                                            color: accentColor.withOpacity(0.8),
                                          ),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          onPressed: () => _showModuleHelpSheet(
                                            context,
                                            'switch',
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: GestureDetector(
                                            onTap: () =>
                                                _openPluginUri(pedal.uri),
                                            child: Text(
                                              pedal.uri,
                                              style: TextStyle(
                                                fontSize: 8.5,
                                                color: _isDarkMode
                                                    ? const Color(0xFF00FFCC)
                                                    : const Color(0xFF00B3FF),
                                                decoration:
                                                    TextDecoration.underline,
                                                fontFamily: 'monospace',
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Switch: ${switchPort ?? "None"}',
                                          style: TextStyle(
                                            fontSize: 8.5,
                                            color: _isDarkMode
                                                ? Colors.grey[500]
                                                : Colors.grey[750],
                                            fontFamily: 'monospace',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.power_settings_new,
                              color: powerIconColor,
                              size: 26,
                            ),
                            onPressed: () {
                              _webSocketService.toggleBypass(
                                instance: pedal.instance,
                                bypass: !isBypassed,
                              );
                            },
                          ),
                        ],
                      ),
                      const Spacer(),

                      // Custom A / B Switch Control
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // PATH A Button
                          GestureDetector(
                            onTap: isBypassed || switchPort == null
                                ? null
                                : () => _setSwitchPath(pedal, switchPort, 0.0),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: (!isPathB && !isBypassed)
                                    ? const Color(0xFF00FFCC).withOpacity(0.12)
                                    : (_isDarkMode
                                          ? Colors.black.withOpacity(0.3)
                                          : Colors.grey[200]),
                                borderRadius: const BorderRadius.horizontal(
                                  left: Radius.circular(8),
                                ),
                                border: Border.all(
                                  color: (!isPathB && !isBypassed)
                                      ? const Color(0xFF00FFCC)
                                      : (_isDarkMode
                                            ? Colors.grey[800]!
                                            : Colors.grey[400]!),
                                  width: 1.5,
                                ),
                              ),
                              child: Text(
                                'PATH A (CLEAN)',
                                style: TextStyle(
                                  color: (!isPathB && !isBypassed)
                                      ? const Color(0xFF00FFCC)
                                      : (_isDarkMode
                                            ? Colors.grey[600]
                                            : Colors.grey[700]),
                                  fontWeight: FontWeight.w900,
                                  fontSize: 12,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ),
                          ),

                          // PATH B Button
                          GestureDetector(
                            onTap: isBypassed || switchPort == null
                                ? null
                                : () => _setSwitchPath(pedal, switchPort, 1.0),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: (isPathB && !isBypassed)
                                    ? const Color(0xFFFF007F).withOpacity(0.12)
                                    : (_isDarkMode
                                          ? Colors.black.withOpacity(0.3)
                                          : Colors.grey[200]),
                                borderRadius: const BorderRadius.horizontal(
                                  right: Radius.circular(8),
                                ),
                                border: Border.all(
                                  color: (isPathB && !isBypassed)
                                      ? const Color(0xFFFF007F)
                                      : (_isDarkMode
                                            ? Colors.grey[800]!
                                            : Colors.grey[400]!),
                                  width: 1.5,
                                ),
                              ),
                              child: Text(
                                'PATH B (HEAVY)',
                                style: TextStyle(
                                  color: (isPathB && !isBypassed)
                                      ? const Color(0xFFFF007F)
                                      : (_isDarkMode
                                            ? Colors.grey[600]
                                            : Colors.grey[700]),
                                  fontWeight: FontWeight.w900,
                                  fontSize: 12,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildFadeButton({
    required String label,
    required IconData icon,
    required bool isBypassed,
    required VoidCallback onTap,
    required Color accentColor,
    required bool isFading,
    bool isCompact = false,
  }) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: ElevatedButton.icon(
          onPressed: isBypassed ? null : onTap,
          icon: Icon(
            icon,
            size: isCompact ? 10 : 13,
            color: isFading ? const Color(0xFFFF007F) : Colors.black,
          ),
          label: Text(
            label,
            style: TextStyle(
              fontSize: isCompact ? 9 : 11,
              fontWeight: FontWeight.w900,
              letterSpacing: isCompact ? 0.5 : 1.0,
              color: isFading ? const Color(0xFFFF007F) : Colors.black,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: isFading
                ? const Color(0xFFFF007F).withOpacity(0.12)
                : accentColor,
            disabledBackgroundColor: Colors.grey[800],
            padding: EdgeInsets.symmetric(vertical: isCompact ? 4 : 8),
            elevation: isFading ? 4 : 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: isFading
                  ? const BorderSide(color: Color(0xFFFF007F), width: 1.5)
                  : BorderSide.none,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholderCard(PluginInstance pedal, String size) {
    final bool isBypassed = pedal.isBypassed;

    // Read the custom glow configuration
    final String colorHex =
        _pedalGlowColors[pedal.instance] ?? _getDefaultColorForPedal(pedal);
    final Color glowColor = _hexToColor(colorHex);

    // Design states based on active status and chosen neon color
    final Color accentColor = isBypassed ? Colors.grey[600]! : glowColor;

    final Color powerIconColor = isBypassed
        ? const Color(0xFFFF007F)
        : glowColor;

    return GestureDetector(
      onLongPress: () => _showColorPickerDialog(pedal),
      child: Container(
        decoration: BoxDecoration(
          color: _isDarkMode ? const Color(0xFF161B22) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: glowColor.withOpacity(isBypassed ? 0.25 : 0.6),
            width: 1.5,
          ),
          boxShadow: [
            // 1. Very bright glow just around the device (small spread/blur)
            BoxShadow(
              color: glowColor.withOpacity(isBypassed ? 0.0 : 0.85),
              blurRadius: 8,
              spreadRadius: 2,
            ),
            // 2. Softer glow that goes further away
            BoxShadow(
              color: glowColor.withOpacity(
                isBypassed ? 0.0 : (_isDarkMode ? 0.20 : 0.35),
              ),
              blurRadius: 80,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(size == 'compact' ? 10.0 : 16.0),
          child: size == 'compact'
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => _highlightPedalInWebView(pedal),
                            child: Text(
                              (_customTitles[pedal.instance] ?? pedal.title)
                                  .toUpperCase(),
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w900,
                                color: accentColor,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.edit,
                            size: 12,
                            color: _isDarkMode
                                ? Colors.grey[500]
                                : Colors.grey[600],
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => _showRenameDialog(pedal),
                        ),
                        const SizedBox(width: 8),
                        // Compact Power Switch
                        GestureDetector(
                          onTap: () {
                            _webSocketService.toggleBypass(
                              instance: pedal.instance,
                              bypass: !isBypassed,
                            );
                          },
                          child: Icon(
                            Icons.power_settings_new,
                            color: powerIconColor,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: _isDarkMode
                              ? Colors.grey[600]
                              : Colors.grey[750],
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Generic module',
                          style: TextStyle(
                            fontSize: 10,
                            color: _isDarkMode
                                ? Colors.grey[500]
                                : Colors.grey[750],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => _highlightPedalInWebView(pedal),
                            child: Tooltip(
                              message: 'Tap to locate in Web interface',
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          (_customTitles[pedal.instance] ??
                                                  pedal.title)
                                              .toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w900,
                                            color: accentColor,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: Icon(
                                          Icons.edit,
                                          size: 14,
                                          color: _isDarkMode
                                              ? Colors.grey[500]
                                              : Colors.grey[600],
                                        ),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        onPressed: () =>
                                            _showRenameDialog(pedal),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  GestureDetector(
                                    onTap: () => _openPluginUri(pedal.uri),
                                    child: Text(
                                      pedal.uri,
                                      style: TextStyle(
                                        fontSize: 8.5,
                                        color: _isDarkMode
                                            ? const Color(0xFF00FFCC)
                                            : const Color(0xFF00B3FF),
                                        decoration: TextDecoration.underline,
                                        fontFamily: 'monospace',
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.power_settings_new,
                            color: powerIconColor,
                            size: 24,
                          ),
                          onPressed: () {
                            _webSocketService.toggleBypass(
                              instance: pedal.instance,
                              bypass: !isBypassed,
                            );
                          },
                        ),
                      ],
                    ),
                    const Divider(color: Colors.grey, height: 1),
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: _isDarkMode
                              ? Colors.grey[600]
                              : Colors.grey[750],
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Custom card layout coming soon.',
                          style: TextStyle(
                            fontSize: 11,
                            color: _isDarkMode
                                ? Colors.grey[500]
                                : Colors.grey[750],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildWebView() {
    return WebViewWidget(controller: _webViewController);
  }

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

  Widget _buildConnectionPanel() {
    final bool isDisconnected =
        _webSocketService.status == ConnectionStatus.disconnected;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: _isDarkMode ? const Color(0xFF161B22) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getStatusColor(_webSocketService.status).withOpacity(0.2),
          width: 1,
        ),
        boxShadow: _isDarkMode
            ? null
            : [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _ipController,
              decoration: InputDecoration(
                labelText: 'MOD Dwarf IP',
                labelStyle: TextStyle(
                  color: _isDarkMode ? Colors.grey : Colors.grey[700],
                  fontSize: 11,
                ),
                border: InputBorder.none,
                prefixIcon: Icon(
                  Icons.lan,
                  color: _isDarkMode ? Colors.grey : Colors.grey[600],
                  size: 18,
                ),
              ),
              style: TextStyle(
                color: _isDarkMode ? Colors.white : Colors.black,
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
                  ? (_isDarkMode
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
                          ? (_isDarkMode
                                ? const Color(0xFF00FFCC)
                                : const Color(0xFF00B3FF))
                          : const Color(0xFFFF007F))
                      .withOpacity(0.5),
            ),
            onPressed: () {
              if (isDisconnected) {
                _webSocketService.connect(ip: _ipController.text);
                _webViewController.loadRequest(
                  Uri.parse('http://${_ipController.text}'),
                );
              } else {
                _webSocketService.disconnect();
              }
            },
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
              color: _isDarkMode
                  ? const Color(0xFFFF7700)
                  : const Color(0xFFFF5500),
              size: 20,
            ),
            tooltip: 'Open in Chrome / Browser',
            onPressed: _openWebInterface,
          ),
        ],
      ),
    );
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

  Widget _buildBottomToolbar() {
    final primaryColor = _isDarkMode
        ? const Color(0xFF00FFCC)
        : const Color(0xFF00B3FF);
    final accentColor = const Color(0xFFFF007F);
    final isConnected = _webSocketService.status == ConnectionStatus.connected;

    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: _isDarkMode ? const Color(0xFF0F141C) : const Color(0xFFE4E6EB),
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
                isActive: _showControls,
                onTap: () {
                  if (_showControls && !_showWeb) return;
                  setState(() {
                    _showControls = !_showControls;
                  });
                },
                onLongPress: () {
                  setState(() {
                    _showControls = true;
                    _showWeb = false;
                  });
                },
              ),
              const SizedBox(width: 8),
              _buildLayoutButton(
                icon: Icons.language,
                tooltip: 'Toggle Web interface',
                isActive: _showWeb,
                onTap: () {
                  if (_showWeb && !_showControls) return;
                  setState(() {
                    _showWeb = !_showWeb;
                  });
                },
                onLongPress: () {
                  setState(() {
                    _showWeb = true;
                    _showControls = false;
                  });
                },
              ),
            ],
          ),

          // Center: Radar locate & Reload pedalboard
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.radar, color: accentColor, size: 20),
                tooltip: 'Glow all Workspace Pedals in Web GUI',
                onPressed: isConnected ? _highlightAllPedalsInWebView : null,
              ),
              const SizedBox(width: 12),
              IconButton(
                icon: Icon(
                  Icons.refresh,
                  color: _isDarkMode
                      ? const Color(0xFF00FFCC)
                      : const Color(0xFF009977),
                  size: 20,
                ),
                tooltip: 'Refresh Pedalboard',
                onPressed: isConnected
                    ? () => _webSocketService.requestPedalboard()
                    : null,
              ),
            ],
          ),

          // Right: Theme Toggler & Version Label
          Row(
            children: [
              IconButton(
                icon: Icon(
                  _isDarkMode
                      ? Icons.wb_sunny_outlined
                      : Icons.nightlight_round,
                  color: _isDarkMode
                      ? const Color(0xFFFF7700)
                      : const Color(0xFF9D00FF),
                  size: 20,
                ),
                tooltip: _isDarkMode
                    ? 'Switch to Daylight Theme'
                    : 'Switch to Midnight Theme',
                onPressed: () {
                  setState(() {
                    _isDarkMode = !_isDarkMode;
                  });
                  _saveThemeSettings();
                },
              ),
              const SizedBox(width: 8),
              Text(
                'v$kAppVersion',
                style: TextStyle(
                  color: _isDarkMode ? Colors.grey[500] : Colors.grey[600],
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

  String _getPedalboardKey() {
    final plugins = _webSocketService.allPlugins.value;
    if (plugins.isEmpty) return 'default_pedalboard';
    final List<String> instances = plugins.map((p) => p.instance).toList()
      ..sort();
    return 'pedalboard_${instances.join(',').hashCode}';
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
      // Fade settings
      await prefs.setString('${key}_fadeRangeStart', jsonEncode(_fadeRangeStart));
      await prefs.setString('${key}_fadeRangeEnd',   jsonEncode(_fadeRangeEnd));
      await prefs.setString('${key}_fadeShapes',     jsonEncode(_fadeShapes));
      // Encode nested map: Map<String, Map<String, double>>
      final customEncoded = _fadeCustomParams.map(
        (k, v) => MapEntry(k, jsonEncode(v)),
      );
      await prefs.setString('${key}_fadeCustomParams', jsonEncode(customEncoded));
      debugPrint('Saved layout settings for $key');
    } catch (e) {
      debugPrint('Error saving layout settings: $e');
    }
  }

  String _getDefaultColorForInstanceId(String instanceId) {
    if (instanceId.toLowerCase().contains('alo')) {
      return '#FF0055';
    }
    final plugins = _webSocketService.allPlugins.value;
    for (final p in plugins) {
      if (p.instance == instanceId) {
        final uriLower = p.uri.toLowerCase();
        final titleLower = p.title.toLowerCase();
        if (uriLower.contains('alo') || titleLower.contains('alo')) {
          return '#FF0055';
        }
        break;
      }
    }
    final int hash = instanceId.hashCode.abs();
    return kNeonColors[hash % kNeonColors.length];
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
      if (uriLower.contains('alo') || titleLower.contains('alo')) {
        return; // Forced expanded
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

    final int crossAxisCount = controlsWidth > 600 ? 2 : 1;
    final int rowIndex = index ~/ crossAxisCount;
    final double scrollOffset = rowIndex * (225.0 + 16.0);

    if (_cardsScrollController.hasClients) {
      _cardsScrollController.animateTo(
        scrollOffset.clamp(
          0.0,
          _cardsScrollController.position.maxScrollExtent,
        ),
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOutCubic,
      );
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
          color: _isDarkMode ? Colors.grey[500] : Colors.grey[600],
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
              color: _isDarkMode ? Colors.grey[350] : Colors.grey[800],
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

  Widget _buildLeftDrawerContent() {
    final status = _webSocketService.status;
    final isConnected = status == ConnectionStatus.connected;
    final int activeCount = _enabledPluginInstances.length;
    final int totalCount = _webSocketService.allPlugins.value.length;

    return Container(
      color: _isDarkMode ? const Color(0xFF0F141C) : Colors.white,
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
                colors: _isDarkMode
                    ? [const Color(0xFF161B22), const Color(0xFF0F141C)]
                    : [const Color(0xFFE4E6EB), const Color(0xFFF0F2F5)],
              ),
              border: Border(
                bottom: BorderSide(
                  color: _isDarkMode
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
                      colors: _isDarkMode
                          ? [const Color(0xFF00FFCC), const Color(0xFFFF007F)]
                          : [const Color(0xFF00B3FF), const Color(0xFFFF0055)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color:
                            (_isDarkMode
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
                          color: _isDarkMode ? Colors.white : Colors.black,
                        ),
                      ),
                      Text(
                        'LIVE CONTROLLER',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: _isDarkMode
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
                  color: _isDarkMode
                      ? const Color(0xFF00FFCC)
                      : const Color(0xFF00B3FF),
                ),
                _buildLeftDrawerTile(
                  icon: Icons.speed,
                  title: 'BPM / Tempo',
                  trailingText: '${_bpm.toStringAsFixed(0)} BPM',
                  color: const Color(0xFFFF007F),
                ),
                _buildLeftDrawerTile(
                  icon: Icons.link,
                  title: 'Connection State',
                  trailingText: isConnected ? 'CONNECTED' : 'DISCONNECTED',
                  color: _getStatusColor(status),
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
                      color: _isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                  subtitle: const Text(
                    'strobe pulses on the web canvas',
                    style: TextStyle(fontSize: 10),
                  ),
                  onTap: isConnected
                      ? () {
                          Navigator.pop(context);
                          _highlightAllPedalsInWebView();
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
                      color: _isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                  subtitle: const Text(
                    'query parameters from mod dwarf',
                    style: TextStyle(fontSize: 10),
                  ),
                  onTap: isConnected
                      ? () {
                          Navigator.pop(context);
                          _webSocketService.requestPedalboard();
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
                      color: _isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                  subtitle: const Text(
                    'launch Web interface in Chrome',
                    style: TextStyle(fontSize: 10),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _openWebInterface();
                  },
                ),
                ListTile(
                  leading: Icon(
                    _isDarkMode ? Icons.light_mode : Icons.dark_mode,
                    color: _isDarkMode
                        ? const Color(0xFFFF7700)
                        : const Color(0xFF9D00FF),
                    size: 20,
                  ),
                  title: Text(
                    _isDarkMode ? 'Daylight Theme' : 'Midnight Theme',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: _isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                  subtitle: const Text(
                    'optimize display for direct sunlight',
                    style: TextStyle(fontSize: 10),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _isDarkMode = !_isDarkMode;
                    });
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
                  color: _isDarkMode
                      ? const Color(0xFF161B22)
                      : const Color(0xFFE4E6EB),
                  width: 1,
                ),
              ),
            ),
            child: Text(
              'VERSION $kAppVersion',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
                color: _isDarkMode
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

  Widget _buildDrawerHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: _isDarkMode ? const Color(0xFF0F141C) : Colors.grey[200],
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'WORKSPACE SETTINGS',
            style: TextStyle(
              color: _isDarkMode
                  ? const Color(0xFF00FFCC)
                  : const Color(0xFF00B3FF),
              fontSize: 15,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.close,
              color: _isDarkMode ? Colors.grey : Colors.grey[600],
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerContent() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double drawerWidth = constraints.maxWidth;
        final double horizontalPadding = 12.0;
        final double spacing = 6.0;
        // Account for container margin (10px each side) + container padding (6px each side)
        // so that two regularWidth tiles actually fit in a Wrap row.
        final double tileAreaWidth =
            drawerWidth - horizontalPadding * 2 - 10 * 2 - 6 * 2;
        final double gridWidth = tileAreaWidth;

        // 4 Columns available width calculation
        final double totalColumnWidth = gridWidth - (spacing * 3);
        final double colWidth = totalColumnWidth / 4;

        final double compactWidth = colWidth;
        final double regularWidth = (colWidth * 2) + spacing;
        final double expandedWidth = gridWidth;

        return ValueListenableBuilder<List<PluginInstance>>(
          valueListenable: _webSocketService.allPlugins,
          builder: (context, allPlugins, _) {
            // Hydrate active list based on saved order & visibility
            final List<PluginInstance> activePedals = [];
            for (final id in _orderedPluginInstances) {
              if (_enabledPluginInstances.contains(id)) {
                final pedal = allPlugins.firstWhere(
                  (p) => p.instance == id,
                  orElse: () =>
                      PluginInstance(instance: '', title: '', uri: ''),
                );
                if (pedal.instance.isNotEmpty) {
                  activePedals.add(pedal);
                }
              }
            }

            // Hydrate inactive list
            final List<PluginInstance> inactivePedals = [];
            for (final id in _orderedPluginInstances) {
              if (!_enabledPluginInstances.contains(id)) {
                final pedal = allPlugins.firstWhere(
                  (p) => p.instance == id,
                  orElse: () =>
                      PluginInstance(instance: '', title: '', uri: ''),
                );
                if (pedal.instance.isNotEmpty) {
                  inactivePedals.add(pedal);
                }
              }
            }

            return Column(
              children: [
                _buildDrawerHeader(),

                // ACTIVE PUZZLE CANVAS
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.extension,
                        size: 15,
                        color: _isDarkMode
                            ? const Color(0xFF00FFCC)
                            : const Color(0xFF00B3FF),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'PUZZLE CANVAS (ACTIVE)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 10.5,
                          color: _isDarkMode ? Colors.grey : Colors.grey[750],
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  flex: 3,
                  child: DragTarget<String>(
                    onAccept: (draggedId) {
                      // Drag from Inactive or general drop to activate/reorder to the end
                      setState(() {
                        if (!_enabledPluginInstances.contains(draggedId)) {
                          _enabledPluginInstances.add(draggedId);
                        }

                        // Move to end of active list in _orderedPluginInstances
                        final List<String> actives = _orderedPluginInstances
                            .where((id) => _enabledPluginInstances.contains(id) && id != draggedId)
                            .toList();

                        _orderedPluginInstances.remove(draggedId);
                        if (actives.isNotEmpty) {
                          final lastActiveId = actives.last;
                          final targetIdx = _orderedPluginInstances.indexOf(lastActiveId);
                          if (targetIdx != -1) {
                            _orderedPluginInstances.insert(targetIdx + 1, draggedId);
                          } else {
                            _orderedPluginInstances.add(draggedId);
                          }
                        } else {
                          _orderedPluginInstances.insert(0, draggedId);
                        }

                        // Also sync _enabledPluginInstances order
                        _enabledPluginInstances.remove(draggedId);
                        _enabledPluginInstances.add(draggedId);
                      });
                      _updateAllGlowsInWebView();
                      _saveLayoutSettings();
                    },
                    builder: (context, _, __) {
                      return Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 2,
                        ),
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: _isDarkMode
                              ? const Color(0xFF0F141C).withOpacity(0.5)
                              : Colors.grey[100],
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: (_isDarkMode
                                ? Colors.grey[850]
                                : Colors.grey[300])!,
                            width: 1.5,
                          ),
                        ),
                        child: activePedals.isEmpty
                            ? Center(
                                child: Text(
                                  'Drag cards here or toggle below to activate.',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: _isDarkMode
                                        ? Colors.grey[650]
                                        : Colors.grey[500],
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              )
                            : SingleChildScrollView(
                                child: Wrap(
                                  spacing: spacing,
                                  runSpacing: spacing,
                                  alignment: WrapAlignment.start,
                                  runAlignment: WrapAlignment.start,
                                  crossAxisAlignment: WrapCrossAlignment.start,
                                  children: activePedals.map((pedal) {
                                    return _buildMiniPuzzleTile(
                                      pedal: pedal,
                                      isActive: true,
                                      cWidth: compactWidth,
                                      rWidth: regularWidth,
                                      eWidth: expandedWidth,
                                    );
                                  }).toList(),
                                ),
                              ),
                      );
                    },
                  ),
                ),

                // INACTIVE / AVAILABLE POOL
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 15,
                        color: inactivePedals.isEmpty
                            ? Colors.grey
                            : (_isDarkMode
                                  ? const Color(0xFFFF007F)
                                  : const Color(0xFFFF0055)),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'AVAILABLE POOL (INACTIVE)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 10.5,
                          color: _isDarkMode ? Colors.grey : Colors.grey[750],
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  flex: 2,
                  child: DragTarget<String>(
                    onAccept: (draggedId) {
                      // Drag from Active to Inactive
                      if (_enabledPluginInstances.contains(draggedId)) {
                        setState(() {
                          _enabledPluginInstances.remove(draggedId);
                        });
                        _updateAllGlowsInWebView();
                        _saveLayoutSettings();
                      }
                    },
                    builder: (context, _, __) {
                      return Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 2,
                        ),
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: _isDarkMode
                              ? const Color(0xFF0F141C).withOpacity(0.3)
                              : Colors.grey[50],
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: (_isDarkMode
                                ? Colors.grey[900]
                                : Colors.grey[200])!,
                            style: BorderStyle.solid,
                          ),
                        ),
                        child: inactivePedals.isEmpty
                            ? Center(
                                child: Text(
                                  'All components are active.',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: _isDarkMode
                                        ? Colors.grey[650]
                                        : Colors.grey[500],
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              )
                            : SingleChildScrollView(
                                child: Wrap(
                                  spacing: spacing,
                                  runSpacing: spacing,
                                  children: inactivePedals.map((pedal) {
                                    return _buildMiniPuzzleTile(
                                      pedal: pedal,
                                      isActive: false,
                                      cWidth: compactWidth,
                                      rWidth: regularWidth,
                                      eWidth: expandedWidth,
                                    );
                                  }).toList(),
                                ),
                              ),
                      );
                    },
                  ),
                ),


              ],
            );
          },
        );
      },
    );
  }

  Widget _buildMiniPuzzleTile({
    required PluginInstance pedal,
    required bool isActive,
    required double cWidth,
    required double rWidth,
    required double eWidth,
  }) {
    final String instanceId = pedal.instance;
    final size = _pedalSizes[instanceId] ?? 'regular';

    final uriLower = pedal.uri.toLowerCase();
    final titleLower = pedal.title.toLowerCase();
    final isLooper = uriLower.contains('alo') || titleLower.contains('alo') || instanceId.toLowerCase().contains('alo');
    final isSwitch =
        uriLower.contains('switch') || titleLower.contains('switch');

    double width = rWidth;
    double height = 46.0;
    if (isActive) {
      if (isLooper) {
        width = eWidth;
        height = 56.0;
      } else if (size == 'compact') {
        width = cWidth;
        height = 40.0;
      } else if (size == 'regular') {
        width = rWidth;
        height = 48.0;
      } else {
        width = eWidth;
        height = 56.0;
      }
    } else {
      // Inactive tiles always show regular sizing for grid visual consistency in pool
      width = rWidth;
      height = 46.0;
    }

    final String colorHex =
        _pedalGlowColors[instanceId] ?? _getDefaultColorForPedal(pedal);
    final Color glowColor = _hexToColor(colorHex);

    IconData typeIcon = Icons.help_outline;
    if (isLooper) {
      typeIcon = Icons.fiber_manual_record; // red looper dot
    } else if (isSwitch) {
      typeIcon = Icons.swap_horiz;
    } else {
      typeIcon = Icons.adjust; // rotary volume knob
    }

    final tileContent = Container(
      width: width,
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: isActive
            ? glowColor.withOpacity(_isDarkMode ? 0.12 : 0.18)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: glowColor.withOpacity(isActive ? 0.9 : 0.4),
          width: isActive ? 1.5 : 1.0,
          style: isActive ? BorderStyle.solid : BorderStyle.solid,
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: glowColor.withOpacity(0.3),
                  blurRadius: 4,
                  spreadRadius: 0.5,
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          // Device Type Icon
          Icon(
            typeIcon,
            size: size == 'compact' && isActive ? 11 : 13,
            color: isLooper && isActive ? const Color(0xFFFF0055) : glowColor,
          ),
          const SizedBox(width: 4),

          // Title
          Expanded(
            child: Text(
              (_customTitles[instanceId] ?? pedal.title).toUpperCase(),
              style: TextStyle(
                color: isActive
                    ? (_isDarkMode ? Colors.white : Colors.black)
                    : (_isDarkMode ? Colors.grey[400] : Colors.grey[750]),
                fontWeight: FontWeight.bold,
                fontSize: size == 'compact' && isActive ? 8 : 9.5,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),

          // Right panel options
          if (isActive) ...[
            // Size Toggle C/R/E (non-loopers only)
            if (!isLooper)
              GestureDetector(
                onTap: () => _cyclePedalSize(instanceId),
                child: Container(
                  margin: const EdgeInsets.only(right: 4),
                  padding: const EdgeInsets.all(2.5),
                  decoration: BoxDecoration(
                    color: _isDarkMode ? Colors.grey[900] : Colors.grey[300],
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    size[0].toUpperCase(),
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      color: _isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );

    // Draggable wrapping
    return DragTarget<String>(
      onWillAccept: (data) => data != instanceId,
      onAccept: (draggedId) {
        setState(() {
          // Reorder list order
          final idxA = _orderedPluginInstances.indexOf(draggedId);
          final idxB = _orderedPluginInstances.indexOf(instanceId);
          if (idxA != -1 && idxB != -1) {
            final item = _orderedPluginInstances.removeAt(idxA);
            _orderedPluginInstances.insert(idxB, item);
          }

          // If dragged item was inactive, activate it at target index
          if (!_enabledPluginInstances.contains(draggedId)) {
            _enabledPluginInstances.add(draggedId);
          }

          // Also sync reorder inside active visibility list
          final activeA = _enabledPluginInstances.indexOf(draggedId);
          final activeB = _enabledPluginInstances.indexOf(instanceId);
          if (activeA != -1 && activeB != -1 && activeA != activeB) {
            final item = _enabledPluginInstances.removeAt(activeA);
            _enabledPluginInstances.insert(activeB, item);
          }
        });
        _updateAllGlowsInWebView();
        _saveLayoutSettings();
      },
      builder: (context, _, __) {
        return LongPressDraggable<String>(
          data: instanceId,
          feedback: Material(
            color: Colors.transparent,
            child: Opacity(
              opacity: 0.7,
              child: Container(
                width: width,
                height: height,
                decoration: BoxDecoration(
                  color: glowColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: glowColor, width: 2.0),
                ),
                child: Center(
                  child: Text(
                    (_customTitles[instanceId] ?? pedal.title).toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
              ),
            ),
          ),
          childWhenDragging: Opacity(
            opacity: 0.25,
            child: Container(
              width: width,
              height: height,
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          child: GestureDetector(
            onTap: () {
              _highlightPedalInWebView(pedal);
              if (isActive) {
                _scrollToCard(instanceId);
              }
            },
            onDoubleTap: () => _showColorPickerDialog(pedal),
            child: tileContent,
          ),
        );
      },
    );
  }

  void _showModuleHelpSheet(BuildContext context, String moduleKey) {
    final help = ModuleHelpData.registry[moduleKey];
    if (help == null) return;

    final primaryThemeColor = _isDarkMode
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
                color: _isDarkMode ? const Color(0xFF0F141C) : Colors.white,
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
                      color: _isDarkMode ? Colors.grey[800] : Colors.grey[300],
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
                                  color: _isDarkMode
                                      ? Colors.white
                                      : Colors.black,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'TamperMod Companion Documentation',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: _isDarkMode
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
                            color: _isDarkMode
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
                    color: _isDarkMode ? Colors.grey[900] : Colors.grey[300],
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
                            color: _isDarkMode
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
                                        color: _isDarkMode
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
                                    color: _isDarkMode
                                        ? Colors.black
                                        : Colors.grey[200],
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: _isDarkMode
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
                                      color: _isDarkMode
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
                            color: _isDarkMode
                                ? Colors.black.withOpacity(0.3)
                                : Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _isDarkMode
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
                              color: _isDarkMode
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

  Widget _buildHelpSectionHeader(String title, IconData icon, Color color) {
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

  String? _findPortSymbol(PluginInstance pedal, String keyword) {
    final keywordLower = keyword.toLowerCase();
    for (final k in pedal.parameters.keys) {
      if (k.toLowerCase().contains(keywordLower)) {
        return k;
      }
    }
    return null;
  }

  Widget _buildLooperControlPanel(PluginInstance pedal) {
    return AnimatedBuilder(
      animation: _looperController,
      builder: (context, _) {
        final String looperId = pedal.instance;
        final String colorHex =
            _pedalGlowColors[looperId] ?? _getDefaultColorForPedal(pedal);
        final Color glowColor = _hexToColor(colorHex);

        final primaryThemeColor = _isDarkMode
            ? const Color(0xFF00FFCC)
            : const Color(0xFF00B3FF);
        final Color looperAccentColor = glowColor;

        // Find symbols dynamically
        final String thresholdPort =
            _findPortSymbol(pedal, 'threshold') ?? 'threshold';
        final String clickPort =
            _findPortSymbol(pedal, 'click') ??
            _findPortSymbol(pedal, 'metronome') ??
            'click';
        final String mixPort =
            _findPortSymbol(pedal, 'mix') ??
            _findPortSymbol(pedal, 'dry') ??
            'mix';

        final double thresholdValue = pedal.parameters[thresholdPort] ?? -30.0;
        final double clickValue = pedal.parameters[clickPort] ?? 0;
        final double mixValue = pedal.parameters[mixPort] ?? 1.0;

        return GestureDetector(
          onLongPress: () => _showColorPickerDialog(pedal),
          child: Container(
            decoration: BoxDecoration(
              color: _isDarkMode ? const Color(0xFF161B22) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: glowColor.withOpacity(_isDarkMode ? 0.35 : 0.65),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: glowColor.withOpacity(0.85),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: glowColor.withOpacity(_isDarkMode ? 0.20 : 0.35),
                  blurRadius: 80,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title / Header Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => _highlightPedalInWebView(pedal),
                          child: Row(
                            children: [
                              Icon(
                                Icons.music_video,
                                color: looperAccentColor,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  (_customTitles[pedal.instance] ?? pedal.title)
                                      .toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.0,
                                    color: _isDarkMode
                                        ? Colors.white
                                        : Colors.black,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                icon: Icon(
                                  Icons.edit,
                                  size: 13,
                                  color: _isDarkMode
                                      ? Colors.grey[500]
                                      : Colors.grey[600],
                                ),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () => _showRenameDialog(pedal),
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                icon: Icon(
                                  Icons.help_outline,
                                  size: 14,
                                  color: primaryThemeColor.withOpacity(0.8),
                                ),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () =>
                                    _showModuleHelpSheet(context, 'looper'),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Metronome BPM indicator/badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _isDarkMode ? Colors.black : Colors.grey[200],
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: primaryThemeColor.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.query_builder,
                              size: 12,
                              color: primaryThemeColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${_bpm.toStringAsFixed(1)} BPM',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'monospace',
                                color: primaryThemeColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Divider(
                    color: (_isDarkMode ? Colors.grey[850] : Colors.grey[300])
                        ?.withOpacity(0.5),
                    height: 1,
                  ),
                  const SizedBox(height: 8),

                  // Scrollable tracks and sliders to prevent overflow
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          // Track 1
                          SizedBox(
                            height: 140,
                            child: _buildLooperTrackSegment(
                              1,
                              looperAccentColor,
                              pedal,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Track 2
                          SizedBox(
                            height: 140,
                            child: _buildLooperTrackSegment(
                              2,
                              looperAccentColor,
                              pedal,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Divider(
                            color:
                                (_isDarkMode
                                        ? Colors.grey[850]
                                        : Colors.grey[300])
                                    ?.withOpacity(0.5),
                            height: 1,
                          ),
                          const SizedBox(height: 12),

                          // Sliders Column at bottom
                          Column(
                            children: [
                              _buildLooperSlider(
                                label: 'Threshold',
                                value: thresholdValue,
                                min: -60.0,
                                max: 0.0,
                                valueSuffix: ' dB',
                                accentColor: looperAccentColor,
                                onChanged: (val) {
                                  setState(() {
                                    pedal.parameters[thresholdPort] = val;
                                  });
                                  _webSocketService.setParamValue(
                                    instance: pedal.instance,
                                    port: thresholdPort,
                                    value: double.parse(val.toStringAsFixed(2)),
                                  );
                                },
                              ),
                              const SizedBox(height: 6),
                              _buildLooperSlider(
                                label: 'Mix Setting',
                                value: mixValue,
                                min: 0.0,
                                max: 1.0,
                                isPercentage: true,
                                accentColor: looperAccentColor,
                                onChanged: (val) {
                                  setState(() {
                                    pedal.parameters[mixPort] = val;
                                  });
                                  _webSocketService.setParamValue(
                                    instance: pedal.instance,
                                    port: mixPort,
                                    value: double.parse(val.toStringAsFixed(2)),
                                  );
                                },
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  SizedBox(
                                    width: 90,
                                    child: Text(
                                      'Click Volume',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: _isDarkMode ? Colors.grey[300] : Colors.grey[750],
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: SliderTheme(
                                      data: SliderTheme.of(context).copyWith(
                                        activeTrackColor: looperAccentColor,
                                        inactiveTrackColor: _isDarkMode
                                            ? Colors.grey[850]
                                            : Colors.grey[300],
                                        trackHeight: 4.0,
                                        thumbColor: _isDarkMode ? Colors.white : Colors.grey[100],
                                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
                                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 12.0),
                                      ),
                                      child: Slider(
                                        value: (clickValue).clamp(0, 10),
                                        min: 0,
                                        max: 10,
                                        divisions: 9,
                                        onChanged: (val) {
                                          final targetVal = val;
                                          setState(() {
                                            pedal.parameters[clickPort] = targetVal;
                                          });
                                          _webSocketService.setParamValue(
                                            instance: pedal.instance,
                                            port: clickPort,
                                            value: double.parse(targetVal.toStringAsFixed(2)),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  SizedBox(
                                    width: 50,
                                    child: Text(
                                      (clickValue).round().toString(),
                                      textAlign: TextAlign.end,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w900,
                                        color: looperAccentColor,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLooperTrackSegment(
    int loopNum,
    Color glowColor,
    PluginInstance pedal,
  ) {
    final state = _looperController.getState(loopNum);

    Color stateColor;
    String stateText = '';
    IconData stateIcon;
    bool isPulsing = false;

    switch (state) {
      case LooperState.empty:
        stateColor = Colors.grey[600]!;
        stateText = 'Empty Loop';
        stateIcon = Icons.music_note_outlined;
        break;
      case LooperState.countIn:
        stateColor = Colors.orange;
        stateText =
            'COUNT-IN (Rec in ${((16 - _looperController.getCurrentBeatIndex(loopNum)) * _looperController.beatDurationMs / 1000).toStringAsFixed(1)}s)';
        stateIcon = Icons.hourglass_top;
        isPulsing = true;
        break;
      case LooperState.recording:
        stateColor = const Color(0xFFFF0055);
        stateText =
            'RECORDING (Beat ${_looperController.getCurrentBeatIndex(loopNum) + 1}/16)';
        stateIcon = Icons.fiber_manual_record;
        isPulsing = true;
        break;
      case LooperState.playing:
        stateColor = glowColor;
        stateText =
            'PLAYING LOOP (Bar ${_looperController.getCurrentBar(loopNum)}, Beat ${_looperController.getCurrentBeatInBar(loopNum)})';
        stateIcon = Icons.play_arrow;
        break;
      case LooperState.paused:
        stateColor = Colors.amber;
        stateText = 'PAUSED';
        stateIcon = Icons.pause;
        break;
    }

    Widget stateIndicator = Icon(stateIcon, color: stateColor, size: 14);
    if (isPulsing) {
      stateIndicator = _PulsingIndicator(icon: stateIcon, color: stateColor);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Track Header Info
        Row(
          children: [
            Text(
              'LOOP $loopNum',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: state == LooperState.empty
                    ? Colors.grey[500]
                    : glowColor,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(width: 8),
            stateIndicator,
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                stateText,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: stateColor,
                  letterSpacing: 0.5,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),

        // Track timeline
        _build4BarTimeline(loopNum, stateColor),
        const SizedBox(height: 6),

        // Track actions row
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      (state == LooperState.countIn ||
                          state == LooperState.recording)
                      ? Colors.grey[800]
                      : const Color(0xFFFF0055),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                icon: Icon(
                  (state == LooperState.countIn ||
                          state == LooperState.recording)
                      ? Icons.cancel
                      : Icons.fiber_manual_record,
                  size: 12,
                ),
                label: Text(
                  (state == LooperState.countIn ||
                          state == LooperState.recording)
                      ? 'CANCEL'
                      : 'RECORD 4-BAR',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
                onPressed: () {
                  if (state == LooperState.countIn ||
                      state == LooperState.recording) {
                    _looperController.clearLoop(loopNum);
                  } else {
                    _looperController.recordSequence(loopNum);
                  }
                },
              ),
            ),
            const SizedBox(width: 6),

            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _isDarkMode
                    ? Colors.black.withOpacity(0.4)
                    : Colors.grey[200],
                foregroundColor: _isDarkMode ? Colors.white : Colors.black,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                minimumSize: const Size(40, 28),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                  side: BorderSide(
                    color: _isDarkMode ? Colors.grey[800]! : Colors.grey[400]!,
                  ),
                ),
              ),
              onPressed: (state == LooperState.playing)
                  ? () => _looperController.pauseLoop(loopNum)
                  : (state == LooperState.paused)
                  ? () => _looperController.playLoop(loopNum)
                  : null,
              child: Icon(
                (state == LooperState.paused) ? Icons.play_arrow : Icons.pause,
                size: 14,
              ),
            ),
            const SizedBox(width: 6),

            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber.withOpacity(0.12),
                foregroundColor: Colors.amber,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                minimumSize: const Size(40, 28),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                  side: const BorderSide(color: Colors.amber),
                ),
              ),
              onPressed: (state != LooperState.empty)
                  ? () => _looperController.clearLoop(loopNum)
                  : null,
              child: const Icon(Icons.delete_outline, size: 14),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLooperSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required Color accentColor,
    required ValueChanged<double> onChanged,
    String valueSuffix = '',
    bool isPercentage = false,
  }) {
    final displayValue = isPercentage
        ? (value * 100).toStringAsFixed(0) + '%'
        : value.toStringAsFixed(1) + valueSuffix;
    return Row(
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: _isDarkMode ? Colors.grey[300] : Colors.grey[750],
            ),
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: accentColor,
              inactiveTrackColor: _isDarkMode
                  ? Colors.grey[850]
                  : Colors.grey[300],
              trackHeight: 4.0,
              thumbColor: _isDarkMode ? Colors.white : Colors.grey[100],
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12.0),
            ),
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 50,
          child: Text(
            displayValue,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: accentColor,
              fontFamily: 'monospace',
            ),
          ),
        ),
      ],
    );
  }

  Widget _build4BarTimeline(int loopNum, Color stateColor) {
    final state = _looperController.getState(loopNum);
    final progress = _looperController.getSweepProgress(loopNum);
    final currentBar = _looperController.getCurrentBar(loopNum);
    final currentBeatIndex = _looperController.getCurrentBeatIndex(loopNum);

    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: _isDarkMode ? Colors.black.withOpacity(0.5) : Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _isDarkMode ? Colors.grey[900]! : Colors.grey[300]!,
        ),
      ),
      child: Stack(
        children: [
          if (state == LooperState.recording)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              right: 0,
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: progress,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF0055).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(7),
                  ),
                ),
              ),
            ),

          Row(
            children: List.generate(4, (barIndex) {
              final isCurrentBar =
                  (state != LooperState.empty) && (currentBar == barIndex + 1);
              return Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border(
                      right: barIndex < 3
                          ? BorderSide(
                              color: _isDarkMode
                                  ? Colors.grey[900]!
                                  : Colors.grey[350]!,
                              width: 1,
                            )
                          : BorderSide.none,
                    ),
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: Text(
                          'BAR ${barIndex + 1}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: isCurrentBar
                                ? FontWeight.w900
                                : FontWeight.bold,
                            color: isCurrentBar
                                ? stateColor
                                : (_isDarkMode
                                      ? Colors.grey[700]
                                      : Colors.grey[400]),
                          ),
                        ),
                      ),

                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 4,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: List.generate(4, (beatIndex) {
                            final globalBeatIndex = barIndex * 4 + beatIndex;
                            final isCurrentBeat =
                                (state != LooperState.empty) &&
                                (currentBeatIndex == globalBeatIndex);
                            return Container(
                              width: isCurrentBeat ? 6 : 4,
                              height: isCurrentBeat ? 6 : 4,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isCurrentBeat
                                    ? stateColor
                                    : (_isDarkMode
                                          ? Colors.grey[850]
                                          : Colors.grey[300]),
                              ),
                            );
                          }),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),

          if (state != LooperState.empty)
            Positioned.fill(
              child: Align(
                alignment: Alignment(progress * 2.0 - 1.0, 0.0),
                child: Container(
                  width: 3,
                  decoration: BoxDecoration(
                    color: stateColor,
                    boxShadow: [
                      BoxShadow(
                        color: stateColor.withOpacity(0.8),
                        blurRadius: 6,
                        spreadRadius: 1.5,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PulsingIndicator extends StatefulWidget {
  final IconData icon;
  final Color color;

  const _PulsingIndicator({required this.icon, required this.color});

  @override
  State<_PulsingIndicator> createState() => _PulsingIndicatorState();
}

class _PulsingIndicatorState extends State<_PulsingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.4, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: Icon(widget.icon, color: widget.color, size: 16),
    );
  }
}
