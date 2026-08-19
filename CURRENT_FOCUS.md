# TamperMod — Current Focus

## ✅ Completed (v1.3.51)
- **Vectorized Bézier Curve & Dual Fade-In/Out Editing**:
  1. Simplified `VectorBezierEditor` to 3 interactive control targets: Center Point Inflection (`mx, my`) and 2 Vector Handles (`h1x, h1y` at start, `h2x, h2y` at end).
  2. Implemented independent custom curve parameter state (`customParams` for Fade In and `customParamsOut` for Fade Out).
  3. Added explicit `MIRROR` and `COPY` curve actions allowing Fade Out to mirror or copy Fade In dynamically.
  4. Fixed widget test mock & layout overflow issues in settings drawer section headers.

## ✅ Completed (v1.3.50)
- **Fix Unbounded Layout Crash in GainCard Expanded View**:
  1. Removed `Spacer()` inside `GainCard._buildExpandedView` which caused a fatal Flutter RenderFlex exception when `cardHeight = null` in Expanded card size.
  2. Hardened `VectorBezierCurve` mathematical solver against NaN propagation and infinite loops.

## 📋 Remaining Tasks
- **A2. WebView Controls**: WebView full-screen toggle, separation layout adjustment.
- **E2. Default Fadeout Values**: Mapping default values for fader/automation objects.

## 🔧 Quick Context
- **App Version:** v1.3.51
- **Last commit:** Gemini3.6Flash(v1.3.51) - Vectorized Bezier curve editor 3-point simplification and dual fade in/out mirror copy support
- **Architecture:** Flutter app in `mod_controller/` with modular card-based UI
