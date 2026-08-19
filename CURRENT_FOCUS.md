# TamperMod — Current Focus

## ✅ Completed (v1.3.54)
- **Unify SwitchCard Full-Card Tap & Eliminate WebView Duplicate Invocations**:
  1. Unified `SwitchCard` gestures into a single root `GestureDetector(behavior: HitTestBehavior.opaque)` — tapping anywhere on the card (background, Path A box, Path B box, or toggle pill) reliably toggles between Path A/B or On/Off.
  2. Removed inner conflicting gesture detectors from child button widgets to prevent arena contention.
  3. Cleaned up `window.tamperSetParam` and `window.tamperSetBypass` JavaScript helpers in `dashboard_screen.dart`, eliminating duplicate WebView WebSocket payloads and `el.click()` DOM events that were causing reverse/double toggling.

## ✅ Completed (v1.3.53)
- **Fix SwitchBox Toggle State Race & Lock Bézier Midpoint Dot to Curve**:
  1. Resolved gesture arena and state race in `SwitchCard` by separating tap targets and adding optimistic local parameter state updates with immediate `setState`.
  2. Locked center point dot $M$ mathematically to the exact cubic Bézier midpoint $(X(0.5), Y(0.5))$, guaranteeing it never detaches from the curve.

## 📋 Remaining Tasks
- **A2. WebView Controls**: WebView full-screen toggle, separation layout adjustment.
- **E2. Default Fadeout Values**: Mapping default values for fader/automation objects.

## 🔧 Quick Context
- **App Version:** v1.3.54
- **Last commit:** Gemini3.7Flash(v1.3.54) - Unify SwitchCard full-card tap toggle and remove duplicate WebView click/WS sends
- **Architecture:** Flutter app in `mod_controller/` with modular card-based UI
