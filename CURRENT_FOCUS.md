# TamperMod — Current Focus

## ✅ Completed (v1.3.97)
- **Unified Drag Feedback & Continuous Hover Persistence**:
  1. **Regular (R) Tile Feedback from Available Pool**: When dragging a tile out of the available pool, it now displays the exact Regular puzzle tile preview (`width: rWidth, height: 48.0` with neon border and glow) instead of the wide bar, eliminating double-shape overlay artifacts.
  2. **Continuous Hover Persistence**: Fixed hover fadeout behavior—the hover name tag stays permanently visible as long as the cursor remains over the pedal, and only fades out after the cursor leaves the pedal visual.

## 📋 Remaining Tasks
- **A2. WebView Controls**: WebView full-screen toggle, separation layout adjustment.
- **E2. Default Fadeout Values**: Mapping default values for fader/automation objects.

## 🔧 Quick Context
- **App Version:** v1.3.97
- **Last commit:** Gemini3.7Flash(v1.3.97) - Regular tile drag feedback for available pool and continuous hover persistence
- **Architecture:** Flutter app in `mod_controller/` with modular card-based UI
