# TamperMod — Current Focus

## ✅ Completed (v1.3.45)
- **Fix SwitchBox Power Button & TinyGain Range Mapping**:
  1. Clean integer formatting (`0` / `1`) for toggle & bypass parameters in HTTP REST calls, resolving Tornado HTTP 500 exceptions.
  2. For SwitchBox plugins without a separate `:bypass` port, wired the top-right power button to toggle the primary routing `Switch` parameter (matching the MOD Dwarf GUI behavior).
  3. Corrected `minGain` / `maxGain` range mapping for `tinygain#mono` (-20dB to +20dB) and prioritized discovered metadata.

## ✅ Completed (v1.3.44)
- **Pedalboard Bypass Endpoint & Gain Slider Sync Fix**:
  1. Corrected `toggleBypass` REST payload to use the official `/effect/parameter/set/` endpoint with `:bypass` port symbol.
  2. Linked `tamperSetParam` and `tamperSetBypass` dual bridge to `GainCard` and `PlaceholderCard` so visual knobs and bypass indicators in the embedded WebView update instantly when tiles are adjusted.

## 📋 Remaining Tasks
- **A2. WebView Controls**: WebView full-screen toggle, separation layout adjustment.
- **E2. Default Fadeout Values**: Mapping default values for fader/automation objects.

## 🔧 Quick Context
- **App Version:** v1.3.45
- **Last commit:** Gemini3.7Flash(v1.3.45) - Fix SwitchBox toggle behavior and tinygain range
- **Architecture:** Flutter app in `mod_controller/` with modular card-based UI
