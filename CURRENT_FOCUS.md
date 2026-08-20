# TamperMod — Current Focus

## ✅ Completed (v1.5.0)
- **Fade View VU & Gain Readout and Range Display on Fade Buttons**:
  1. **Sub-Slider VU & Gain Readout Row**:
     - Added a dedicated row below the slider in Fade View showing:
       - **`VU: -71.5 dB`** (neon cyan `#00FFCC` pill)
       - **`GAIN: -5.6 dB`** (glowing accent pill)
       - Range endpoints (`MIN dB` and `MAX dB`) on the outer flanks.
  2. **Fade In & Fade Out Range Display on Buttons**:
     - **FADE IN** button displays live start → end dB values (e.g. `-20.0 → +0.0 dB`).
     - **FADE OUT** button displays live end → start dB values (e.g. `+0.0 → -20.0 dB`).

## 📋 Remaining Tasks
- **A2. WebView Controls**: WebView full-screen toggle, separation layout adjustment.
- **E2. Default Fadeout Values**: Mapping default values for fader/automation objects.

## 🔧 Quick Context
- **App Version:** v1.5.0
- **Last commit:** Gemini3.7Flash(v1.5.0) - Fade view VU & Gain readout with start/end range on Fade buttons
- **Architecture:** Flutter app in `mod_controller/` with modular card-based UI
