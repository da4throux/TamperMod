# TamperMod — Current Focus

## ✅ Completed (v1.3.39)
- **WebView Traffic Inspector & Dual Control Bridge**: Injected traffic interceptors into WebView to log all console messages (`setOnConsoleMessage`), inspect web GUI traffic, and added `tamperSetParam` / `tamperSetBypass` Backbone and DOM helpers to guarantee pedalboard interaction from tiles.

## ✅ Completed (v1.3.38)
- **Fix Space-Separated WebSocket `param_set` and `bypass` syntax**: Discovered from live WebSocket captures that Tornado `mod-ui` requires space-separated arguments (`param_set <instance> <port> <value>` and `param_set <instance> :bypass <value>`). Replaced slash-separated formatting in `setParamValue` and `toggleBypass`, restoring full two-way control for SwitchBox routing and all pedal parameters.

## 📋 Remaining Tasks
- **A2. WebView Controls**: WebView full-screen toggle, separation layout adjustment.
- **E2. Default Fadeout Values**: Mapping default values for fader/automation objects.

## 🔧 Quick Context
- **App Version:** v1.3.39
- **Last commit:** Gemini3.7Flash(v1.3.39) - WebView Traffic Inspector and Dual Control Bridge
- **Architecture:** Flutter app in `mod_controller/` with modular card-based UI
