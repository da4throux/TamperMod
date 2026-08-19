# TamperMod — Current Focus

## ✅ Completed (v1.3.70)
- **Unconstrained Touch Dragging & Constant Opposite Arm Length**:
  1. Removed clamping on normalization calculations (`toNormalized`), allowing drag touch coordinates to extend continuously beyond the canvas box and drive strength up to 10x.
  2. Fixed handle angle rotation so the opposite handle strictly maintains its exact scalar length ($L$) when rotating, without stretching or shrinking.
  3. Pinned visual handle diamonds safely at the boundary edge while letting arm stroke thickness and curve tension scale freely.

## ✅ Completed (v1.3.69)
- **Extended Tangent Strength Scaling with Dynamic Arm Thickness**:
  1. Allows tangent strength to scale freely ($s_1, s_2 \ge 1.0$ up to $10.0$) when pulling beyond the canvas frame, creating ultra-powerful, sharper vertical S-curve inflections.
  2. Handle diamonds stay neatly pinned to the box boundaries ($Y=0.0, 1.0$), while the tangent arm thickness dynamically scales from 2px up to 8px for tactile visual tension feedback.
  3. Formulated strength-modulated cubic Bézier in `curves.dart` preserving exact tangent slope and pure monotonicity.

## 📋 Remaining Tasks
- **A2. WebView Controls**: WebView full-screen toggle, separation layout adjustment.
- **E2. Default Fadeout Values**: Mapping default values for fader/automation objects.

## 🔧 Quick Context
- **App Version:** v1.3.70
- **Last commit:** Gemini3.7Flash(v1.3.70) - Unconstrained drag coordinate space with preserved opposite arm length
- **Architecture:** Flutter app in `mod_controller/` with modular card-based UI
