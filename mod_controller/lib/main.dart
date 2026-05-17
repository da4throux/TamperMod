import 'dart:async';
import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'services/websocket_service.dart';
import 'models/plugin_instance.dart';

// Global application version tracking constant
const String kAppVersion = '1.0.6';

enum ViewMode {
  split,
  controls,
  web,
}

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

class _DashboardScreenState extends State<DashboardScreen> with WidgetsBindingObserver {
  final ModWebSocketService _webSocketService = ModWebSocketService();
  final TextEditingController _ipController = TextEditingController(text: '192.168.51.1');
  late final WebViewController _webViewController;
  
  bool _showControls = true;
  bool _showWeb = true;

  ViewMode get _viewMode {
    if (_showControls && _showWeb) return ViewMode.split;
    if (_showControls) return ViewMode.controls;
    return ViewMode.web;
  }

  // Track volume slider values locally to make the slider extremely responsive
  final Map<String, double> _localVolumes = {};

  // Custom User Ordering and Visibility List
  List<String> _enabledPluginInstances = [];

  // Fading and BPM Parameter State
  double _bpm = 120.0;
  int _fadeBars = 8; // Default fade speed period in bars (configurable: 1, 2, 4, 8, 16)
  
  final Map<String, double> _preFadeVolumes = {};
  final Map<String, Timer?> _fadeTimers = {};
  final Map<String, bool> _fadeDirections = {}; // true for Fade In, false for Fade Out

  // User custom display titles for plugin cards (renaming support)
  final Map<String, String> _customTitles = {};

  // Tap-tempo times keeper
  final List<DateTime> _tapTimes = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Initialize WebViewController
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF0B0E14));
      
    // Load initial URL
    _webViewController.loadRequest(Uri.parse('http://${_ipController.text}'));

    // Connect automatically on launch
    _webSocketService.connect(ip: _ipController.text);
    
    // Listen to value changes to update local volume values and BPM initially
    _webSocketService.gainPedals.addListener(_initializeLocalVolumes);
    _webSocketService.bpm.addListener(_updateBpmFromService);
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
      if (avgMs > 200 && avgMs < 2000) { // Limit to 30 to 300 BPM
        final double calculatedBpm = 60000 / avgMs;
        _webSocketService.setBpm(double.parse(calculatedBpm.toStringAsFixed(1)));
      }
    }
  }

  void _showBpmDialog() {
    final controller = TextEditingController(text: _bpm.toStringAsFixed(1));
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0F141C),
          title: const Text(
            'SET HOST TEMPO',
            style: TextStyle(
              color: Color(0xFF00FFCC), 
              fontWeight: FontWeight.bold, 
              letterSpacing: 1.2, 
              fontSize: 16
            ),
          ),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Tempo (BPM)',
              labelStyle: TextStyle(color: Colors.grey),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF00FFCC))),
            ),
            style: const TextStyle(color: Colors.white, fontFamily: 'monospace'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00FFCC), 
                foregroundColor: Colors.black
              ),
              onPressed: () {
                final double? newBpm = double.tryParse(controller.text);
                if (newBpm != null && newBpm > 20.0 && newBpm < 300.0) {
                  _webSocketService.setBpm(newBpm);
                }
                Navigator.pop(context);
              },
              child: const Text('SET', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _triggerFade(PluginInstance pedal, {required bool fadeIn}) {
    if (pedal.gainPortSymbol == null) return;
    
    final double currentValue = _localVolumes[pedal.instance] ?? 
        pedal.parameters[pedal.gainPortSymbol] ?? 
        0.0;
        
    final double minRange = pedal.minGain;
    final double maxRange = pedal.maxGain;
    
    final double startVal = currentValue.clamp(minRange, maxRange);
    
    double targetEndValue;
    if (fadeIn) {
      targetEndValue = _preFadeVolumes[pedal.instance] ?? 0.0;
      targetEndValue = targetEndValue.clamp(minRange, maxRange);
    } else {
      // Save current pre-fade volume if it's substantial
      if (startVal > minRange + 5.0) {
        _preFadeVolumes[pedal.instance] = startVal;
      }
      targetEndValue = minRange;
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
    });
    
    _fadeTimers[pedal.instance] = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      currentStep++;
      if (currentStep >= totalSteps) {
        setState(() {
          _localVolumes[pedal.instance] = targetEndValue;
          _fadeTimers[pedal.instance] = null;
        });
        _webSocketService.setParamValue(
          instance: pedal.instance,
          port: pedal.gainPortSymbol!,
          value: double.parse(targetEndValue.toStringAsFixed(2)),
        );
        timer.cancel();
      } else {
        // Compute S-curve interpolation using Curves.easeInOut
        final double progress = currentStep / totalSteps;
        final double curvedProgress = Curves.easeInOut.transform(progress);
        final double intermediateVal = startVal + (targetEndValue - startVal) * curvedProgress;
        
        setState(() {
          _localVolumes[pedal.instance] = intermediateVal;
        });
        _webSocketService.setParamValue(
          instance: pedal.instance,
          port: pedal.gainPortSymbol!,
          value: double.parse(intermediateVal.toStringAsFixed(2)),
        );
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      debugPrint('App returned from background: automatically restoring remote connection...');
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
    
    // Cancel all running fade timers
    for (var timer in _fadeTimers.values) {
      timer?.cancel();
    }
    
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
              decoration: const BoxDecoration(
                color: Color(0xFF0F141C),
                border: Border(
                  left: BorderSide(color: Color(0xFF00FFCC), width: 1.5),
                  top: BorderSide(color: Color(0xFF00FFCC), width: 1.5),
                ),
              ),
              child: _buildDrawerContent(),
            ),
          ),
          appBar: AppBar(
            backgroundColor: const Color(0xFF0F141C),
            elevation: 8,
            // Custom Application Drawer Menu trigger in top-right
            leadingWidth: 0,
            leading: const SizedBox(),
            title: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: _getStatusColor(_webSocketService.status),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _getStatusColor(_webSocketService.status).withOpacity(0.6),
                        blurRadius: 8,
                        spreadRadius: 2,
                      )
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'TAMPERMOD LIVE',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1.5),
                    ),
                    Text(
                      _getStatusText(_webSocketService.status),
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: _getStatusColor(_webSocketService.status),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              // Premium Integrated BPM & Fade Controller
              if (screenWidth > 550) _buildBpmControllerWidget(),
              const SizedBox(width: 8),
              
              // Custom View Layout Selectors
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
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.refresh, color: Color(0xFF00FFCC), size: 22),
                tooltip: 'Refresh Pedalboard',
                onPressed: _webSocketService.status == ConnectionStatus.connected
                    ? () => _webSocketService.requestPedalboard()
                    : null,
              ),
              // Open Settings Drawer
              Builder(
                builder: (context) => IconButton(
                  icon: const Icon(Icons.settings_outlined, color: Color(0xFFFF007F), size: 22),
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
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF0F141C), Color(0xFF05070A)],
              ),
            ),
            child: Column(
              children: [
                // Inline Connection / IP bar
                _buildConnectionPanel(),
                
                // BPM inline widget on tiny screens to avoid AppBar overcrowding
                if (screenWidth <= 550) 
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: _buildBpmControllerWidget(),
                  ),

                // Responsive layout container
                Expanded(
                  child: _buildBodyContent(isLandscape),
                ),
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
        color: Colors.black.withOpacity(0.35),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF00FFCC).withOpacity(0.2)),
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
                border: Border.all(color: const Color(0xFFFF007F).withOpacity(0.4)),
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
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
                color: Color(0xFF00FFCC),
              ),
            ),
          ),
          const SizedBox(width: 8),
          
          // Dropdown selector for Fade Beats length
          DropdownButton<int>(
            value: _fadeBars,
            dropdownColor: const Color(0xFF0F141C),
            underline: const SizedBox(),
            icon: const Icon(Icons.arrow_drop_down, color: Colors.grey, size: 16),
            style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold),
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
            style: TextStyle(fontSize: 10, color: Colors.grey[500]),
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
                Expanded(
                  flex: 5,
                  child: _buildUnifiedControlsList(),
                ),
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
                Expanded(
                  flex: 5,
                  child: _buildUnifiedControlsList(),
                ),
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
            Icon(Icons.link_off, size: 64, color: const Color(0xFFFF007F).withOpacity(0.5)),
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
            (instanceId) => plugins.any((p) => p.instance == instanceId)
          );
          if (!hasAnyActive) {
            final newGains = plugins.where((p) {
              final uriLower = p.uri.toLowerCase();
              final titleLower = p.title.toLowerCase();
              return uriLower.contains('gain') || 
                     uriLower.contains('volume') || 
                     uriLower.contains('amp') ||
                     titleLower.contains('gain') || 
                     titleLower.contains('volume');
            }).map((p) => p.instance).toList();
            
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  _enabledPluginInstances = newGains;
                });
              }
            });
          }
        }

        // Hydrate selected active controls list safely without type-cast null safety exceptions
        final List<PluginInstance> enabledPlugins = [];
        for (final instanceId in _enabledPluginInstances) {
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
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey),
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
            final int crossAxisCount = width > 600 ? 2 : 1;
            
            // Calculate column width taking spacing and padding into account
            final double spacing = 16.0;
            final double columnWidth = (width - (crossAxisCount - 1) * spacing) / crossAxisCount;
            
            // Lock height to exactly 185 logical pixels
            final double childAspectRatio = columnWidth / 185.0;

            return GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                childAspectRatio: childAspectRatio,
                crossAxisSpacing: spacing,
                mainAxisSpacing: spacing,
              ),
              itemCount: enabledPlugins.length,
              itemBuilder: (context, index) {
                final pedal = enabledPlugins[index];
                final uriLower = pedal.uri.toLowerCase();
                final titleLower = pedal.title.toLowerCase();
                
                final isSwitch = uriLower.contains('switch') || 
                                 titleLower.contains('switch');
                
                final isGainOrVolume = uriLower.contains('gain') || 
                                       uriLower.contains('volume') || 
                                       uriLower.contains('amp') ||
                                       titleLower.contains('gain') || 
                                       titleLower.contains('volume');
                
                if (isSwitch) {
                  return _buildSwitchCard(pedal);
                } else if (isGainOrVolume) {
                  return _buildGainCard(pedal);
                } else {
                  return _buildPlaceholderCard(pedal);
                }
              },
            );
          },
        );
      },
    );
  }

  Widget _buildGainCard(PluginInstance pedal) {
    final double currentValue = _localVolumes[pedal.instance] ?? 
        (pedal.gainPortSymbol != null ? pedal.parameters[pedal.gainPortSymbol] : null) ?? 
        0.0;
    
    final double minRange = pedal.minGain;
    final double maxRange = pedal.maxGain;

    final double clampedValue = currentValue.clamp(minRange, maxRange);
    final bool isBypassed = pedal.isBypassed;

    // Design states based on active status
    final Color accentColor = isBypassed 
        ? Colors.grey[600]! 
        : const Color(0xFF00FFCC);
        
    final Color powerIconColor = isBypassed 
        ? const Color(0xFFFF007F) 
        : const Color(0xFF00FFCC);

    final double cardOpacity = isBypassed ? 0.70 : 1.0;
    
    // Check if dynamic fading is active
    final bool isFading = _fadeTimers[pedal.instance] != null;
    final bool isFadingIn = isFading && (_fadeDirections[pedal.instance] == true);
    final bool isFadingOut = isFading && (_fadeDirections[pedal.instance] == false);

    return Opacity(
      opacity: cardOpacity,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: accentColor.withOpacity(isBypassed ? 0.1 : 0.25),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: accentColor.withOpacity(isBypassed ? 0.0 : 0.06),
              blurRadius: 10,
              spreadRadius: 2,
            )
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header parameters
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
                                    (_customTitles[pedal.instance] ?? pedal.title).toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w900,
                                      color: accentColor,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(Icons.edit, size: 14, color: Colors.grey[500]),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () => _showRenameDialog(pedal),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Instance: ${pedal.instance}  |  Port: ${pedal.gainPortSymbol ?? "Gain"}',
                              style: TextStyle(
                                fontSize: 9,
                                color: Colors.grey[500],
                                fontFamily: 'monospace',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  // Power Switch
                  IconButton(
                    icon: Icon(
                      Icons.power_settings_new,
                      color: powerIconColor,
                      size: 26,
                    ),
                    tooltip: isBypassed ? 'Activate Pedal' : 'Bypass Pedal',
                    onPressed: () {
                      _webSocketService.toggleBypass(
                        instance: pedal.instance,
                        bypass: !isBypassed,
                      );
                    },
                  ),
                  const SizedBox(width: 8),
 
                  // Decibel Value Box
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: accentColor.withOpacity(0.5),
                      ),
                    ),
                    child: Text(
                      '${clampedValue.toStringAsFixed(1)} dB',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: accentColor,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              
              // Custom styled Volume Slider
              Row(
                children: [
                  Icon(Icons.volume_mute, color: Colors.grey[isBypassed ? 700 : 600], size: 20),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: accentColor,
                        inactiveTrackColor: Colors.grey[850],
                        trackHeight: 12.0,
                        thumbColor: isBypassed ? Colors.grey[400] : Colors.white,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 15.0),
                        overlayColor: accentColor.withOpacity(0.2),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 28.0),
                      ),
                      child: Slider(
                        value: clampedValue,
                        min: minRange,
                        max: maxRange,
                        onChanged: (newValue) {
                          // Interrupt and cancel any active fade immediately if user moves thumb
                          _fadeTimers[pedal.instance]?.cancel();
                          setState(() {
                            _fadeTimers[pedal.instance] = null;
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
                    ),
                  ),
                  Icon(Icons.volume_up, color: accentColor, size: 20),
                ],
              ),
              
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${minRange.toStringAsFixed(1)} dB',
                    style: TextStyle(fontSize: 10, color: Colors.grey[isBypassed ? 750 : 650]),
                  ),
                  Text(
                    '${maxRange >= 0 ? "+" : ""}${maxRange.toStringAsFixed(1)} dB (Max)',
                    style: TextStyle(fontSize: 10, color: Colors.grey[isBypassed ? 750 : 650]),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              
              // Fade Action Row
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
        ),
      ),
    );
  }

  void _highlightPedalInWebView(PluginInstance pedal) {
    final String instId = pedal.instance;
    
    // Construct robust JavaScript to find, scroll and glow-highlight the pedal element in the Web GUI
    final String jsCode = '''
      (function() {
        const instId = "$instId";
        
        // Helper to highlight and scroll
        function highlight(el) {
          // Remove any existing highlights first
          const existing = document.querySelectorAll(".tamper-highlight");
          existing.forEach(e => {
            e.style.outline = "";
            e.style.boxShadow = "";
            if (e.removeAttribute) {
              e.removeAttribute("stroke");
              e.removeAttribute("stroke-width");
            }
            e.classList.remove("tamper-highlight");
          });
          
          // Apply glowing neon outline & shadow highlight
          el.style.transition = "outline 0.3s ease, box-shadow 0.3s ease, stroke 0.3s ease";
          el.style.outline = "6px solid #FF0055";
          el.style.outlineOffset = "4px";
          el.style.boxShadow = "0 0 25px #FF0055";
          
          if (el.setAttribute) {
            el.setAttribute("stroke", "#FF0055");
            el.setAttribute("stroke-width", "6px");
          }
          
          el.classList.add("tamper-highlight");
          
          // Scroll smoothly into view
          el.scrollIntoView({ behavior: 'smooth', block: 'center', inline: 'center' });
          
          // Make it pulse a few times for high visibility
          let flashCount = 0;
          const interval = setInterval(() => {
            const visible = (flashCount % 2 === 0);
            el.style.outlineColor = visible ? "#FF0055" : "transparent";
            el.style.boxShadow = visible ? "0 0 25px #FF0055" : "none";
            if (el.setAttribute) {
              el.setAttribute("stroke", visible ? "#FF0055" : "none");
            }
            flashCount++;
            if (flashCount > 7) {
              clearInterval(interval);
              el.style.outlineColor = "#FF0055";
              el.style.boxShadow = "0 0 25px #FF0055";
              if (el.setAttribute) {
                el.setAttribute("stroke", "#FF0055");
                el.setAttribute("stroke-width", "6px");
              }
            }
          }, 200);
        }

        // Broad search for the instance element in the MOD Web interface DOM
        const cleanName = instId.split("/").pop(); // e.g. "Gain_1"
        
        // 1. Try selector by ID or common prefixes
        let el = document.getElementById("pedal-" + cleanName) || 
                 document.getElementById("instance-" + cleanName) ||
                 document.getElementById(cleanName) ||
                 document.getElementById(instId);
        if (el) { highlight(el); return; }
        
        // 2. Try by custom attributes commonly used in MOD Dwarf GUI
        el = document.querySelector("[data-instance='" + instId + "']") || 
             document.querySelector("[data-id='" + instId + "']") ||
             document.querySelector("[instance='" + instId + "']") ||
             document.querySelector("[data-instance*='" + cleanName + "']") ||
             document.querySelector("[data-id*='" + cleanName + "']") ||
             document.querySelector("[id*='" + cleanName + "']");
        if (el) { highlight(el); return; }
        
        // 3. Search all divs/g/svg elements
        const candidates = document.querySelectorAll("div, g, svg, rect, section, .plugin, .instance, [id*='graph']");
        for (let c of candidates) {
          const idVal = c.id || "";
          const dataInst = c.getAttribute ? (c.getAttribute('data-instance') || "") : "";
          const dataId = c.getAttribute ? (c.getAttribute('data-id') || "") : "";
          
          if (idVal === instId || 
              idVal === cleanName || 
              idVal.includes("pedal-" + cleanName) || 
              idVal.includes("instance-" + cleanName) ||
              dataInst === instId || 
              dataInst.includes(cleanName) ||
              dataId === instId || 
              dataId.includes(cleanName)) {
            highlight(c);
            return;
          }
        }
      })();
    ''';

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
          backgroundColor: const Color(0xFF0F141C),
          title: const Text(
            'RENAME PEDAL',
            style: TextStyle(
              color: Color(0xFF00FFCC), 
              fontWeight: FontWeight.bold, 
              letterSpacing: 1.2, 
              fontSize: 16
            ),
          ),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Custom Display Name',
              labelStyle: TextStyle(color: Colors.grey),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF00FFCC))),
            ),
            style: const TextStyle(color: Colors.white),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00FFCC), 
                foregroundColor: Colors.black
              ),
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  setState(() {
                    _customTitles[pedal.instance] = controller.text.trim();
                  });
                }
                Navigator.pop(context);
              },
              child: const Text('SAVE', style: TextStyle(fontWeight: FontWeight.bold)),
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

  Widget _buildSwitchCard(PluginInstance pedal) {
    final bool isBypassed = pedal.isBypassed;
    final String displayName = _customTitles[pedal.instance] ?? pedal.title;
    
    // Detect the routing parameter and its value
    final String? switchPort = _getSwitchPortSymbol(pedal);
    final double currentValue = switchPort != null ? (pedal.parameters[switchPort] ?? 0.0) : 0.0;
    
    // Typically: 0 = Path A, 1 = Path B
    final bool isPathB = currentValue >= 0.5;

    final Color accentColor = isBypassed ? Colors.grey[600]! : const Color(0xFF00FFCC);
    final Color powerIconColor = isBypassed ? const Color(0xFFFF007F) : const Color(0xFF00FFCC);

    return Opacity(
      opacity: isBypassed ? 0.70 : 1.0,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: accentColor.withOpacity(isBypassed ? 0.1 : 0.25),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: accentColor.withOpacity(isBypassed ? 0.0 : 0.06),
              blurRadius: 10,
              spreadRadius: 2,
            )
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
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
                                  icon: Icon(Icons.edit, size: 14, color: Colors.grey[500]),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () => _showRenameDialog(pedal),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Instance: ${pedal.instance}  |  Switch: ${switchPort ?? "None"}',
                              style: TextStyle(
                                  fontSize: 9,
                                  color: Colors.grey[500],
                                  fontFamily: 'monospace',
                                  overflow: TextOverflow.ellipsis,
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
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        color: (!isPathB && !isBypassed) 
                            ? const Color(0xFF00FFCC).withOpacity(0.12)
                            : Colors.black.withOpacity(0.3),
                        borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                        border: Border.all(
                          color: (!isPathB && !isBypassed)
                              ? const Color(0xFF00FFCC)
                              : Colors.grey[800]!,
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        'PATH A (CLEAN)',
                        style: TextStyle(
                          color: (!isPathB && !isBypassed) ? const Color(0xFF00FFCC) : Colors.grey[600],
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
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        color: (isPathB && !isBypassed) 
                            ? const Color(0xFFFF007F).withOpacity(0.12)
                            : Colors.black.withOpacity(0.3),
                        borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
                        border: Border.all(
                          color: (isPathB && !isBypassed)
                              ? const Color(0xFFFF007F)
                              : Colors.grey[800]!,
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        'PATH B (HEAVY)',
                        style: TextStyle(
                          color: (isPathB && !isBypassed) ? const Color(0xFFFF007F) : Colors.grey[600],
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
    );
  }

  Widget _buildFadeButton({
    required String label,
    required IconData icon,
    required bool isBypassed,
    required VoidCallback onTap,
    required Color accentColor,
    required bool isFading,
  }) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: ElevatedButton.icon(
          onPressed: isBypassed ? null : onTap,
          icon: Icon(
            icon, 
            size: 13, 
            color: isFading ? const Color(0xFFFF007F) : Colors.black
          ),
          label: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.0,
              color: isFading ? const Color(0xFFFF007F) : Colors.black,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: isFading 
                ? const Color(0xFFFF007F).withOpacity(0.12)
                : accentColor,
            disabledBackgroundColor: Colors.grey[800],
            padding: const EdgeInsets.symmetric(vertical: 8),
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

  Widget _buildPlaceholderCard(PluginInstance pedal) {
    final bool isBypassed = pedal.isBypassed;
    final Color accentColor = isBypassed ? Colors.grey[600]! : const Color(0xFF00FFCC);
    
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accentColor.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
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
                                  (_customTitles[pedal.instance] ?? pedal.title).toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: accentColor,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.edit, size: 14, color: Colors.grey[500]),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () => _showRenameDialog(pedal),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'URI: ${pedal.uri}',
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.grey[500],
                              fontFamily: 'monospace',
                              overflow: TextOverflow.ellipsis,
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
                    color: isBypassed ? const Color(0xFFFF007F) : const Color(0xFF00FFCC),
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
                Icon(Icons.info_outline, color: Colors.grey[600], size: 16),
                const SizedBox(width: 8),
                Text(
                  'Custom card layout coming soon.',
                  style: TextStyle(fontSize: 11, color: Colors.grey[500], fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ],
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
            color: isActive ? const Color(0xFF00FFCC).withOpacity(0.12) : Colors.transparent,
            border: Border.all(
              color: isActive ? const Color(0xFF00FFCC).withOpacity(0.4) : Colors.transparent,
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
    final bool isDisconnected = _webSocketService.status == ConnectionStatus.disconnected;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getStatusColor(_webSocketService.status).withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _ipController,
              decoration: const InputDecoration(
                labelText: 'MOD Dwarf IP',
                labelStyle: TextStyle(color: Colors.grey, fontSize: 11),
                border: InputBorder.none,
                prefixIcon: Icon(Icons.lan, color: Colors.grey, size: 18),
              ),
              style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 13),
              enabled: isDisconnected,
            ),
          ),
          const SizedBox(width: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isDisconnected ? const Color(0xFF00FFCC) : const Color(0xFFFF007F),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 4,
              shadowColor: (isDisconnected ? const Color(0xFF00FFCC) : const Color(0xFFFF007F)).withOpacity(0.5),
            ),
            onPressed: () {
              if (isDisconnected) {
                _webSocketService.connect(ip: _ipController.text);
                _webViewController.loadRequest(Uri.parse('http://${_ipController.text}'));
              } else {
                _webSocketService.disconnect();
              }
            },
            child: Text(
              isDisconnected ? 'CONNECT' : 'DISCONNECT',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: const Color(0xFF0F141C),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'WORKSPACE SETTINGS',
                style: TextStyle(
                  color: Color(0xFF00FFCC),
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.grey),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Select and drag to order plugins to show on your screen.',
            style: TextStyle(color: Colors.grey, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerContent() {
    return ValueListenableBuilder<List<PluginInstance>>(
      valueListenable: _webSocketService.allPlugins,
      builder: (context, allPlugins, _) {
        // Hydrate checked/active list safely without type-cast null safety exceptions
        final List<PluginInstance> active = [];
        for (final instanceId in _enabledPluginInstances) {
          PluginInstance? found;
          for (final p in allPlugins) {
            if (p.instance == instanceId) {
              found = p;
              break;
            }
          }
          if (found != null) {
            active.add(found);
          }
        }

        // Hydrate unchecked/inactive list
        final List<PluginInstance> inactive = allPlugins
            .where((p) => !_enabledPluginInstances.contains(p.instance))
            .toList();

        return Column(
          children: [
            _buildDrawerHeader(),
            
            // ACTIVE CONTROLS
            if (active.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.drag_indicator, size: 16, color: Color(0xFF00FFCC)),
                    const SizedBox(width: 8),
                    Text(
                      'ACTIVE CONTROLS (${active.length})',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold, 
                        fontSize: 11, 
                        color: Colors.grey, 
                        letterSpacing: 1.0
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 3,
                child: Theme(
                  data: Theme.of(context).copyWith(
                    canvasColor: const Color(0xFF161B22),
                  ),
                  child: ReorderableListView.builder(
                    itemCount: active.length,
                    onReorder: (oldIdx, newIdx) {
                      setState(() {
                        if (oldIdx < newIdx) {
                          newIdx -= 1;
                        }
                        final item = _enabledPluginInstances.removeAt(oldIdx);
                        _enabledPluginInstances.insert(newIdx, item);
                      });
                    },
                    itemBuilder: (context, index) {
                      final pedal = active[index];
                      return ListTile(
                        key: ValueKey(pedal.instance),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                        leading: Checkbox(
                          activeColor: const Color(0xFF00FFCC),
                          checkColor: Colors.black,
                          value: true,
                          onChanged: (_) {
                            setState(() {
                              _enabledPluginInstances.remove(pedal.instance);
                            });
                          },
                        ),
                        title: Text(
                          pedal.title,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                        ),
                        subtitle: Text(
                          pedal.instance,
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 9, color: Colors.grey),
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: const Icon(Icons.drag_handle, color: Colors.grey),
                      );
                    },
                  ),
                ),
              ),
            ],

            // AVAILABLE PLUGINS
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.add_circle_outline, 
                    size: 16, 
                    color: inactive.isEmpty ? Colors.grey : const Color(0xFFFF007F)
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'AVAILABLE COMPONENTS (${inactive.length})',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold, 
                      fontSize: 11, 
                      color: Colors.grey, 
                      letterSpacing: 1.0
                    ),
                  ),
                ],
              ),
            ),
            
            Expanded(
              flex: 2,
              child: inactive.isEmpty
                  ? const Center(
                      child: Text(
                        'All plugins are currently active.',
                        style: TextStyle(color: Colors.grey, fontSize: 12, fontStyle: FontStyle.italic),
                      ),
                    )
                  : ListView.builder(
                      itemCount: inactive.length,
                      itemBuilder: (context, index) {
                        final pedal = inactive[index];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                          leading: Checkbox(
                            activeColor: const Color(0xFF00FFCC),
                            value: false,
                            onChanged: (_) {
                              setState(() {
                                _enabledPluginInstances.add(pedal.instance);
                              });
                            },
                          ),
                          title: Text(
                            pedal.title,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Colors.grey),
                          ),
                          subtitle: Text(
                            pedal.instance,
                            style: const TextStyle(fontFamily: 'monospace', fontSize: 9, color: Colors.grey),
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      },
                    ),
            ),

            // Continuous App version tag
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: Text(
                  'TAMPERMOD LIVE v$kAppVersion',
                  style: TextStyle(
                    color: Color(0xFFFF007F),
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
