// Copyright (c) 2026 TamperMod Contributors
// Licensed under the MIT License

import 'package:flutter/material.dart';
import '../models/plugin_instance.dart';

enum PluginCategoryType {
  drive,
  delay,
  reverb,
  modulation,
  ampCab,
  eqFilter,
  compressor,
  pitchSynth,
  switcher,
  gainVolume,
  looper,
  utility,
  lineBreak,
  spacer,
}

class PluginCategoryInfo {
  final PluginCategoryType type;
  final String label;
  final String shortCode;
  final IconData icon;
  final String description;
  final Color defaultColor;

  const PluginCategoryInfo({
    required this.type,
    required this.label,
    required this.shortCode,
    required this.icon,
    required this.description,
    required this.defaultColor,
  });
}

class PluginCategoryHelper {
  static const Map<PluginCategoryType, PluginCategoryInfo> categories = {
    PluginCategoryType.drive: PluginCategoryInfo(
      type: PluginCategoryType.drive,
      label: 'Drive & Fuzz',
      shortCode: 'DRIVE',
      icon: Icons.bolt,
      description: 'Overdrive, Distortion, Fuzz, Crunch, Preamp clipping & Saturation',
      defaultColor: Color(0xFFFF5500),
    ),
    PluginCategoryType.delay: PluginCategoryInfo(
      type: PluginCategoryType.delay,
      label: 'Delay & Echo',
      shortCode: 'DELAY',
      icon: Icons.waves,
      description: 'Tape Echo, Analog/Digital Delay, Ping-Pong & Space Echo',
      defaultColor: Color(0xFF00FFCC),
    ),
    PluginCategoryType.reverb: PluginCategoryInfo(
      type: PluginCategoryType.reverb,
      label: 'Reverb',
      shortCode: 'REVERB',
      icon: Icons.blur_on,
      description: 'Spring, Plate, Hall, Room, Shimmer & Convolution Reverb',
      defaultColor: Color(0xFF9D00FF),
    ),
    PluginCategoryType.modulation: PluginCategoryInfo(
      type: PluginCategoryType.modulation,
      label: 'Modulation',
      shortCode: 'MOD',
      icon: Icons.vibration,
      description: 'Chorus, Flanger, Phaser, Tremolo, Vibrato, Rotary & Uni-Vibe',
      defaultColor: Color(0xFFFF007F),
    ),
    PluginCategoryType.ampCab: PluginCategoryInfo(
      type: PluginCategoryType.ampCab,
      label: 'Amp & Cabinet',
      shortCode: 'AMP/CAB',
      icon: Icons.speaker,
      description: 'Guitar/Bass Amplifiers, Cabinet Simulators & Impulse Responses',
      defaultColor: Color(0xFFFF9900),
    ),
    PluginCategoryType.eqFilter: PluginCategoryInfo(
      type: PluginCategoryType.eqFilter,
      label: 'EQ & Filter',
      shortCode: 'EQ/FLT',
      icon: Icons.equalizer,
      description: 'Parametric/Graphic EQ, Wah, Low-Pass, High-Pass & Band-Pass',
      defaultColor: Color(0xFF00FF66),
    ),
    PluginCategoryType.compressor: PluginCategoryInfo(
      type: PluginCategoryType.compressor,
      label: 'Dynamics',
      shortCode: 'COMP',
      icon: Icons.compress,
      description: 'Compressor, Limiter, Noise Gate, De-Esser & Transient Shaper',
      defaultColor: Color(0xFF00B3FF),
    ),
    PluginCategoryType.pitchSynth: PluginCategoryInfo(
      type: PluginCategoryType.pitchSynth,
      label: 'Pitch & Synth',
      shortCode: 'SYNTH',
      icon: Icons.graphic_eq,
      description: 'Pitch Shifter, Octaver, Harmonizer, Oscillators & Synthesizers',
      defaultColor: Color(0xFFFF00CC),
    ),
    PluginCategoryType.switcher: PluginCategoryInfo(
      type: PluginCategoryType.switcher,
      label: 'Switch & Route',
      shortCode: 'SWITCH',
      icon: Icons.alt_route,
      description: 'A/B Box, Signal Switchers, Crossfaders, Routers & Splitters',
      defaultColor: Color(0xFF00E5FF),
    ),
    PluginCategoryType.gainVolume: PluginCategoryInfo(
      type: PluginCategoryType.gainVolume,
      label: 'Gain & Volume',
      shortCode: 'GAIN',
      icon: Icons.volume_up,
      description: 'Mono/Stereo Gain, Volume sliders, Attenuators & Mute controls',
      defaultColor: Color(0xFF00FFCC),
    ),
    PluginCategoryType.looper: PluginCategoryInfo(
      type: PluginCategoryType.looper,
      label: 'Looper',
      shortCode: 'LOOPER',
      icon: Icons.loop,
      description: 'Multi-Track Audio Loopers, ALO Live Looper & Phrase Samplers',
      defaultColor: Color(0xFFFF0055),
    ),
    PluginCategoryType.utility: PluginCategoryInfo(
      type: PluginCategoryType.utility,
      label: 'Utility & CV',
      shortCode: 'UTIL',
      icon: Icons.developer_board,
      description: 'Control Voltage (CV), MIDI processors, Generators & Analyzers',
      defaultColor: Color(0xFFAAAAAA),
    ),
    PluginCategoryType.lineBreak: PluginCategoryInfo(
      type: PluginCategoryType.lineBreak,
      label: 'Line Break',
      shortCode: 'BREAK',
      icon: Icons.wrap_text,
      description: 'Visual row separator in the dashboard and puzzle organizer',
      defaultColor: Color(0xFF00FFCC),
    ),
    PluginCategoryType.spacer: PluginCategoryInfo(
      type: PluginCategoryType.spacer,
      label: 'Spacer',
      shortCode: 'SPACE',
      icon: Icons.space_bar,
      description: 'Transparent placeholder card for custom grid alignment',
      defaultColor: Color(0xFF777777),
    ),
  };

  static String getCategoryEmoji(PluginCategoryType type) {
    switch (type) {
      case PluginCategoryType.drive:
        return '⚡';
      case PluginCategoryType.delay:
        return '⏱️';
      case PluginCategoryType.reverb:
        return '🌊';
      case PluginCategoryType.modulation:
        return '🔄';
      case PluginCategoryType.ampCab:
        return '📢';
      case PluginCategoryType.eqFilter:
        return '🎚️';
      case PluginCategoryType.compressor:
        return '🗜️';
      case PluginCategoryType.pitchSynth:
        return '🎹';
      case PluginCategoryType.switcher:
        return '🔀';
      case PluginCategoryType.gainVolume:
        return '🔊';
      case PluginCategoryType.looper:
        return '🔁';
      case PluginCategoryType.utility:
        return '🎛️';
      case PluginCategoryType.lineBreak:
      case PluginCategoryType.spacer:
        return '🧩';
    }
  }

  static PluginCategoryInfo getCategoryForPlugin(PluginInstance pedal) {
    final String instanceId = pedal.instance;
    if (instanceId.startsWith('__linebreak_')) {
      return categories[PluginCategoryType.lineBreak]!;
    }
    if (instanceId.startsWith('__spacer_')) {
      return categories[PluginCategoryType.spacer]!;
    }

    final String uri = pedal.uri.toLowerCase();
    final String title = pedal.title.toLowerCase();
    final String inst = instanceId.toLowerCase();

    // 1. Looper
    if (uri.contains('alo') || title.contains('alo') || inst.contains('alo') ||
        uri.contains('sooperlooper') || title.contains('looper')) {
      return categories[PluginCategoryType.looper]!;
    }

    // 2. Switch & Route
    if (uri.contains('switch') || title.contains('switch') || inst.contains('switch') ||
        uri.contains('route') || title.contains('route') ||
        uri.contains('crossfade') || title.contains('crossfade') ||
        uri.contains('split') || title.contains('split') ||
        uri.contains('a_b') || title.contains('a/b')) {
      return categories[PluginCategoryType.switcher]!;
    }

    // 3. Delay & Echo
    if (uri.contains('delay') || title.contains('delay') || inst.contains('delay') ||
        uri.contains('echo') || title.contains('echo') ||
        uri.contains('dub') || title.contains('tape') ||
        uri.contains('binson') || uri.contains('bucket')) {
      return categories[PluginCategoryType.delay]!;
    }

    // 4. Reverb
    if (uri.contains('reverb') || title.contains('reverb') || inst.contains('reverb') ||
        uri.contains('room') || uri.contains('hall') ||
        uri.contains('plate') || uri.contains('spring') ||
        uri.contains('shimmer') || uri.contains('freeverb') ||
        uri.contains('gverb') || uri.contains('dragonfly') ||
        uri.contains('convo')) {
      return categories[PluginCategoryType.reverb]!;
    }

    // 5. Drive, Distortion, Fuzz, Preamp
    if (uri.contains('dist') || title.contains('dist') || inst.contains('dist') ||
        uri.contains('fuzz') || title.contains('fuzz') ||
        uri.contains('drive') || title.contains('drive') ||
        uri.contains('ts9') || uri.contains('muff') ||
        uri.contains('ds1') || uri.contains('rat') ||
        uri.contains('tube') || uri.contains('crunch') ||
        uri.contains('saturat') || uri.contains('clip') ||
        uri.contains('metal') || uri.contains('lead')) {
      return categories[PluginCategoryType.drive]!;
    }

    // 6. Modulation (Chorus, Flanger, Phaser, Tremolo, Vibrato)
    if (uri.contains('chorus') || title.contains('chorus') ||
        uri.contains('flang') || title.contains('flang') ||
        uri.contains('phase') || title.contains('phase') ||
        uri.contains('tremolo') || title.contains('tremolo') ||
        uri.contains('vibrato') || title.contains('vibrato') ||
        uri.contains('rotary') || uri.contains('univibe') ||
        uri.contains('detune') || uri.contains('ring')) {
      return categories[PluginCategoryType.modulation]!;
    }

    // 7. Amp & Cabinet
    if (uri.contains('cabinet') || title.contains('cabinet') ||
        uri.contains('cab') || title.contains('cab') ||
        uri.contains('gx_cabinet') || uri.contains('head') ||
        uri.contains('preamp') || uri.contains('marshall') ||
        uri.contains('fender') || uri.contains('vox') ||
        uri.contains('ir_lv2') || uri.contains('neural') ||
        uri.contains('nam') || (title.contains('amp') && !title.contains('ampere') && !title.contains('sample'))) {
      return categories[PluginCategoryType.ampCab]!;
    }

    // 8. Pitch & Synth
    if (uri.contains('pitch') || title.contains('pitch') ||
        uri.contains('octave') || title.contains('octave') ||
        uri.contains('whammy') || title.contains('harmon') ||
        uri.contains('synth') || title.contains('synth') ||
        uri.contains('gen8sp') || title.contains('gen8sp') ||
        uri.contains('oscillator') || uri.contains('generator')) {
      return categories[PluginCategoryType.pitchSynth]!;
    }

    // 9. Dynamics & Compressor
    if (uri.contains('comp') || title.contains('comp') ||
        uri.contains('limiter') || title.contains('limiter') ||
        uri.contains('gate') || title.contains('gate') ||
        uri.contains('expander') || uri.contains('dyn')) {
      return categories[PluginCategoryType.compressor]!;
    }

    // 10. EQ & Filter
    if (uri.contains('eq') || title.contains('eq') ||
        uri.contains('filter') || title.contains('filter') ||
        uri.contains('wah') || title.contains('wah') ||
        uri.contains('equalizer') || uri.contains('bandpass') ||
        uri.contains('lowpass') || uri.contains('highpass') ||
        uri.contains('notch')) {
      return categories[PluginCategoryType.eqFilter]!;
    }

    // 11. Gain & Volume
    if (uri.contains('gain') || title.contains('gain') ||
        uri.contains('volume') || title.contains('volume') ||
        uri.contains('mono') || title.contains('mono') ||
        uri.contains('stereo') || title.contains('stereo') ||
        uri.contains('tinygain') || uri.contains('attenuat') ||
        uri.contains('level') || uri.contains('bypass') || title.contains('bypass')) {
      return categories[PluginCategoryType.gainVolume]!;
    }

    // 12. Utility / CV
    if (uri.contains('cv') || uri.contains('midi') || uri.contains('lfo') ||
        uri.contains('clock') || uri.contains('step') || uri.contains('meter')) {
      return categories[PluginCategoryType.utility]!;
    }

    // Default fallback
    return categories[PluginCategoryType.utility]!;
  }
}
