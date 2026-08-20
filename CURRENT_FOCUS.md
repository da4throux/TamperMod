# TamperMod — Current Focus

## ✅ Completed (v1.4.4)
- **Live Gain Synchronization & Persistent Gain Readout when Muted**:
  1. **Gain Always Visible When Muted**:
     - The giant Mute button always displays the actual gain dB level (e.g. `+0.0 dB`, `-37.1 dB`) alongside the high-visibility `MUTED` status badge and `MUTED • TAP TO RESTORE` subtitle.
  2. **Live WebSocket Parameter Sync**:
     - Synchronized `currentValue` directly from live pedal parameters in WebSocket (`pedal.parameters[pedal.gainPortSymbol]`), ensuring the card and the hardware LCD/display on the pedalboard match accurately in real time.

## 📋 Remaining Tasks
- **A2. WebView Controls**: WebView full-screen toggle, separation layout adjustment.
- **E2. Default Fadeout Values**: Mapping default values for fader/automation objects.

## 🔧 Quick Context
- **App Version:** v1.4.4
- **Last commit:** Gemini3.7Flash(v1.4.4) - Live gain sync with pedalboard and persistent gain readout when muted
- **Architecture:** Flutter app in `mod_controller/` with modular card-based UI
