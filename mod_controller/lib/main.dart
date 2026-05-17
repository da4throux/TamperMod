import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'services/websocket_service.dart';
import 'models/plugin_instance.dart';

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

class _DashboardScreenState extends State<DashboardScreen> with TickerProviderStateMixin, WidgetsBindingObserver {
  final ModWebSocketService _webSocketService = ModWebSocketService();
  final TextEditingController _ipController = TextEditingController(text: '192.168.51.1');
  late TabController _tabController;
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // We will initialize with 3 tabs initially (Gain, All Plugins, Web GUI)
    _tabController = TabController(length: 3, vsync: this);
    
    // Initialize WebViewController
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF0B0E14));
      
    // Load initial URL
    _webViewController.loadRequest(Uri.parse('http://${_ipController.text}'));

    // Connect automatically on launch
    _webSocketService.connect(ip: _ipController.text);
    
    // Listen to value changes to update local volume values initially
    _webSocketService.gainPedals.addListener(_initializeLocalVolumes);
  }

  void _updateTabController(int targetLength) {
    if (_tabController.length != targetLength) {
      final oldIndex = _tabController.index;
      final newIndex = oldIndex.clamp(0, targetLength - 1);
      
      // Delay recreation to avoid modifying state during the build phase
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _tabController.dispose();
          _tabController = TabController(
            length: targetLength,
            vsync: this,
            initialIndex: newIndex,
          );
        });
      });
    }
  }

  int get _targetTabLength {
    if (_viewMode == ViewMode.web) {
      return 1; // TabController needs at least 1 tab
    }
    if (_viewMode == ViewMode.controls) {
      return 2;
    }
    // split view: length 2 for tablets, 3 for phones
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    return isTablet ? 2 : 3;
  }

  void _initializeLocalVolumes() {
    for (var pedal in _webSocketService.gainPedals.value) {
      if (pedal.gainPortSymbol != null) {
        final double? serverValue = pedal.parameters[pedal.gainPortSymbol];
        if (serverValue != null && !_localVolumes.containsKey(pedal.instance)) {
          _localVolumes[pedal.instance] = serverValue;
        }
      }
    }
    setState(() {});
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
    _webSocketService.dispose();
    _ipController.dispose();
    _tabController.dispose();
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
        final isTablet = screenWidth > 600;
        final isLandscape = orientation == Orientation.landscape;
        
        _updateTabController(_targetTabLength);

        return Scaffold(
          appBar: AppBar(
            backgroundColor: const Color(0xFF0F141C),
            elevation: 8,
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
                      'TAMPERMOD LIVE v1.0.6',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 1.5),
                    ),
                    Text(
                      _getStatusText(_webSocketService.status),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: _getStatusColor(_webSocketService.status),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              _buildLayoutButton(
                icon: Icons.tune,
                tooltip: 'Tap: Toggle Controls | Long Press: Full Controls',
                isActive: _showControls,
                onTap: () {
                  if (_showControls && !_showWeb) return; // Keep at least one view
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
                tooltip: 'Tap: Toggle Web | Long Press: Full Web Interface',
                isActive: _showWeb,
                onTap: () {
                  if (_showWeb && !_showControls) return; // Keep at least one view
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
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.open_in_browser, color: Color(0xFF00FFCC)),
                tooltip: 'Open MOD Web GUI',
                onPressed: _openWebInterface,
              ),
              IconButton(
                icon: const Icon(Icons.refresh, color: Color(0xFF00FFCC)),
                tooltip: 'Refresh Pedalboard',
                onPressed: _webSocketService.status == ConnectionStatus.connected
                    ? () => _webSocketService.requestPedalboard()
                    : null,
              ),
            ],
            bottom: _viewMode == ViewMode.web
                ? null
                : TabBar(
                    controller: _tabController,
                    indicatorColor: const Color(0xFF00FFCC),
                    labelColor: const Color(0xFF00FFCC),
                    unselectedLabelColor: Colors.grey,
                    tabs: (_viewMode == ViewMode.controls || isTablet)
                        ? const [
                            Tab(icon: Icon(Icons.tune), text: 'GAIN CONTROL'),
                            Tab(icon: Icon(Icons.settings_ethernet), text: 'ALL PLUGINS'),
                          ]
                        : const [
                            Tab(icon: Icon(Icons.tune), text: 'GAIN CONTROL'),
                            Tab(icon: Icon(Icons.settings_ethernet), text: 'ALL PLUGINS'),
                            Tab(icon: Icon(Icons.language), text: 'WEB GUI'),
                          ],
                  ),
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
                // Top Connection Bar
                _buildConnectionPanel(),
                
                // Content Areas
                Expanded(
                  child: _buildBodyContent(isTablet, isLandscape),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBodyContent(bool isTablet, bool isLandscape) {
    if (_viewMode == ViewMode.web) {
      return _buildWebView();
    }
    
    if (_viewMode == ViewMode.controls) {
      return TabBarView(
        controller: _tabController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _buildGainPadsTab(),
          _buildAllPluginsTab(),
        ],
      );
    }
    
    // _viewMode == ViewMode.split
    if (isTablet) {
      return isLandscape
          ? Row(
              children: [
                Expanded(
                  flex: 5,
                  child: TabBarView(
                    controller: _tabController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _buildGainPadsTab(),
                      _buildAllPluginsTab(),
                    ],
                  ),
                ),
                Container(width: 1, color: Colors.grey[850]),
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
                  child: TabBarView(
                    controller: _tabController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _buildGainPadsTab(),
                      _buildAllPluginsTab(),
                    ],
                  ),
                ),
                Container(height: 1, color: Colors.grey[850]),
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
    } else {
      // Small mobile split-screen = tabbed view
      return TabBarView(
        controller: _tabController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _buildGainPadsTab(),
          _buildAllPluginsTab(),
          _buildWebView(),
        ],
      );
    }
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
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getStatusColor(_webSocketService.status).withOpacity(0.3),
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
                labelStyle: TextStyle(color: Colors.grey, fontSize: 12),
                border: InputBorder.none,
                prefixIcon: Icon(Icons.lan, color: Colors.grey, size: 20),
              ),
              style: const TextStyle(color: Colors.white, fontFamily: 'monospace'),
              enabled: isDisconnected,
            ),
          ),
          const SizedBox(width: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isDisconnected ? const Color(0xFF00FFCC) : const Color(0xFFFF007F),
              foregroundColor: Colors.black,
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
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGainPadsTab() {
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
      valueListenable: _webSocketService.gainPedals,
      builder: (context, gains, _) {
        if (gains.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(color: Color(0xFF00FFCC)),
                const SizedBox(height: 24),
                const Text(
                  'Scanning Pedalboard Graph...',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    'No volume/gain pedals detected yet. Create a pedalboard with a Gain or Volume pedal on the Dwarf web GUI.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                  ),
                ),
              ],
            ),
          );
        }

        final double screenWidth = MediaQuery.of(context).size.width;
        final int crossAxisCount = screenWidth > 600 ? 2 : 1;

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: 1.4,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: gains.length,
          itemBuilder: (context, index) {
            final pedal = gains[index];
            return _buildGainCard(pedal);
          },
        );
      },
    );
  }

  Widget _buildGainCard(PluginInstance pedal) {
    // Read from local volumes map first, then server parameter, or default to 0.0
    final double currentValue = _localVolumes[pedal.instance] ?? 
        (pedal.gainPortSymbol != null ? pedal.parameters[pedal.gainPortSymbol] : null) ?? 
        0.0;
    
    final double minRange = pedal.minGain;
    final double maxRange = pedal.maxGain;

    // Clamp to ensure the slider doesn't throw a validation error
    final double clampedValue = currentValue.clamp(minRange, maxRange);
    final bool isBypassed = pedal.isBypassed;

    // Premium styling choices based on bypass state
    final Color accentColor = isBypassed 
        ? Colors.grey[600]! 
        : const Color(0xFF00FFCC); // Neon Turquoise
        
    final Color powerIconColor = isBypassed 
        ? const Color(0xFFFF007F) // Fuchsia for deactivated/off
        : const Color(0xFF00FFCC); // Turquoise for active/on

    final double cardOpacity = isBypassed ? 0.70 : 1.0;
    
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
              // Pedal Info Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pedal.title.toUpperCase(),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: accentColor,
                            overflow: TextOverflow.ellipsis,
                          ),
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
                  
                  // Power Toggle Switch (Stage Rack style)
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
 
                  // Volume display box
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
              
              // Slider Row (Custom designed, fat, and responsive)
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
                          setState(() {
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
              
              const SizedBox(height: 8),
              // Dynamic slope info or other details
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAllPluginsTab() {
    if (_webSocketService.status != ConnectionStatus.connected) {
      return Center(
        child: Icon(Icons.link_off, size: 64, color: const Color(0xFFFF007F).withOpacity(0.5)),
      );
    }

    return ValueListenableBuilder<List<PluginInstance>>(
      valueListenable: _webSocketService.allPlugins,
      builder: (context, plugins, _) {
        if (plugins.isEmpty) {
          return const Center(
            child: Text('No active plugins loaded in current pedalboard.'),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'DISCOVERED GRAPH COMPONENTS (${plugins.length})',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey),
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: plugins.length,
                separatorBuilder: (context, index) => Divider(color: Colors.grey[850]),
                itemBuilder: (context, index) {
                  final plugin = plugins[index];
                  final isGain = _webSocketService.gainPedals.value.any((p) => p.instance == plugin.instance);
                  
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      plugin.title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isGain 
                            ? (plugin.isBypassed ? Colors.grey : const Color(0xFF00FFCC)) 
                            : Colors.white,
                      ),
                    ),
                    subtitle: Text(
                      'Instance: ${plugin.instance}\nURI: ${plugin.uri}',
                      style: TextStyle(fontSize: 11, color: Colors.grey[500], fontFamily: 'monospace'),
                    ),
                    trailing: isGain
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: (plugin.isBypassed ? Colors.grey : const Color(0xFF00FFCC)).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: plugin.isBypassed ? Colors.grey : const Color(0xFF00FFCC)),
                            ),
                            child: Text(
                              plugin.isBypassed ? 'BYPASSED' : 'ACTIVE VOL',
                              style: TextStyle(
                                fontSize: 8, 
                                color: plugin.isBypassed ? Colors.grey : const Color(0xFF00FFCC), 
                                fontWeight: FontWeight.bold
                              ),
                            ),
                          )
                        : null,
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
