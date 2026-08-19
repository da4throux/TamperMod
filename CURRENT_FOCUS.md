# TamperMod — Current Focus

## ✅ Completed (v1.3.68)
- **Stationary Middle Anchor & Hardware Bézier Spline Rendering**:
  1. Decoupled `_mx` and `_my` getters from handle coordinates, keeping the middle point 100% stationary when adjusting handle strength/length.
  2. Replaced step-discretized canvas drawing with native `Path.cubicTo` parametric Bézier rendering, eliminating chord discretization error and ensuring the rendered curve matches vertical handle tangents with sub-pixel perfection.
  3. Optimized `onPanStart` hit-testing prioritizing handles over the center point.

## ✅ Completed (v1.3.67)
- **100% Exact Curve Alignment Along Handle Tangent**:
  1. Bound handles $H_1$ and $H_2$ directly as the active cubic Bézier control points $C_{02}$ and $C_{11}$.
  2. The curve passing through center anchor $M$ is mathematically and visually 100% tangent to the line formed by the Cyan and Neon Gold handles.
  3. Maintained strict monotonic smoothness and boundary stability.

## 📋 Remaining Tasks
- **A2. WebView Controls**: WebView full-screen toggle, separation layout adjustment.
- **E2. Default Fadeout Values**: Mapping default values for fader/automation objects.

## 🔧 Quick Context
- **App Version:** v1.3.68
- **Last commit:** Gemini3.7Flash(v1.3.68) - Stationary middle anchor and exact parametric Bézier spline rendering
- **Architecture:** Flutter app in `mod_controller/` with modular card-based UI
