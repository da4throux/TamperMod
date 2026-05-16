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
  final ValueNotifier<List<PluginInstance>> gainPedals = ValueNotifier<List<PluginInstance>>([]);
  // Expose all parsed plugins (useful for debugging/discovery)
  final ValueNotifier<List<PluginInstance>> allPlugins = ValueNotifier<List<PluginInstance>>([]);

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
        debugPrint('PEDALBOARD LOADING STARTED');
        allPlugins.value = [];
        gainPedals.value = [];
      } else if (cmd == 'add') {
        // Format: add <instance> <uri> <x> <y> <bypassed> ...
        final List<String> parts = data.split(' ');
        if (parts.length >= 2) {
          final String instance = parts[0];
          final String uri = parts[1];
          
          final plugin = PluginInstance.fromRawFields(instance: instance, uri: uri);
          
          final List<PluginInstance> current = List.from(allPlugins.value);
          if (!current.any((p) => p.instance == instance)) {
            current.add(plugin);
            allPlugins.value = current;
            debugPrint('DISCOVERED PLUGIN: $plugin');
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
            final List<PluginInstance> current = List.from(allPlugins.value);
            final int index = current.indexWhere((p) => p.instance == instance);
            if (index != -1) {
              final plugin = current[index];
              plugin.parameters[portsymbol] = value;
              
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
              
              allPlugins.value = current;
              
              // Notify listeners that parameter state changed
              gainPedals.value = List.from(gainPedals.value);
              allPlugins.value = List.from(allPlugins.value);
            }
          }
        }
      } else if (cmd == 'loading_end') {
        debugPrint('PEDALBOARD LOADING ENDED');
        
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
      }
    } catch (e, stack) {
      debugPrint('Error parsing command $cmd: $e\n$stack');
    }
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

  @override
  void dispose() {
    _handleDisconnect();
    _rawMessageStreamController.close();
    super.dispose();
  }
}
