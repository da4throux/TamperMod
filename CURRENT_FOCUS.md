# TamperMod — Current Focus

## ✅ Completed (v1.3.46)
- **Native WebSocket param_set & Bypass Dispatch**:
  1. Replaced REST `HttpClient` calls in `setParamValue` and `toggleBypass` with native MOD Dwarf WebSocket commands (`param_set <instance>/<port> <val>` and `param_set <instance>/:bypass <0|1>`), eliminating HTTP 500 exceptions.
  2. Captured active WebView WebSocket instance in JS injector to route gain adjustments and bypass triggers directly through the browser socket and update Backbone models in real-time.
  3. Fixed SwitchCard power button to toggle `:bypass` across all switch instances.

## ✅ Completed (v1.3.45)
- **Fix SwitchBox Power Button & TinyGain Range Mapping**:
  1. Clean integer formatting (`0` / `1`) for toggle & bypass parameters.
  2. Corrected `minGain` / `maxGain` range mapping for `tinygain#mono` (-20dB to +20dB).

## 📋 Remaining Tasks
- **A2. WebView Controls**: WebView full-screen toggle, separation layout adjustment.
- **E2. Default Fadeout Values**: Mapping default values for fader/automation objects.

## 🔧 Quick Context
- **App Version:** v1.3.46
- **Last commit:** Gemini3.7Flash(v1.3.46) - Native WebSocket param_set and bypass dispatch
- **Architecture:** Flutter app in `mod_controller/` with modular card-based UI
