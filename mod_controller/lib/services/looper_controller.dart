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

  LooperState _state = LooperState.empty;
  PluginInstance? _activeLooper;
  
  // Stopwatch & Timers for ultra-smooth 60fps timeline sweeps
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _sweepTimer;
  
  // Animation fractions and counts
  double _sweepProgress = 0.0; // 0.0 to 1.0 sweeping timeline
  int _currentBeatIndex = 0;   // 0 to 15 (16 beats total)
  int _currentBar = 1;         // 1 to 4
  int _currentBeatInBar = 1;   // 1 to 4
  
  // Dynamic list of discovered loopers
  final ValueNotifier<List<PluginInstance>> discoveredLoopers =
      ValueNotifier<List<PluginInstance>>([]);

  LooperController({required this.webSocketService}) {
    // Listen to all discovered plugins to extract ALO loopers
    webSocketService.allPlugins.addListener(_updateDiscoveredLoopers);
  }

  LooperState get state => _state;
  PluginInstance? get activeLooper => _activeLooper;
  double get sweepProgress => _sweepProgress;
  int get currentBeatIndex => _currentBeatIndex;
  int get currentBar => _currentBar;
  int get currentBeatInBar => _currentBeatInBar;
  
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
    _sweepTimer?.cancel();
    _sweepTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (_state == LooperState.empty || _activeLooper == null) {
        timer.cancel();
        return;
      }

      final double elapsed = _stopwatch.elapsedMilliseconds.toDouble();
      final double total = totalDurationMs;

      if (_state == LooperState.countIn) {
        if (elapsed >= total) {
          // Transition: End of Count-In -> Click to start recording!
          _triggerSwitch();
          _stopwatch.reset();
          _state = LooperState.recording;
        } else {
          _sweepProgress = elapsed / total;
          _calculateBeatMetrics(elapsed);
        }
      } else if (_state == LooperState.recording) {
        if (elapsed >= total) {
          // Transition: End of Recording -> Click to stop and play!
          _triggerSwitch();
          _stopwatch.reset();
          _state = LooperState.playing;
        } else {
          _sweepProgress = elapsed / total;
          _calculateBeatMetrics(elapsed);
        }
      } else if (_state == LooperState.playing) {
        // Continuous looping sweep progress
        final double loopElapsed = elapsed % total;
        _sweepProgress = loopElapsed / total;
        _calculateBeatMetrics(loopElapsed);
      }

      notifyListeners();
    });
  }

  void _calculateBeatMetrics(double elapsedMs) {
    final double beatSize = beatDurationMs;
    _currentBeatIndex = (elapsedMs / beatSize).floor().clamp(0, 15);
    _currentBar = (_currentBeatIndex / 4).floor() + 1;
    _currentBeatInBar = (_currentBeatIndex % 4) + 1;
  }

  // Sends simulated single click/tap on ALO's loop1
  Future<void> _triggerSwitch() async {
    if (_activeLooper == null) return;
    
    // Tap Down
    webSocketService.setParamValue(
      instance: _activeLooper!.instance,
      port: 'loop1',
      value: 1.0,
    );
    
    await Future.delayed(const Duration(milliseconds: 50));
    
    // Tap Up
    webSocketService.setParamValue(
      instance: _activeLooper!.instance,
      port: 'loop1',
      value: 0.0,
    );
  }

  // Emulates Foot-Switch Double-Tap to Clear Loop Memory
  Future<void> _triggerDoubleSwitch() async {
    if (_activeLooper == null) return;

    // First Tap
    await _triggerSwitch();
    
    // Wait for physical gap
    await Future.delayed(const Duration(milliseconds: 150));
    
    // Second Tap
    await _triggerSwitch();
  }

  // Start 4-Bar Count-In + 4-Bar Record sequence
  void recordSequence() {
    if (_activeLooper == null) return;
    
    _resetState();
    _state = LooperState.countIn;
    _stopwatch.start();
    _startSweepTimer();
    notifyListeners();
  }

  // Pause the Looper playback
  void pauseLoop() {
    if (_activeLooper == null || _state != LooperState.playing) return;
    
    _triggerSwitch();
    _stopwatch.stop();
    _state = LooperState.paused;
    notifyListeners();
  }

  // Resume Looper playback
  void playLoop() {
    if (_activeLooper == null || _state != LooperState.paused) return;
    
    _triggerSwitch();
    _stopwatch.start();
    _state = LooperState.playing;
    _startSweepTimer();
    notifyListeners();
  }

  // Clear current loop memory
  void clearLoop() {
    if (_activeLooper == null) return;
    
    _triggerDoubleSwitch();
    _resetState();
    notifyListeners();
  }

  // Manual Trigger Bypass Switch (Period Key Trigger)
  void manualTrigger() {
    _triggerSwitch();
  }

  void _resetState() {
    _stopwatch.stop();
    _stopwatch.reset();
    _sweepTimer?.cancel();
    _sweepTimer = null;
    _state = LooperState.empty;
    _sweepProgress = 0.0;
    _currentBeatIndex = 0;
    _currentBar = 1;
    _currentBeatInBar = 1;
  }

  @override
  void dispose() {
    webSocketService.allPlugins.removeListener(_updateDiscoveredLoopers);
    _sweepTimer?.cancel();
    discoveredLoopers.dispose();
    super.dispose();
  }
}
