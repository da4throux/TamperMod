# TamperMod — Current Focus

## ✅ Completed (v1.3.38)
- **Fix Space-Separated WebSocket `param_set` and `bypass` syntax**: Discovered from live WebSocket captures that Tornado `mod-ui` requires space-separated arguments (`param_set <instance> <port> <value>` and `param_set <instance> :bypass <value>`). Replaced slash-separated formatting in `setParamValue` and `toggleBypass`, restoring full two-way control for SwitchBox routing and all pedal parameters.

## ✅ Completed (v1.3.37)
- **SwitchCard Routing Port & WS Logging**: Updated SwitchCard to toggle the audio routing parameter port (`setParamValue`) instead of solely relying on `:bypass`, added real-time display of the parameter symbol and value on the card, and enabled incoming WebSocket logging (`WS RECV`) to diagnose MOD Dwarf message flow.

## 📋 Remaining Tasks
- **A2. WebView Controls**: WebView full-screen toggle, separation layout adjustment.
- **E2. Default Fadeout Values**: Mapping default values for fader/automation objects.

## 🔧 Quick Context
- **App Version:** v1.3.38
- **Last commit:** Gemini3.7Flash(v1.3.38) - Fix space-separated param_set and bypass WebSocket syntax
- **Architecture:** Flutter app in `mod_controller/` with modular card-based UI
