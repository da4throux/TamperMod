import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/plugin_instance.dart';
import 'websocket_service.dart';

enum LooperState {
  empty,
  countIn,
  recording,
  playing,
  paused,
}

class LooperController extends ChangeNotifier {
  final ModWebSocketService webSocketService;

  LooperState _state1 = LooperState.empty;
  LooperState _state2 = LooperState.empty;
  PluginInstance? _activeLooper;
  
  // Stopwatch & Timers for ultra-smooth 60fps timeline sweeps
  final Stopwatch _stopwatch1 = Stopwatch();
  final Stopwatch _stopwatch2 = Stopwatch();
  Timer? _sweepTimer;
  
  // Animation fractions and counts for loop 1
  double _sweepProgress1 = 0.0;
  int _currentBeatIndex1 = 0;
  int _currentBar1 = 1;
  int _currentBeatInBar1 = 1;

  // Animation fractions and counts for loop 2
  double _sweepProgress2 = 0.0;
  int _currentBeatIndex2 = 0;
  int _currentBar2 = 1;
  int _currentBeatInBar2 = 1;
  
  // Dynamic list of discovered loopers
  final ValueNotifier<List<PluginInstance>> discoveredLoopers =
      ValueNotifier<List<PluginInstance>>([]);

  LooperController({required this.webSocketService}) {
    // Listen to all discovered plugins to extract ALO loopers
    webSocketService.allPlugins.addListener(_updateDiscoveredLoopers);
  }

  // Getters for loop-specific states
  LooperState getState(int loopNum) => loopNum == 1 ? _state1 : _state2;
  double getSweepProgress(int loopNum) => loopNum == 1 ? _sweepProgress1 : _sweepProgress2;
  int getCurrentBeatIndex(int loopNum) => loopNum == 1 ? _currentBeatIndex1 : _currentBeatIndex2;
  int getCurrentBar(int loopNum) => loopNum == 1 ? _currentBar1 : _currentBar2;
  int getCurrentBeatInBar(int loopNum) => loopNum == 1 ? _currentBeatInBar1 : _currentBeatInBar2;

  // Backward compatibility getters (mapping to loop 1)
  LooperState get state => _state1;
  PluginInstance? get activeLooper => _activeLooper;
  double get sweepProgress => _sweepProgress1;
  int get currentBeatIndex => _currentBeatIndex1;
  int get currentBar => _currentBar1;
  int get currentBeatInBar => _currentBeatInBar1;
  
  double get bpm => webSocketService.bpm.value;
  double get beatDurationMs => (60.0 / bpm) * 1000.0;
  double get totalDurationMs => beatDurationMs * 16.0; // 4 bars = 16 beats

  void _updateDiscoveredLoopers() {
    final List<PluginInstance> loopers = webSocketService.allPlugins.value.where((p) {
      final uriLower = p.uri.toLowerCase();
      final titleLower = p.title.toLowerCase();
      return uriLower.contains('alo') || titleLower.contains('alo');
    }).toList();

    discoveredLoopers.value = loopers;

    // Default to the first discovered looper if none is active
    if (loopers.isNotEmpty && (_activeLooper == null || !loopers.any((p) => p.instance == _activeLooper!.instance))) {
      setActiveLooper(loopers.first);
    } else if (loopers.isEmpty) {
      _activeLooper = null;
      _resetState();
      notifyListeners();
    }
  }

  void setActiveLooper(PluginInstance looper) {
    _activeLooper = looper;
    _resetState();
    notifyListeners();
  }

  // Visual & Logical sweep loop running at 60fps (every 16ms)
  void _startSweepTimer() {
    if (_sweepTimer != null) return;
    _sweepTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (_state1 == LooperState.empty && _state2 == LooperState.empty || _activeLooper == null) {
        timer.cancel();
        _sweepTimer = null;
        return;
      }

      final double total = totalDurationMs;

      // Update Loop 1
      if (_state1 != LooperState.empty) {
        final double elapsed1 = _stopwatch1.elapsedMilliseconds.toDouble();
        if (_state1 == LooperState.countIn) {
          if (elapsed1 >= total) {
            _triggerSwitch(1);
            _stopwatch1.reset();
            _state1 = LooperState.recording;
          } else {
            _sweepProgress1 = elapsed1 / total;
            _currentBeatIndex1 = (elapsed1 / beatDurationMs).floor().clamp(0, 15);
            _currentBar1 = (_currentBeatIndex1 / 4).floor() + 1;
            _currentBeatInBar1 = (_currentBeatIndex1 % 4) + 1;
          }
        } else if (_state1 == LooperState.recording) {
          if (elapsed1 >= total) {
            _triggerSwitch(1);
            _stopwatch1.reset();
            _state1 = LooperState.playing;
          } else {
            _sweepProgress1 = elapsed1 / total;
            _currentBeatIndex1 = (elapsed1 / beatDurationMs).floor().clamp(0, 15);
            _currentBar1 = (_currentBeatIndex1 / 4).floor() + 1;
            _currentBeatInBar1 = (_currentBeatIndex1 % 4) + 1;
          }
        } else if (_state1 == LooperState.playing) {
          final double loopElapsed1 = elapsed1 % total;
          _sweepProgress1 = loopElapsed1 / total;
          _currentBeatIndex1 = (loopElapsed1 / beatDurationMs).floor().clamp(0, 15);
          _currentBar1 = (_currentBeatIndex1 / 4).floor() + 1;
          _currentBeatInBar1 = (_currentBeatIndex1 % 4) + 1;
        }
      }

      // Update Loop 2
      if (_state2 != LooperState.empty) {
        final double elapsed2 = _stopwatch2.elapsedMilliseconds.toDouble();
        if (_state2 == LooperState.countIn) {
          if (elapsed2 >= total) {
            _triggerSwitch(2);
            _stopwatch2.reset();
            _state2 = LooperState.recording;
          } else {
            _sweepProgress2 = elapsed2 / total;
            _currentBeatIndex2 = (elapsed2 / beatDurationMs).floor().clamp(0, 15);
            _currentBar2 = (_currentBeatIndex2 / 4).floor() + 1;
            _currentBeatInBar2 = (_currentBeatIndex2 % 4) + 1;
          }
        } else if (_state2 == LooperState.recording) {
          if (elapsed2 >= total) {
            _triggerSwitch(2);
            _stopwatch2.reset();
            _state2 = LooperState.playing;
          } else {
            _sweepProgress2 = elapsed2 / total;
            _currentBeatIndex2 = (elapsed2 / beatDurationMs).floor().clamp(0, 15);
            _currentBar2 = (_currentBeatIndex2 / 4).floor() + 1;
            _currentBeatInBar2 = (_currentBeatIndex2 % 4) + 1;
          }
        } else if (_state2 == LooperState.playing) {
          final double loopElapsed2 = elapsed2 % total;
          _sweepProgress2 = loopElapsed2 / total;
          _currentBeatIndex2 = (loopElapsed2 / beatDurationMs).floor().clamp(0, 15);
          _currentBar2 = (_currentBeatIndex2 / 4).floor() + 1;
          _currentBeatInBar2 = (_currentBeatIndex2 % 4) + 1;
        }
      }

      notifyListeners();
    });
  }

  // Sends simulated single click/tap on ALO's loop1 or loop2
  Future<void> _triggerSwitch(int loopNum) async {
    if (_activeLooper == null) return;
    final port = loopNum == 1 ? 'loop1' : 'loop2';
    
    // Tap - Press
    webSocketService.setParamValue(
      instance: _activeLooper!.instance,
      port: port,
      value: 1.0,
    );
    
    // Release after 100ms
    await Future.delayed(const Duration(milliseconds: 100));
    webSocketService.setParamValue(
      instance: _activeLooper!.instance,
      port: port,
      value: 0.0,
    );
  }

  // Emulates Foot-Switch Double-Tap to Clear Loop Memory
  Future<void> _triggerDoubleSwitch(int loopNum) async {
    if (_activeLooper == null) return;

    // First Tap
    await _triggerSwitch(loopNum);
    
    // Wait for physical gap
    await Future.delayed(const Duration(milliseconds: 150));
    
    // Second Tap
    await _triggerSwitch(loopNum);
  }

  // Start 4-Bar Count-In + 4-Bar Record sequence for loop 1 or 2
  void recordSequence([int loopNum = 1]) {
    if (_activeLooper == null) return;
    
    _resetStateFor(loopNum);
    if (loopNum == 1) {
      _state1 = LooperState.countIn;
      _stopwatch1.start();
    } else {
      _state2 = LooperState.countIn;
      _stopwatch2.start();
    }
    _startSweepTimer();
    notifyListeners();
  }

  // Cancel/clear record/countIn/play
  void cancelRecord([int loopNum = 1]) {
    _resetStateFor(loopNum);
    notifyListeners();
  }

  // Pause the Looper playback
  void pauseLoop([int loopNum = 1]) {
    if (_activeLooper == null) return;
    final currentState = loopNum == 1 ? _state1 : _state2;
    if (currentState != LooperState.playing) return;
    
    _triggerSwitch(loopNum);
    if (loopNum == 1) {
      _stopwatch1.stop();
      _state1 = LooperState.paused;
    } else {
      _stopwatch2.stop();
      _state2 = LooperState.paused;
    }
    notifyListeners();
  }

  // Resume Looper playback
  void playLoop([int loopNum = 1]) {
    if (_activeLooper == null) return;
    final currentState = loopNum == 1 ? _state1 : _state2;
    if (currentState != LooperState.paused) return;
    
    _triggerSwitch(loopNum);
    if (loopNum == 1) {
      _stopwatch1.start();
      _state1 = LooperState.playing;
    } else {
      _stopwatch2.start();
      _state2 = LooperState.playing;
    }
    _startSweepTimer();
    notifyListeners();
  }

  // Clear current loop memory
  void clearLoop([int loopNum = 1]) {
    if (_activeLooper == null) return;
    
    _triggerDoubleSwitch(loopNum);
    _resetStateFor(loopNum);
    notifyListeners();
  }

  // Manual Trigger Bypass Switch
  void manualTrigger([int loopNum = 1]) {
    _triggerSwitch(loopNum);
  }

  void _resetState() {
    _stopwatch1.stop();
    _stopwatch1.reset();
    _stopwatch2.stop();
    _stopwatch2.reset();
    _sweepTimer?.cancel();
    _sweepTimer = null;
    _state1 = LooperState.empty;
    _state2 = LooperState.empty;
    _sweepProgress1 = 0.0;
    _currentBeatIndex1 = 0;
    _currentBar1 = 1;
    _currentBeatInBar1 = 1;
    _sweepProgress2 = 0.0;
    _currentBeatIndex2 = 0;
    _currentBar2 = 1;
    _currentBeatInBar2 = 1;
  }

  void _resetStateFor(int loopNum) {
    if (loopNum == 1) {
      _stopwatch1.stop();
      _stopwatch1.reset();
      _state1 = LooperState.empty;
      _sweepProgress1 = 0.0;
      _currentBeatIndex1 = 0;
      _currentBar1 = 1;
      _currentBeatInBar1 = 1;
    } else {
      _stopwatch2.stop();
      _stopwatch2.reset();
      _state2 = LooperState.empty;
      _sweepProgress2 = 0.0;
      _currentBeatIndex2 = 0;
      _currentBar2 = 1;
      _currentBeatInBar2 = 1;
    }
    if (_state1 == LooperState.empty && _state2 == LooperState.empty) {
      _sweepTimer?.cancel();
      _sweepTimer = null;
    }
  }

  @override
  void dispose() {
    webSocketService.allPlugins.removeListener(_updateDiscoveredLoopers);
    _sweepTimer?.cancel();
    discoveredLoopers.dispose();
    super.dispose();
  }
}
