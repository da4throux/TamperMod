# TamperMod — Current Focus

## ✅ Completed (v1.4.2)
- **Type Icons on Hover Tag & Gain Direct Control Mode**:
  1. **Type / Category Icons in Name Hover Tag**: The WebView hover tag now displays the pedal category emoji (e.g. 🔊 GAIN, ⚡ DRIVE, 🌊 REVERB, ⏱️ DELAY, 🔄 MOD, 🔀 SWITCH, 🔁 LOOPER, 🎛️ UTIL) + category short-code chip alongside the pedal name and placement status.
  2. **Direct Gain & Mute Option for Gain / TinyGain Cards**:
     - **Mode Switcher Button**: Tap the mode icon (`Icons.tune` / `Icons.auto_graph`) in the card header to switch between **Fade Automation Mode** (default) and **Direct Gain & Mute Mode**.
     - **Prominent Gain Readout View**: Monospaced glowing dB display showing live level (e.g. `+0.0 dB`).
     - **Dedicated Mute Button**: High-visibility MUTE / MUTED toggle with glowing state.
     - **Volume Slider with Nudge Buttons**: Integrated `[-1 dB]` / `[+1 dB]` step buttons for quick adjustments.
     - **Quick Step Presets**: `[-6 dB]` `[-3 dB]` `[-1 dB]` `[ 0 dB ]` `[+1 dB]` `[+3 dB]` `[+6 dB]` quick jump pills.

## 📋 Remaining Tasks
- **A2. WebView Controls**: WebView full-screen toggle, separation layout adjustment.
- **E2. Default Fadeout Values**: Mapping default values for fader/automation objects.

## 🔧 Quick Context
- **App Version:** v1.4.2
- **Last commit:** Gemini3.7Flash(v1.4.2) - Category type icons in hover tag and Direct Gain/Mute mode for gain cards
- **Architecture:** Flutter app in `mod_controller/` with modular card-based UI
