# TamperMod — Current Focus

## ✅ Completed (v1.3.55)
- **Custom Curve UX Polish: Clear Labels, Target Undo Stack, Unlimited Tangent Power, Clean Graph**:
  1. Updated button labels to explicit "TO" format (`COPY TO FADE OUT`, `MIRROR TO FADE OUT`, `COPY TO FADE IN`, `MIRROR TO FADE IN`).
  2. Fixed undo history stack for copy and mirror actions to push snapshots directly to the modified target curve stack.
  3. Removed artificial handle X cross-clamping, unlocking full tangent power so horizontal handles can produce intense, near-vertical S-curve drops.
  4. Hid redundant duplicate bottom graph when `VectorBezierEditor` is active.

## ✅ Completed (v1.3.54)
- **Unify SwitchCard Full-Card Tap & Eliminate WebView Duplicate Invocations**:
  1. Unified `SwitchCard` gestures into a single root `GestureDetector(behavior: HitTestBehavior.opaque)` — tapping anywhere on the card (background, Path A box, Path B box, or toggle pill) reliably toggles between Path A/B or On/Off.
  2. Removed inner conflicting gesture detectors from child button widgets to prevent arena contention.

## 📋 Remaining Tasks
- **A2. WebView Controls**: WebView full-screen toggle, separation layout adjustment.
- **E2. Default Fadeout Values**: Mapping default values for fader/automation objects.

## 🔧 Quick Context
- **App Version:** v1.3.55
- **Last commit:** Gemini3.7Flash(v1.3.55) - Custom curve UX polish: clear labels, target undo stack, unlimited tangent power, remove duplicate bottom graph
- **Architecture:** Flutter app in `mod_controller/` with modular card-based UI
