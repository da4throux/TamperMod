# TamperMod — Current Focus

## ✅ Completed (v1.3.93)
- **Tile Board Interaction & Gesture Fixes**:
  1. **Speaker / Category Icon Tapping**: Tapping the category/speaker icon on any active puzzle tile instantly triggers pedal location (5-second blinking strobe on physical pedal + auto-scrolling to the card). Tapping it on an inactive pool tile blinks the physical pedal in the webboard.
  2. **Size Badge `[C]` / `[R]` / `[E]` & Tile Tap to Cycle Size**: Clicking the size badge (or tapping anywhere on the active tile body) reliably cycles the tile size (`compact` -> `regular` -> `expanded`).
  3. **Smooth Long-Press Dragging**: Removed conflicting double-tap gesture recognizers on the tile wrapper and added `HitTestBehavior.opaque` across interactive tile buttons so long-press re-organizing responds instantly and cleanly.

## 📋 Remaining Tasks
- **A2. WebView Controls**: WebView full-screen toggle, separation layout adjustment.
- **E2. Default Fadeout Values**: Mapping default values for fader/automation objects.

## 🔧 Quick Context
- **App Version:** v1.3.93
- **Last commit:** Gemini3.7Flash(v1.3.93) - Speaker icon location tap, size badge cycling, and smooth long-press dragging in tile board
- **Architecture:** Flutter app in `mod_controller/` with modular card-based UI
