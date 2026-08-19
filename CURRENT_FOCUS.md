# TamperMod — Current Focus

## ✅ Completed (v1.3.69)
- **Extended Tangent Strength Scaling with Dynamic Arm Thickness**:
  1. Allows tangent strength to scale freely ($s_1, s_2 \ge 1.0$ up to $10.0$) when pulling beyond the canvas frame, creating ultra-powerful, sharper vertical S-curve inflections.
  2. Handle diamonds stay neatly pinned to the box boundaries ($Y=0.0, 1.0$), while the tangent arm thickness dynamically scales from 2px up to 8px for tactile visual tension feedback.
  3. Formulated strength-modulated cubic Bézier in `curves.dart` preserving exact tangent slope and pure monotonicity.

## ✅ Completed (v1.3.68)
- **Stationary Middle Anchor & Hardware Bézier Spline Rendering**:
  1. Decoupled `_mx` and `_my` getters from handle coordinates, keeping the middle point 100% stationary when adjusting handle strength/length.
  2. Replaced step-discretized canvas drawing with native `Path.cubicTo` parametric Bézier rendering, eliminating chord discretization error and ensuring the rendered curve matches vertical handle tangents with sub-pixel perfection.
  3. Optimized `onPanStart` hit-testing prioritizing handles over the center point.

## 📋 Remaining Tasks
- **A2. WebView Controls**: WebView full-screen toggle, separation layout adjustment.
- **E2. Default Fadeout Values**: Mapping default values for fader/automation objects.

## 🔧 Quick Context
- **App Version:** v1.3.69
- **Last commit:** Gemini3.7Flash(v1.3.69) - Extended tangent strength scaling beyond boundary with dynamic arm thickness
- **Architecture:** Flutter app in `mod_controller/` with modular card-based UI
