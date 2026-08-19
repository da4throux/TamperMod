# TamperMod — Current Focus

## ✅ Completed (v1.3.47)
- **Fix Mono (tinygain#mono) Min/Max Scale to -20 dB .. +20 dB**:
  1. Guaranteed `minGain` = `-20.0 dB` and `maxGain` = `+20.0 dB` for all Mono and tinygain instances, ensuring the slider, labels, and fade ranges map accurately across the entire -20dB to +20dB range.
  2. Fixed Backbone port range parsing in `scrapeMetadata` to read `port.ranges.min` and `port.ranges.max`, preventing fallback to 0..1 defaults.

## ✅ Completed (v1.3.46)
- **Native WebSocket param_set & Bypass Dispatch**:
  1. Replaced REST `HttpClient` calls in `setParamValue` and `toggleBypass` with native MOD Dwarf WebSocket commands (`param_set <instance>/<port> <val>` and `param_set <instance>/:bypass <0|1>`), eliminating HTTP 500 exceptions.
  2. Captured active WebView WebSocket instance in JS injector to route gain adjustments and bypass triggers directly through the browser socket and update Backbone models in real-time.
  3. Fixed SwitchCard power button to toggle `:bypass` across all switch instances.

## 📋 Remaining Tasks
- **A2. WebView Controls**: WebView full-screen toggle, separation layout adjustment.
- **E2. Default Fadeout Values**: Mapping default values for fader/automation objects.

## 🔧 Quick Context
- **App Version:** v1.3.47
- **Last commit:** Gemini3.7Flash(v1.3.47) - Fix Mono min/max dB scale to -20dB..+20dB
- **Architecture:** Flutter app in `mod_controller/` with modular card-based UI
