# TamperMod — Current Focus

## ✅ Completed (v1.3.61)
- **Fixed Middle Anchor with Collinear Tangent Handles & Near-Vertical S-Curve**:
  1. Anchored middle point $M = (mx, my)$ so dragging tangent handles $H_1$ or $H_2$ **never moves $M$**.
  2. Symmetrical collinear tangent linkage: dragging $H_1$ adjusts $H_2$ collinearly through $M$ (and vice versa) to guarantee seamless $C^1$ smooth transitions.
  3. Unlocked near-vertical steepness across $M$ (slope up to vertical $\infty$) for punchy and sharp S-curves with zero angle kinks.

## ✅ Completed (v1.3.60)
- **Live Puzzle Drag Reordering & Zero-Height Row Line Breaks**:
  1. Live interactive tile reordering in Puzzle Canvas (`onMove` in `DragTarget`), dynamically rearranging the entire Wrap layout in real-time as the finger glides across the screen.
  2. Added zero-height `LINE BREAK` separator (`+ LINE BREAK`), forcing cards after it onto a new line with zero vertical footprint on the dashboard.

## 📋 Remaining Tasks
- **A2. WebView Controls**: WebView full-screen toggle, separation layout adjustment.
- **E2. Default Fadeout Values**: Mapping default values for fader/automation objects.

## 🔧 Quick Context
- **App Version:** v1.3.61
- **Last commit:** Gemini3.7Flash(v1.3.61) - Fixed middle anchor with collinear tangent handles supporting near-vertical S-curve
- **Architecture:** Flutter app in `mod_controller/` with modular card-based UI
