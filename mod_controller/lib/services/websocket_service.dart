import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/plugin_instance.dart';

enum ConnectionStatus {
  disconnected,
  connecting,
  connected,
}

class ModWebSocketService extends ChangeNotifier {
  WebSocketChannel? _channel;
  ConnectionStatus _status = ConnectionStatus.disconnected;
  String _lastIp = '192.168.51.1';

  StreamSubscription? _subscription;
  final StreamController<String> _rawMessageStreamController =
      StreamController<String>.broadcast();

  // Expose parsed Gain plugins
  final ValueNotifier<ConnectionStatus> connectionStatus = ValueNotifier(ConnectionStatus.disconnected);
  final ValueNotifier<List<PluginInstance>> allPlugins = ValueNotifier([]);
  final ValueNotifier<List<PluginInstance>> gainPedals = ValueNotifier([]);
  
  // Transport State
  final ValueNotifier<bool> isTransportRolling = ValueNotifier(false);
  final ValueNotifier<int> transportSyncMode = ValueNotifier(0); // 0 = Internal, 1 = MIDI, 2 = Link
  // Expose parsed BPM (tempo)
  final ValueNotifier<double> bpm = ValueNotifier<double>(120.0);
  final ValueNotifier<bool> isRolling = ValueNotifier<bool>(false);

  ConnectionStatus get status => _status;
  Stream<String> get messages => _rawMessageStreamController.stream;

  // Connects to the MOD Dwarf websocket
  void connect({String ip = '192.168.51.1'}) {
    _lastIp = ip;
    if (_status == ConnectionStatus.connected || _status == ConnectionStatus.connecting) {
      return;
    }

    _status = ConnectionStatus.connecting;
    notifyListeners();

    final wsUrl = Uri.parse('ws://$ip/websocket');
    debugPrint('Connecting to MOD Dwarf at: $wsUrl');

    try {
      _channel = WebSocketChannel.connect(wsUrl);
      
      _subscription = _channel!.stream.listen(
        (message) {
          if (_status != ConnectionStatus.connected) {
            _status = ConnectionStatus.connected;
            notifyListeners();
            debugPrint('Connected to MOD Dwarf!');
          }
          _handleIncomingMessage(message);
        },
        onError: (error) {
          debugPrint('WebSocket Error: $error');
          _handleDisconnect();
        },
        onDone: () {
          debugPrint('WebSocket Connection Closed');
          _handleDisconnect();
        },
      );
    } catch (e) {
      debugPrint('WebSocket connection attempt failed: $e');
      _handleDisconnect();
    }
  }

  // Disconnects from the MOD Dwarf websocket
  void disconnect() {
    _handleDisconnect();
  }

  void _handleDisconnect() {
    _subscription?.cancel();
    _subscription = null;
    _channel?.sink.close();
    _channel = null;
    
    gainPedals.value = [];
    allPlugins.value = [];
    
    if (_status != ConnectionStatus.disconnected) {
      _status = ConnectionStatus.disconnected;
      notifyListeners();
      debugPrint('Disconnected from MOD Dwarf');
    }
  }

  // Request the pedalboard graph from the MOD Dwarf by triggering a fast reconnect
  void requestPedalboard() {
    if (_status == ConnectionStatus.connected) {
      debugPrint('Reconnecting to refresh pedalboard graph...');
      disconnect();
      // Wait a tiny moment to let the socket close fully, then reconnect
      Future.delayed(const Duration(milliseconds: 150), () {
        connect(ip: _lastIp);
      });
    } else {
      connect(ip: _lastIp);
    }
  }

  bool _isRefreshing = false;
  List<PluginInstance> _tempPlugins = [];

  // Processes incoming raw space-separated commands from Tornado server
  void _handleIncomingMessage(dynamic rawMessage) {
    final String msg = rawMessage.toString().trim();
    if (msg.isEmpty || msg == 'pong') return;
    
    _rawMessageStreamController.add(msg);

    // Split by the first space to extract command and data
    final int firstSpace = msg.indexOf(' ');
    final String cmd = firstSpace == -1 ? msg : msg.substring(0, firstSpace);
    final String data = firstSpace == -1 ? '' : msg.substring(firstSpace + 1);

    try {
      if (cmd == 'loading_start') {
        debugPrint('PEDALBOARD LOADING STARTED (DOUBLE-BUFFERED)');
        _isRefreshing = true;
        _tempPlugins = [];
      } else if (cmd == 'add') {
        // Format: add <instance> <uri> <x> <y> <bypassed> ...
        final List<String> parts = data.split(' ');
        if (parts.length >= 2) {
          final String instance = parts[0];
          final String uri = parts[1];
          
          bool bypassed = false;
          if (parts.length >= 5) {
            bypassed = parts[4] == '1';
          }
          
          final plugin = PluginInstance.fromRawFields(
            instance: instance,
            uri: uri,
            isBypassed: bypassed,
          );
          
          if (_isRefreshing) {
            if (!_tempPlugins.any((p) => p.instance == instance)) {
              _tempPlugins.add(plugin);
            }
          } else {
            final List<PluginInstance> current = List.from(allPlugins.value);
            if (!current.any((p) => p.instance == instance)) {
              current.add(plugin);
              allPlugins.value = current;
              debugPrint('DISCOVERED PLUGIN: $plugin');
            }
          }
        }
      } else if (cmd == 'param_set') {
        // Format: param_set <instance> <portsymbol> <value>
        final List<String> parts = data.split(' ');
        if (parts.length >= 3) {
          final String instance = parts[0];
          final String portsymbol = parts[1];
          final double? value = double.tryParse(parts[2]);
          
          if (value != null) {
            final List<PluginInstance> targetList = _isRefreshing ? _tempPlugins : allPlugins.value;
            final int index = targetList.indexWhere((p) => p.instance == instance);
            if (index != -1) {
              final plugin = targetList[index];
              plugin.parameters[portsymbol] = value;
              
              // Handle bypass status parameter
              if (portsymbol == ':bypass') {
                plugin.isBypassed = value == 1.0;
                debugPrint('BYPASS STATE CHANGE FOR ${plugin.instance}: bypassed=${plugin.isBypassed}');
              }
              
              // Dynamic gain symbol detection
              if (plugin.gainPortSymbol == null) {
                final String symbolLower = portsymbol.toLowerCase();
                if (symbolLower.contains('gain') || 
                    symbolLower.contains('volume') || 
                    symbolLower.contains('level')) {
                  plugin.gainPortSymbol = portsymbol;
                  debugPrint('DISCOVERED GAIN PORT SYMBOL FOR ${plugin.instance}: $portsymbol');
                }
              }
              
              if (_isRefreshing) {
                // Keep parsing, do not update ValueNotifier yet to avoid UI flicker
              } else {
                allPlugins.value = List.from(allPlugins.value);
                gainPedals.value = List.from(gainPedals.value);
                notifyListeners();
              }
            }
          }
        }
      } else if (cmd == 'transport_rolling' || cmd == 'transport-rolling') {
        final val = int.tryParse(data) == 1;
        isTransportRolling.value = val;
        isRolling.value = val;
        debugPrint('TRANSPORT ROLLING UPDATED: $val');
      } else if (cmd == 'transport_sync_mode' || cmd == 'transport-sync-mode' || cmd == 'sync' || cmd == 'sync_mode' || cmd == 'sync-mode') {
        final lowerData = data.trim().toLowerCase();
        int val = 0;
        if (lowerData == 'none' || lowerData == 'internal' || lowerData == '0') {
          val = 0;
        } else if (lowerData == 'midi' || lowerData == '1') {
          val = 1;
        } else if (lowerData == 'link' || lowerData == '2') {
          val = 2;
        } else {
          val = int.tryParse(lowerData) ?? 0;
        }
        transportSyncMode.value = val;
        debugPrint('TRANSPORT SYNC MODE UPDATED: $val (raw: $data)');
      } else if (cmd == 'loading_end') {
        debugPrint('PEDALBOARD LOADING ENDED');
        
        if (_isRefreshing) {
          allPlugins.value = _tempPlugins;
          _isRefreshing = false;
        }
        
        final List<PluginInstance> current = List.from(allPlugins.value);
        final List<PluginInstance> gains = current.where((plugin) {
          final uriLower = plugin.uri.toLowerCase();
          final titleLower = plugin.title.toLowerCase();
          final instanceLower = plugin.instance.toLowerCase();
          
          final hasGainParam = plugin.parameters.keys.any((symbol) {
            final symbolLower = symbol.toLowerCase();
            return symbolLower.contains('gain') || 
                   symbolLower.contains('volume') || 
                   symbolLower.contains('level');
          });

          return uriLower.contains('gain') || 
                 uriLower.contains('volume') ||
                 uriLower.contains('eg-amp') || 
                 titleLower.contains('gain') || 
                 titleLower.contains('volume') ||
                 instanceLower.contains('gain') ||
                 instanceLower.contains('volume') ||
                 hasGainParam;
        }).toList();

        // Assign fallback gainPortSymbol if none was auto-detected
        for (var plugin in gains) {
          if (plugin.gainPortSymbol == null) {
            plugin.gainPortSymbol = plugin.parameters.keys.firstWhere(
              (symbol) {
                final symbolLower = symbol.toLowerCase();
                return symbolLower.contains('gain') || 
                       symbolLower.contains('volume') || 
                       symbolLower.contains('level');
              },
              orElse: () => plugin.parameters.isNotEmpty ? plugin.parameters.keys.first : 'Gain',
            );
            debugPrint('ASSIGNED FALLBACK GAIN PORT FOR ${plugin.instance}: ${plugin.gainPortSymbol}');
          }
        }

        gainPedals.value = gains;
        debugPrint('SUCCESSFULLY DISCOVERED ${gains.length} GAIN PEDALS: $gains');
        notifyListeners();
      } else if (cmd == 'bpm' || cmd == 'transport_bpm' || cmd == 'transport-bpm' || cmd == 'tempo') {
        final double? val = double.tryParse(data);
        if (val != null) {
          bpm.value = val;
          debugPrint('RECEIVED BPM FROM HOST: $val');
        }
      } else if (cmd == 'rolling') {
        final double? val = double.tryParse(data);
        if (val != null) {
          final isRoll = val == 1.0;
          isRolling.value = isRoll;
          isTransportRolling.value = isRoll;
          debugPrint('RECEIVED ROLLING STATE FROM HOST: $isRoll');
        }
      }
    } catch (e, stack) {
      debugPrint('Error parsing command $cmd: $e\n$stack');
    }
  }

  // Sends a raw set BPM command
  void setBpm(double value) {
    if (_channel == null || _status != ConnectionStatus.connected) {
      debugPrint('Cannot set BPM: Not connected to MOD Dwarf');
      return;
    }

    final String rawPayload = 'bpm $value';
    debugPrint('SENDING COMMAND: $rawPayload');
    _channel!.sink.add(rawPayload);
    bpm.value = value; // Optimistic update
  }

  // Sends a raw transport rolling command (play/stop)
  void setRolling(bool value) {
    if (_channel == null || _status != ConnectionStatus.connected) {
      debugPrint('Cannot set rolling state: Not connected to MOD Dwarf');
      return;
    }

    final int intVal = value ? 1 : 0;
    final String rawPayload = 'transport-rolling $intVal';
    debugPrint('SENDING COMMAND: $rawPayload');
    _channel!.sink.add(rawPayload);
    isRolling.value = value; // Optimistic update
  }

  // Sends a raw parameter set command
  void setParamValue({
    required String instance,
    required String port,
    required double value,
  }) {
    if (_channel == null || _status != ConnectionStatus.connected) {
      debugPrint('Cannot send param value: Not connected to MOD Dwarf');
      return;
    }

    // Format: param_set <instance>/<port> <value>
    final String rawPayload = 'param_set $instance/$port $value';
    debugPrint('SENDING COMMAND: $rawPayload');
    _channel!.sink.add(rawPayload);
  }

  // Sends a raw toggle bypass command with instantaneous optimistic state updates
  void toggleBypass({
    required String instance,
    required bool bypass,
  }) {
    // 1. OPTIMISTIC UPDATE: Update the state immediately in all collections so the UI reacts in under 1ms
    final List<PluginInstance> currentAll = List.from(allPlugins.value);
    final int indexAll = currentAll.indexWhere((p) => p.instance == instance);
    if (indexAll != -1) {
      currentAll[indexAll].isBypassed = bypass;
      allPlugins.value = currentAll;
    }

    final List<PluginInstance> currentGains = List.from(gainPedals.value);
    final int indexGains = currentGains.indexWhere((p) => p.instance == instance);
    if (indexGains != -1) {
      currentGains[indexGains].isBypassed = bypass;
      gainPedals.value = currentGains;
    }
    
    // Explicitly notify any widget listeners (like main.dart)
    notifyListeners();

    if (_channel == null || _status != ConnectionStatus.connected) {
      debugPrint('Cannot toggle bypass: Not connected to MOD Dwarf');
      return;
    }

    // Format: param_set <instance>/:bypass <1.0 for bypassed/off, 0.0 for active/on>
    final double val = bypass ? 1.0 : 0.0;
    final String rawPayload = 'param_set $instance/:bypass $val';
    debugPrint('SENDING COMMAND: $rawPayload');
    _channel!.sink.add(rawPayload);
  }

  // Sends a raw string payload to the MOD websocket
  void sendRawMessage(String message) {
    if (_channel == null || _status != ConnectionStatus.connected) {
      debugPrint('Cannot send raw message: Not connected');
      return;
    }
    debugPrint('SENDING RAW: $message');
    _channel!.sink.add(message);
  }

  @override
  void dispose() {
    _handleDisconnect();
    _rawMessageStreamController.close();
    super.dispose();
  }
}
