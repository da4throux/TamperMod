# TamperMod — Current Focus

## ✅ Completed (v1.3.41)
- **Configurable Dual Switch Layouts (2-Path Route & Clean On/Off Toggle)**: Added support for two distinct switch tile layouts:
  1. **2-Path Route Mode**: Dual interactive pills displaying custom labels for Path A (Down/0) and Path B (Up/1) with active highlight.
  2. **Clean On/Off Toggle Mode**: Prominent bold name with elegant status badge (`[ ● ON ]` / `[ ○ OFF ]`) and full card ambient glow, with no oversized toggle icon.
  - Added dedicated **Switch Settings Dialog** (pen button/long-press) to configure Layout Mode, Path A/B names, Active State definition (Normal 1=ON vs Inverted 0=ON), Title, and Glow Color with persistent storage.

## ✅ Completed (v1.3.40)
- **Implement Direct HTTP REST Control Endpoint for Parameters & Bypass**: Switched control dispatches (`setParamValue` and `toggleBypass`) to use the official MOD REST API (`POST /effect/parameter/set/` and `POST /effect/bypass/`) with optimistic UI updates, while keeping the WebSocket stream strictly for high-speed broadcast telemetry. This completely eliminates WebSocket drops and makes tile switching rock-solid.

## 📋 Remaining Tasks
- **A2. WebView Controls**: WebView full-screen toggle, separation layout adjustment.
- **E2. Default Fadeout Values**: Mapping default values for fader/automation objects.

## 🔧 Quick Context
- **App Version:** v1.3.41
- **Last commit:** Gemini3.7Flash(v1.3.41) - Configurable dual switch layouts (2-Path Route and Clean On/Off)
- **Architecture:** Flutter app in `mod_controller/` with modular card-based UI
