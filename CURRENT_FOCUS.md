# TamperMod — Current Focus

## ✅ Completed (v1.4.0)
- **Persistent Global WebView Hover Tag**:
  1. **Maximum Z-Index & Body Attachment**: Set hover tag z-index to `2147483647` (browser max) and attached directly to `document.body || document.documentElement`.
  2. **Window & Document Pointer Binding**: Bound pointer listeners across `window` and `document` on `pointermove`, `mousemove`, `pointerover`, and `mouseover` with 30-level upward DOM traversal for deep SVG/canvas/div recognition.
  3. **Continuous Hover**: Keeps the tag visible without auto-fade while over the pedal visual, and provides an 800ms window on mouse exit to transition smoothly to clicking the tag.

## 📋 Remaining Tasks
- **A2. WebView Controls**: WebView full-screen toggle, separation layout adjustment.
- **E2. Default Fadeout Values**: Mapping default values for fader/automation objects.

## 🔧 Quick Context
- **App Version:** v1.4.0
- **Last commit:** Gemini3.7Flash(v1.4.0) - Max z-index, window-wide capture, and robust pedal hover detection in WebView
- **Architecture:** Flutter app in `mod_controller/` with modular card-based UI
