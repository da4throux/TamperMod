# TamperMod — Current Focus

## ✅ Completed (v1.3.95)
- **Live Instant Drag Reordering & Robust Hover Tag Detection**:
  1. **Live Instant Positioning During Drag**: Re-enabled instant live shifting of tiles as you drag over them in the tile board. Handled safely via `WidgetsBinding.instance.addPostFrameCallback` so that the live preview is butter-smooth and never causes `MouseTracker` assertion crashes.
  2. **Pedalboard Hover Tag Robustness**: Registered comprehensive window and document pointer listeners (`pointermove`, `mousemove`, `pointerover`, `mouseover`), ensured tag re-attachment on every theme/glow update, and broadened DOM element detection up to 20 parent layers to reliably detect all SVG, canvas, and nested pedal components.

## 📋 Remaining Tasks
- **A2. WebView Controls**: WebView full-screen toggle, separation layout adjustment.
- **E2. Default Fadeout Values**: Mapping default values for fader/automation objects.

## 🔧 Quick Context
- **App Version:** v1.3.95
- **Last commit:** Gemini3.7Flash(v1.3.95) - Safe post-frame live drag reordering and robust pedalboard hover detection
- **Architecture:** Flutter app in `mod_controller/` with modular card-based UI
