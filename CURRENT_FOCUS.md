# TamperMod — Current Focus

## ✅ Completed (v1.3.53)
- **Fix SwitchBox Toggle State Race & Lock Bézier Midpoint Dot to Curve**:
  1. Resolved gesture arena and state race in `SwitchCard` by separating tap targets and adding optimistic local parameter state updates with immediate `setState`.
  2. Locked center point dot $M$ mathematically to the exact cubic Bézier midpoint $(X(0.5), Y(0.5))$, guaranteeing it never detaches from the curve.
  3. Formulated midpoint drag delta transformation to smoothly shift tangent handles while keeping $M$ locked to the user's touch.

## ✅ Completed (v1.3.52)
- **Continuous Cubic Bézier, Top-to-Bottom Fade Out, Undo, & Saved Presets**:
  1. Refactored `VectorBezierCurve` into a single continuous monotonic cubic Bézier with center balance inflection and tangent handles (eliminating kinks and snapping).
  2. Fade Out tab visually renders from top (100%) to bottom (0%), aligning with audio attenuation.
  3. Added `UNDO` history stack to revert curve adjustments safely.
  4. Added user-saved custom preset management (`SAVE PRESET` dialog + dynamic chips) persisted in `SharedPreferences`.

## 📋 Remaining Tasks
- **A2. WebView Controls**: WebView full-screen toggle, separation layout adjustment.
- **E2. Default Fadeout Values**: Mapping default values for fader/automation objects.

## 🔧 Quick Context
- **App Version:** v1.3.53
- **Last commit:** Gemini3.7Flash(v1.3.53) - Fix switchbox toggle state race and lock Bézier midpoint dot to spline
- **Architecture:** Flutter app in `mod_controller/` with modular card-based UI
