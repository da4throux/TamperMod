# TamperMod — Current Focus

## ✅ Completed (v1.3.72)
- **Strictly Monotonic [0, 1] Bounds for High-Strength Verticals**:
  1. Bound control points $C_{02}$ and $C_{11}$ strictly within the unit interval $[0.0, 1.0]$ using asymptotic scaling towards the baseline and ceiling.
  2. Eliminates overshoots above 100% and dips below 0%, ensuring the curve monotonically increases and tends cleanly toward 100% at the top right.

## ✅ Completed (v1.3.71)
- **Extended Vertical Segment Reach for High Tangent Strengths**:
  1. Scaled tangent control point reach ($C_{02}$ and $C_{11}$) directly by strength multipliers ($s_1, s_2$), allowing the vertical rise through center anchor $M$ to stretch across the full vertical canvas height.
  2. The curve maintains pure vertical alignment across a significantly longer vertical segment before bending toward the baselines.

## 📋 Remaining Tasks
- **A2. WebView Controls**: WebView full-screen toggle, separation layout adjustment.
- **E2. Default Fadeout Values**: Mapping default values for fader/automation objects.

## 🔧 Quick Context
- **App Version:** v1.3.72
- **Last commit:** Gemini3.7Flash(v1.3.72) - Enforce strict monotonic [0, 1] bounds preventing overshoots during high strength vertical tangents
- **Architecture:** Flutter app in `mod_controller/` with modular card-based UI
