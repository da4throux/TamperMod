# TamperMod — Current Focus

## ✅ Completed (v1.3.43)
- **Switch Card Power Button & High-Contrast Button Boxes**: 
  1. Added dedicated Power ON/OFF (Bypass) toggle button to the top-right header of Switch cards, consistent with all other device cards.
  2. Encapsulated switch controls and titles into independent solid "button boxes" (`#162030` dark / `#FFFFFF` light) to ensure crystal-clear text contrast and typography readability regardless of ambient neon card background brightness.

## ✅ Completed (v1.3.42)
- **Immediate Dashboard Re-rendering on Puzzle Organizer Reorder**: Added missing `setState` call to `onLayoutSettingsChanged` in `DashboardScreen`, ensuring the main canvas immediately updates and reflects drag-and-drop reordering from the Puzzle Organizer panel in real-time.

## 📋 Remaining Tasks
- **A2. WebView Controls**: WebView full-screen toggle, separation layout adjustment.
- **E2. Default Fadeout Values**: Mapping default values for fader/automation objects.

## 🔧 Quick Context
- **App Version:** v1.3.43
- **Last commit:** Gemini3.7Flash(v1.3.43) - Switch card power button and high-contrast button boxes
- **Architecture:** Flutter app in `mod_controller/` with modular card-based UI
