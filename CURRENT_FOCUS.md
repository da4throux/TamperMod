# TamperMod — Current Focus

## ✅ Completed (v1.3.94)
- **Eliminate MouseTracker Assertion Crash & Unfreeze Gestures**:
  1. **Root Cause**: `DragTarget.onMove` was executing synchronous `setState()` calls during Flutter's pointer movement and mouse-tracking device update phase, throwing `Failed assertion: '!_debugDuringDeviceUpdate'`, which crashed Flutter's gesture pipeline and blocked all subsequent clicks and taps until app restart.
  2. **Resolution**: Removed synchronous `onMove` mutations from `DragTarget`. Drag reordering is now handled cleanly on `onAccept`, preventing any race conditions with `MouseTracker`.
  3. **Robust Gesture Pipeline**: Tile sizing, category/speaker icon identification taps, and long-press dragging now function continuously without freezing.

## 📋 Remaining Tasks
- **A2. WebView Controls**: WebView full-screen toggle, separation layout adjustment.
- **E2. Default Fadeout Values**: Mapping default values for fader/automation objects.

## 🔧 Quick Context
- **App Version:** v1.3.94
- **Last commit:** Gemini3.7Flash(v1.3.94) - Fix MouseTracker assertion crash by removing unsafe DragTarget onMove mutations
- **Architecture:** Flutter app in `mod_controller/` with modular card-based UI
