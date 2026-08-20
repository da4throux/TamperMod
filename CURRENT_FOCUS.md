# TamperMod — Current Focus

## ✅ Completed (v1.4.9)
- **Top-Most Spatial LCD Extraction & Flexible Instance Matching**:
  1. **Top-Most Spatial Sort**:
     - Leaf SVG `<text>` elements inside the pedal visual are sorted by screen `top` coordinate, ensuring the upper LCD screen (`-71.5 dB`) is always selected instead of the lower knob setting (`-5.64 dB`).
  2. **Flexible Instance Matching**:
     - Added `_getMeterDisplayForPedal()` to robustly map sanitized and graph-prefixed instance identifiers between the DOM and WebSocket states.
  3. **Broadened WebSocket Protocol Support**:
     - Added support for `output_set`, `output`, `meter`, and `monitor` commands in `websocket_service.dart`.

## 📋 Remaining Tasks
- **A2. WebView Controls**: WebView full-screen toggle, separation layout adjustment.
- **E2. Default Fadeout Values**: Mapping default values for fader/automation objects.

## 🔧 Quick Context
- **App Version:** v1.4.9
- **Last commit:** Gemini3.7Flash(v1.4.9) - Top-most spatial LCD extraction and flexible instance matching
- **Architecture:** Flutter app in `mod_controller/` with modular card-based UI
