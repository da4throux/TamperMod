# TamperMod — Current Focus

## ✅ Completed (v1.4.1)
- **Natural Stack Sizing & MAX-MID-MIN Pill Bar**:
  1. **MAX Mode Dynamic Stack Height**: In `MAX`, the available pool takes the exact natural stack height needed for its items (without creating an empty bottom void or compressing the active puzzle canvas).
  2. **MID Mode Half-Stack**: In `MID`, the pool displays half the stack height with smooth scrolling for the rest.
  3. **MIN Mode Completely Folded**: In `MIN`, the pool collapses completely to 0px, granting 100% of drawer space to the active canvas.
  4. **Pill Order**: Re-ordered the 3-way toggle pills to **[ MAX | MID | MIN ]** with MIN on the right side.

## 📋 Remaining Tasks
- **A2. WebView Controls**: WebView full-screen toggle, separation layout adjustment.
- **E2. Default Fadeout Values**: Mapping default values for fader/automation objects.

## 🔧 Quick Context
- **App Version:** v1.4.1
- **Last commit:** Gemini3.7Flash(v1.4.1) - Natural stack sizing for MAX/MID and MAX-MID-MIN pill bar layout
- **Architecture:** Flutter app in `mod_controller/` with modular card-based UI
