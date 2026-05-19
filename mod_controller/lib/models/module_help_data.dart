import 'package:flutter/material.dart';

class ModuleHelpData {
  final String key;
  final String title;
  final IconData icon;
  final String overview;
  final List<String> parameters;
  final List<String> hotkeys;
  final String underTheHood;

  const ModuleHelpData({
    required this.key,
    required this.title,
    required this.icon,
    required this.overview,
    required this.parameters,
    required this.hotkeys,
    required this.underTheHood,
  });

  static const Map<String, ModuleHelpData> registry = {
    'gain': ModuleHelpData(
      key: 'gain',
      title: 'Volume & Gain Card',
      icon: Icons.volume_up,
      overview: 'Controls the audio volume and gain parameters for an instrument on the pedalboard. Provides smooth fade-in and fade-out automation transitions over a customizable beat/bar period.',
      parameters: [
        'Gain Slider: Allows real-time adjustment of current output levels in decibels (dB). Limit configurations auto-adapt between -60dB and +40dB based on plugin parameters.',
        'Bypass Toggle: Enables or disables the Gain plugin instantaneously. The bypass color halo updates dynamically to match the active color preset.',
        'Neon Glow Picker: Toggles permanent ambient neon halos around the physical plugin on the MOD Dwarf web canvas, using a strip of five hand-picked colors.',
      ],
      hotkeys: [
        'Digit Keys (0-9): Highlight and select specific Gain cards.',
        'Arrow Up / Arrow Down: Adjust volume up or down in small steps.',
        'A / S Keys: Trigger smooth 4-bar linear Fade-In or Fade-Out automation.',
      ],
      underTheHood: 'Maps directly to any gain, volume, or amplifier plugin (e.g., /graph/mono, /graph/Gain_1) on the MOD Dwarf. Automations trigger rapid real-time WebSocket "param_set" updates to the volume control port.',
    ),
    'switch': ModuleHelpData(
      key: 'switch',
      title: 'Routing Switch Card',
      icon: Icons.alt_route,
      overview: 'Directs the guitar or instrument audio signals between different signal chains, such as swapping between a pristine Clean path and a heavy distortion/drive path.',
      parameters: [
        'Clean / Heavy Toggle Buttons: Double-buffered routes allowing quick path selection with instant parameter feedback.',
        'Bypass Switch: Totally silences or bypasses the switcher plugin, muting the downstream effects chains.',
        'Neon Glow Accent: Adapts the borders and button colors to match your chosen glow color.',
      ],
      hotkeys: [
        'Spacebar (when card is highlighted): Toggle switcher route.',
        'M Key: Quick mute or bypass switch card.',
      ],
      underTheHood: 'Controls a multi-path switch plugin (e.g., a two-way toggle switch) on the MOD Dwarf. Changes execute WebSocket "param_set" instructions targetting the toggle port.',
    ),
    'looper': ModuleHelpData(
      key: 'looper',
      title: 'ALO Sync Looper Controller',
      icon: Icons.music_video,
      overview: 'High-precision control of the ALO (Audio Looper) LV2 multi-track plugin. **IMPORTANT: You MUST turn the global host BPM transport ON (Play button next to BPM) for the looper to sync and record. ALO does not pass the dry input signal through to its output (route your dry signal separately).**',
      parameters: [
        'Track Loop Switch: Arm a loop track by tapping its button (or TAP 1 / TAP 2). Recording begins automatically as soon as your input signal crosses the configured Threshold.',
        'Bypass / Power: Bypasses the looper. Tap the power button in the looper header to enable/disable.',
        'Threshold: Sets the input signal level (in dB) required to automatically trigger recording once armed.',
        'Click Volume: Adjusts the host metronome click volume (1 to 100) audible during recording/sync.',
        'Mix Setting: Balances dry input vs recorded loops. 100 is loop-only playback (dry muted); 0 is dry signal only.',
        'Instant Loops: Toggle parameter for immediate trigger action.',
        'Reset Mode: Defines the subdivision sync behavior for clearing loop tracks.',
      ],
      hotkeys: [
        'Period (.) Key: Trigger Loop 1 switch.',
        'Comma (,) Key: Trigger Loop 2 switch.',
        'Minus (-) Key: Toggle Host Transport Play/Pause.',
        'Backspace / Delete: Clear Loop 1 / Loop 2 memory.',
      ],
      underTheHood: 'ALO loop controls behave like physical momentary switches. The app triggers them by sending 1.0 (Press) and immediately scheduling a release value of 0.0 after 100ms. Double-tap triggers send two distinct pulses separated by a short gap (e.g. 50ms, 100ms, or 150ms) within 1 second to wipe/reset the loop track.',
    ),
  };
}
