# TamperMod — Current Focus

## ✅ Completed (v1.3.52)
- **Continuous Cubic Bézier, Top-to-Bottom Fade Out, Undo, & Saved Presets**:
  1. Refactored `VectorBezierCurve` into a single continuous monotonic cubic Bézier with center balance inflection and tangent handles (eliminating kinks and snapping).
  2. Fade Out tab visually renders from top (100%) to bottom (0%), aligning with audio attenuation.
  3. Added `UNDO` history stack to revert curve adjustments safely.
  4. Added user-saved custom preset management (`SAVE PRESET` dialog + dynamic chips) persisted in `SharedPreferences`.
  5. Balanced standard S-curve set as the default `RESET` preset.

## ✅ Completed (v1.3.51)
- **Vectorized Bézier Curve & Dual Fade-In/Out Editing**:
  1. Simplified `VectorBezierEditor` to interactive control targets: Center Point Inflection and 2 Vector Handles.
  2. Implemented independent custom curve parameter state (`customParams` for Fade In and `customParamsOut` for Fade Out).
  3. Added explicit `MIRROR` and `COPY` curve actions allowing Fade Out to mirror or copy Fade In dynamically.

## 📋 Remaining Tasks
- **A2. WebView Controls**: WebView full-screen toggle, separation layout adjustment.
- **E2. Default Fadeout Values**: Mapping default values for fader/automation objects.

## 🔧 Quick Context
- **App Version:** v1.3.52
- **Last commit:** Gemini3.7Flash(v1.3.52) - Continuous cubic Bézier, top-to-bottom Fade Out, Undo, and saved presets
- **Architecture:** Flutter app in `mod_controller/` with modular card-based UI
