# TamperMod — Current Focus

## ✅ Completed (v1.3.56)
- **Fixed Center Waypoint Anchor Formulation with Independent Tangent Handles**:
  1. Made center point $M = (mx, my)$ a true fixed waypoint anchor that **never moves when dragging handles $H_1$ or $H_2$**.
  2. Formulated 2-segment cubic Bézier solver passing through $(0,0) \to M \to (1,1)$, ensuring $M$ stays exactly where placed while handles independently shape curvature.
  3. Dragging $M$ directly positions the fixed waypoint anchor.

## ✅ Completed (v1.3.55)
- **Custom Curve UX Polish: Clear Labels, Target Undo Stack, Unlimited Tangent Power, Clean Graph**:
  1. Updated button labels to explicit "TO" format (`COPY TO FADE OUT`, `MIRROR TO FADE OUT`, `COPY TO FADE IN`, `MIRROR TO FADE IN`).
  2. Fixed undo history stack for copy and mirror actions to push snapshots directly to the modified target curve stack.
  3. Hid redundant duplicate bottom graph when `VectorBezierEditor` is active.

## 📋 Remaining Tasks
- **A2. WebView Controls**: WebView full-screen toggle, separation layout adjustment.
- **E2. Default Fadeout Values**: Mapping default values for fader/automation objects.

## 🔧 Quick Context
- **App Version:** v1.3.56
- **Last commit:** Gemini3.7Flash(v1.3.56) - Fixed center waypoint anchor formulation with independent tangent handles
- **Architecture:** Flutter app in `mod_controller/` with modular card-based UI
