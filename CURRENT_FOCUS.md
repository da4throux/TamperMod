# TamperMod — Current Focus

## ✅ Completed (v1.3.71)
- **Extended Vertical Segment Reach for High Tangent Strengths**:
  1. Scaled tangent control point reach ($C_{02}$ and $C_{11}$) directly by strength multipliers ($s_1, s_2$), allowing the vertical rise through center anchor $M$ to stretch across the full vertical canvas height.
  2. The curve maintains pure vertical alignment across a significantly longer vertical segment before bending toward the baselines.

## ✅ Completed (v1.3.70)
- **Unconstrained Touch Dragging & Constant Opposite Arm Length**:
  1. Removed clamping on normalization calculations (`toNormalized`), allowing drag touch coordinates to extend continuously beyond the canvas box and drive strength up to 10x.
  2. Fixed handle angle rotation so the opposite handle strictly maintains its exact scalar length ($L$) when rotating, without stretching or shrinking.
  3. Pinned visual handle diamonds safely at the boundary edge while letting arm stroke thickness and curve tension scale freely.

## 📋 Remaining Tasks
- **A2. WebView Controls**: WebView full-screen toggle, separation layout adjustment.
- **E2. Default Fadeout Values**: Mapping default values for fader/automation objects.

## 🔧 Quick Context
- **App Version:** v1.3.71
- **Last commit:** Gemini3.7Flash(v1.3.71) - Extended vertical reach for high strength tangents
- **Architecture:** Flutter app in `mod_controller/` with modular card-based UI
