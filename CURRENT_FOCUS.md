# TamperMod — Current Focus

## ✅ Completed (v1.3.44)
- **Pedalboard Bypass Endpoint & Gain Slider Sync Fix**:
  1. Corrected `toggleBypass` REST payload to use the official `/effect/parameter/set/` endpoint with `:bypass` port symbol (e.g. `POST /effect/parameter/set/ /graph/SwitchBox2_3/:bypass/1.0`), eliminating HTTP 405 errors and reliably toggling plugin power state.
  2. Linked `tamperSetParam` and `tamperSetBypass` dual bridge to `GainCard` and `PlaceholderCard` so visual knobs and bypass indicators in the embedded WebView update instantly when tiles are adjusted.

## ✅ Completed (v1.3.43)
- **Switch Card Power Button & High-Contrast Button Boxes**: 
  1. Added dedicated Power ON/OFF (Bypass) toggle button to the top-right header of Switch cards, consistent with all other device cards.
  2. Encapsulated switch controls and titles into independent solid "button boxes" (`#162030` dark / `#FFFFFF` light) to ensure crystal-clear text contrast and typography readability regardless of ambient neon card background brightness.

## 📋 Remaining Tasks
- **A2. WebView Controls**: WebView full-screen toggle, separation layout adjustment.
- **E2. Default Fadeout Values**: Mapping default values for fader/automation objects.

## 🔧 Quick Context
- **App Version:** v1.3.44
- **Last commit:** Gemini3.7Flash(v1.3.44) - Fix bypass endpoint and dual bridge for gain sliders
- **Architecture:** Flutter app in `mod_controller/` with modular card-based UI
