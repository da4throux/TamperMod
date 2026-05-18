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
      overview: 'Provides high-precision synchronized control of the ALO Looper plugin on the MOD Dwarf, utilizing a 4-bar count-in timer aligned to the active host BPM to automate recording.',
      parameters: [
        '4-Bar Count-in: Tapping Record starts a 16-beat countdown. Flashing green/yellow visual markers and an active progress sweeping indicator guide you in.',
        '4-Bar Automated Record: Starts recording at the precise beat 0, records for 16 beats (pulsing bright neon red), and stops recording automatically to start playing.',
        'Pause / Play: Suspends playback and resumes instantly.',
        'Double-Tap Clear: Sends two rapid triggers to the looper pedal to completely wipe the current loop memory.',
      ],
      hotkeys: [
        'Period (.) Key: Directly click/trigger the looper button without countdown.',
        'Minus (-) Key: Play / Pause loop toggle.',
        'Equal (=) Key: Automated 4-bar record sequence.',
        'Backspace Key: Clear current loop memory.',
      ],
      underTheHood: 'Interfaces directly with the ALO Looper plugin (e.g., /graph/alo_2) by sending rapid parameter toggles (1.0 then 0.0) on the "loop1" port to emulate foot-pedal clicks.',
    ),
  };
}
