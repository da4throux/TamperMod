# TamperMod — Current Focus

## ✅ Completed (v1.3.40)
- **Implement Direct HTTP REST Control Endpoint for Parameters & Bypass**: Switched control dispatches (`setParamValue` and `toggleBypass`) to use the official MOD REST API (`POST /effect/parameter/set/` and `POST /effect/bypass/`) with optimistic UI updates, while keeping the WebSocket stream strictly for high-speed broadcast telemetry. This completely eliminates WebSocket drops and makes tile switching rock-solid.

## ✅ Completed (v1.3.39)
- **WebView Traffic Inspector & Dual Control Bridge**: Injected traffic interceptors into WebView to log all console messages (`setOnConsoleMessage`), inspect web GUI traffic, and added `tamperSetParam` / `tamperSetBypass` Backbone and DOM helpers to guarantee pedalboard interaction from tiles.

## 📋 Remaining Tasks
- **A2. WebView Controls**: WebView full-screen toggle, separation layout adjustment.
- **E2. Default Fadeout Values**: Mapping default values for fader/automation objects.

## 🔧 Quick Context
- **App Version:** v1.3.40
- **Last commit:** Gemini3.7Flash(v1.3.40) - Direct HTTP REST control endpoints for parameter setting and bypass
- **Architecture:** Flutter app in `mod_controller/` with modular card-based UI
