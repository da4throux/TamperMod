# TamperMod — Current Focus

## ✅ Completed (v1.3.65)
- **Full Vertical Tangents (90°) & Independent Handle Lengths**:
  1. Unlocked pure vertical tangent angle ($\theta = \pi/2$) across the center anchor $M$, allowing handles to align directly on the vertical center guide line.
  2. Implemented independent arm lengths ($L_1, L_2$) for incoming and outgoing handles with unlimited strength scaling.
  3. Formulated slope-matched cubic Bézier in `curves.dart` that transitions through vertical inflections with smooth monotonic arrival and departure.

## ✅ Completed (v1.3.64)
- **Preserve Active Puzzle Tile Position on Click/Release in Place**:
  1. Updated `DragTarget.onAccept` on the Active Puzzle Canvas container in `settings_drawer.dart` to check `wasAlreadyActive`.
  2. Tiles clicked, dragged slightly, or released in place retain their exact current index rather than jumping to the end of the board.

## 📋 Remaining Tasks
- **A2. WebView Controls**: WebView full-screen toggle, separation layout adjustment.
- **E2. Default Fadeout Values**: Mapping default values for fader/automation objects.

## 🔧 Quick Context
- **App Version:** v1.3.65
- **Last commit:** Gemini3.7Flash(v1.3.65) - Full 90-degree vertical tangent alignment with independent arm lengths and slope-matched cubic Bézier
- **Architecture:** Flutter app in `mod_controller/` with modular card-based UI
