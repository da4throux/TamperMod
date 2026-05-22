import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/plugin_instance.dart';
import 'websocket_service.dart';

enum LooperState { empty, countIn, recording, playing, paused }

class LooperController extends ChangeNotifier {
  final ModWebSocketService webSocketService;

  // Global stopwatch for beat sync
  final Stopwatch _globalStopwatch = Stopwatch();

  // State for all 6 loops
  final List<LooperState> _states = List.filled(6, LooperState.empty);
  int _selectedLoopIndex = 0; // 0-5 representing loops 1-6
  PluginInstance? _activeLooper;

  // Stopwatch & Timers for ultra-smooth 60fps timeline sweeps
  final List<Stopwatch> _stopwatches = List.generate(6, (_) => Stopwatch());
  Timer? _sweepTimer;

  // Animation fractions and counts for all 6 loops
  final List<double> _sweepProgress = List.filled(6, 0.0);
  final List<int> _currentBeatIndex = List.filled(6, 0);
  final List<int> _currentBar = List.filled(6, 1);
  final List<int> _currentBeatInBar = List.filled(6, 1);

  // Dynamic list of discovered loopers
  final ValueNotifier<List<PluginInstance>> discoveredLoopers =
      ValueNotifier<List<PluginInstance>>([]);

  LooperController({required this.webSocketService}) {
    _globalStopwatch.start();
    // Listen to all discovered plugins to extract ALO loopers
    webSocketService.allPlugins.addListener(_updateDiscoveredLoopers);
  }

  // Getters for loop-specific states
  LooperState getState(int loopNum) => _states[loopNum - 1];
  double getSweepProgress(int loopNum) => _sweepProgress[loopNum - 1];
  int getCurrentBeatIndex(int loopNum) => _currentBeatIndex[loopNum - 1];
  int getCurrentBar(int loopNum) => _currentBar[loopNum - 1];
  int getCurrentBeatInBar(int loopNum) => _currentBeatInBar[loopNum - 1];

  // Selected loop getters
  int get selectedLoopIndex => _selectedLoopIndex;
  int get selectedLoopNum => _selectedLoopIndex + 1;

  // Backward compatibility getters (mapping to selected loop)
  LooperState get state => _states[_selectedLoopIndex];
  PluginInstance? get activeLooper => _activeLooper;
  double get sweepProgress => _sweepProgress[_selectedLoopIndex];
  int get currentBeatIndex => _currentBeatIndex[_selectedLoopIndex];
  int get currentBar => _currentBar[_selectedLoopIndex];
  int get currentBeatInBar => _currentBeatInBar[_selectedLoopIndex];

  double get bpm => webSocketService.bpm.value;
  double get beatDurationMs => (60.0 / bpm) * 1000.0;
  double get totalDurationMs => beatDurationMs * 16.0; // 4 bars = 16 beats

  void _updateDiscoveredLoopers() {
    final List<PluginInstance> loopers = webSocketService.allPlugins.value
        .where((p) {
          final uriLower = p.uri.toLowerCase();
          final titleLower = p.title.toLowerCase();
          return uriLower.contains('alo') || titleLower.contains('alo');
        })
        .toList();

    discoveredLoopers.value = loopers;

    // Default to the first discovered looper if none is active
    if (loopers.isNotEmpty &&
        (_activeLooper == null ||
            !loopers.any((p) => p.instance == _activeLooper!.instance))) {
      setActiveLooper(loopers.first);
    } else if (loopers.isEmpty) {
      _activeLooper = null;
      _resetState();
      notifyListeners();
    }
  }

  void setActiveLooper(PluginInstance looper) {
    if (_activeLooper?.instance == looper.instance) return;
    _activeLooper = looper;
    _resetState();
    _selectedLoopIndex = 0; // Default to loop 1
    notifyListeners();
  }

  void selectLoop(int loopNum) {
    if (loopNum < 1 || loopNum > 6) return;
    _selectedLoopIndex = loopNum - 1;
    notifyListeners();
  }

  // Visual & Logical sweep loop running at 60fps (every 16ms)
  void _startSweepTimer() {
    if (_sweepTimer != null) return;
    _sweepTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      bool anyActive = _states.any((state) => state != LooperState.empty);
      if (!anyActive || _activeLooper == null) {
        timer.cancel();
        _sweepTimer = null;
        return;
      }

      final double total = totalDurationMs;

      // Update all 6 loops
      for (int i = 0; i < 6; i++) {
        if (_states[i] != LooperState.empty) {
          final double elapsed = _stopwatches[i].elapsedMilliseconds.toDouble();
          if (_states[i] == LooperState.countIn) {
            // Count-in is now just waiting for next beat (handled by Future.delayed)
            // If it's still here, just show the sweep progress
            _sweepProgress[i] = 1.0; 
          } else if (_states[i] == LooperState.recording) {
            if (elapsed >= total) {
              _stopwatches[i].reset();
              _states[i] = LooperState.playing;
            } else {
              _sweepProgress[i] = elapsed / total;
              _currentBeatIndex[i] = (elapsed / beatDurationMs).floor().clamp(
                0,
                15,
              );
              _currentBar[i] = (_currentBeatIndex[i] / 4).floor() + 1;
              _currentBeatInBar[i] = (_currentBeatIndex[i] % 4) + 1;
            }
          } else if (_states[i] == LooperState.playing ||
              _states[i] == LooperState.paused) {
            final double loopElapsed = elapsed % total;
            _sweepProgress[i] = loopElapsed / total;
            _currentBeatIndex[i] = (loopElapsed / beatDurationMs).floor().clamp(
              0,
              15,
            );
            _currentBar[i] = (_currentBeatIndex[i] / 4).floor() + 1;
            _currentBeatInBar[i] = (_currentBeatIndex[i] % 4) + 1;
          }
        }
      }

      notifyListeners();
    });
  }

  // Sends raw parameter value to loop1-6 of ALO
  void _sendLooperValue(int loopNum, double value) {
    if (_activeLooper == null) return;
    final port = 'loop$loopNum';
    webSocketService.setParamValue(
      instance: _activeLooper!.instance,
      port: port,
      value: value,
    );
  }

  // Sends simulated single click/tap on ALO's loop
  Future<void> _triggerSwitch(int loopNum) async {
    if (_activeLooper == null) return;
    final port = 'loop$loopNum';

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

  // Start recording synced to the next beat
  void recordSequence([int loopNum = 1]) {
    if (_activeLooper == null) return;

    _resetStateFor(loopNum);
    final idx = loopNum - 1;
    
    // Calculate wait time until next beat based on global stopwatch
    final double elapsedGlobal = _globalStopwatch.elapsedMilliseconds.toDouble();
    final double beatDuration = beatDurationMs;
    final double waitTimeMs = beatDuration - (elapsedGlobal % beatDuration);
    
    _states[idx] = LooperState.countIn;
    notifyListeners();
    
    Future.delayed(Duration(milliseconds: waitTimeMs.toInt()), () {
      if (_states[idx] == LooperState.countIn) {
        _sendLooperValue(loopNum, 1.0);
        _stopwatches[idx].start();
        _states[idx] = LooperState.recording;
        _startSweepTimer();
        notifyListeners();
      }
    });
  }

  // Cancel/clear record/countIn/play
  void cancelRecord([int loopNum = 1]) {
    _resetStateFor(loopNum);
    notifyListeners();
  }

  // Pause the Looper playback
  void pauseLoop([int loopNum = 1]) {
    if (_activeLooper == null) return;
    final idx = loopNum - 1;
    if (_states[idx] != LooperState.playing) return;

    _sendLooperValue(loopNum, 0.0);
    _states[idx] = LooperState.paused;
    notifyListeners();
  }

  // Resume Looper playback
  void playLoop([int loopNum = 1]) {
    if (_activeLooper == null) return;
    final idx = loopNum - 1;
    if (_states[idx] != LooperState.paused) return;

    _sendLooperValue(loopNum, 1.0);
    _stopwatches[idx].start();
    _states[idx] = LooperState.playing;
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
    for (int i = 0; i < 6; i++) {
      _stopwatches[i].stop();
      _stopwatches[i].reset();
      _states[i] = LooperState.empty;
      _sweepProgress[i] = 0.0;
      _currentBeatIndex[i] = 0;
      _currentBar[i] = 1;
      _currentBeatInBar[i] = 1;
    }
    _sweepTimer?.cancel();
    _sweepTimer = null;
  }

  void _resetStateFor(int loopNum) {
    final idx = loopNum - 1;
    if (idx < 0 || idx >= 6) return;

    _stopwatches[idx].stop();
    _stopwatches[idx].reset();
    _states[idx] = LooperState.empty;
    _sweepProgress[idx] = 0.0;
    _currentBeatIndex[idx] = 0;
    _currentBar[idx] = 1;
    _currentBeatInBar[idx] = 1;

    if (_states.every((state) => state == LooperState.empty)) {
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
