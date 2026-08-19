# TamperMod — Current Focus

## ✅ Completed (v1.3.49)
- **Top AppBar View Selectors & Controls Auto-Populate**:
  1. Added View Mode Chips (`TILES | SPLIT | WEB`) directly into the top AppBar for instant 1-click view switching.
  2. Auto-populates active tiles list with all discovered plugins if custom order is empty, preventing black/blank screens.
  3. Added view-mode fallback guards in `_buildBodyContent`.

## ✅ Completed (v1.3.48)
- **Interactive Blender-style Vectorized Bézier Curve Editor**:
  1. Created `VectorBezierEditor` with direct on-screen touch/drag manipulation of curve keypoints, tangent handle vectors, and angles.
  2. Implemented `VectorBezierCurve` with cubic Bézier root solver (Newton-Raphson + binary search fallback) supporting 2-point and multi-point curves with midpoint handles.
  3. Added quick presets (Smooth S, Punchy Attack, Late Swell, Linear, Midpoint Toggle, Reset) and JSON clipboard export.
  4. Fully wired into Gain Card expanded view and fade animation timers.

## 📋 Remaining Tasks
- **A2. WebView Controls**: WebView full-screen toggle, separation layout adjustment.
- **E2. Default Fadeout Values**: Mapping default values for fader/automation objects.

## 🔧 Quick Context
- **App Version:** v1.3.49
- **Last commit:** Gemini3.7Flash(v1.3.49) - View mode chips in AppBar and controls auto-populate
- **Architecture:** Flutter app in `mod_controller/` with modular card-based UI
