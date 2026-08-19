# TamperMod — Current Focus

## ✅ Completed (v1.3.48)
- **Interactive Blender-style Vectorized Bézier Curve Editor**:
  1. Created `VectorBezierEditor` with direct on-screen touch/drag manipulation of curve keypoints, tangent handle vectors, and angles.
  2. Implemented `VectorBezierCurve` with cubic Bézier root solver (Newton-Raphson + binary search fallback) supporting 2-point and multi-point curves with midpoint handles.
  3. Added quick presets (Smooth S, Punchy Attack, Late Swell, Linear, Midpoint Toggle, Reset) and JSON clipboard export.
  4. Fully wired into Gain Card expanded view and fade animation timers.

## ✅ Completed (v1.3.47)
- **Fix Mono (tinygain#mono) Min/Max Scale to -20 dB .. +20 dB**:
  1. Guaranteed `minGain` = `-20.0 dB` and `maxGain` = `+20.0 dB` for all Mono and tinygain instances.
  2. Fixed Backbone port range parsing in `scrapeMetadata`.

## 📋 Remaining Tasks
- **A2. WebView Controls**: WebView full-screen toggle, separation layout adjustment.
- **E2. Default Fadeout Values**: Mapping default values for fader/automation objects.

## 🔧 Quick Context
- **App Version:** v1.3.48
- **Last commit:** Gemini3.7Flash(v1.3.48) - Vectorized Bezier curve editor
- **Architecture:** Flutter app in `mod_controller/` with modular card-based UI
