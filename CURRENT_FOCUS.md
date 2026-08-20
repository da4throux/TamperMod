# TamperMod — Current Focus

## ✅ Completed (v1.3.96)
- **Live Fluid Drag Shifting in Available Pool**:
  1. **Available Pool Tiles Live DragTarget**: Wrapped inactive pool tiles in `DragTarget<String>` with safe `addPostFrameCallback` live shifting, allowing smooth re-ordering within the pool and instant live placement when dragging active pedals down into the pool.
  2. **Empty Area Pool Drop Support**: Wrapped the available pool container itself in a `DragTarget<String>` to cleanly deactivate pedals dropped onto whitespace.

## 📋 Remaining Tasks
- **A2. WebView Controls**: WebView full-screen toggle, separation layout adjustment.
- **E2. Default Fadeout Values**: Mapping default values for fader/automation objects.

## 🔧 Quick Context
- **App Version:** v1.3.96
- **Last commit:** Gemini3.7Flash(v1.3.96) - Enable live fluid drag shifting and drop targets for available pool tiles
- **Architecture:** Flutter app in `mod_controller/` with modular card-based UI
