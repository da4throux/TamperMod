# TamperMod — Current Focus

## ✅ Completed (v1.3.37)
- **SwitchCard Routing Port & WS Logging**: Updated SwitchCard to toggle the audio routing parameter port (`setParamValue`) instead of solely relying on `:bypass`, added real-time display of the parameter symbol and value on the card, and enabled incoming WebSocket logging (`WS RECV`) to diagnose MOD Dwarf message flow.

## ✅ Completed (v1.3.36)
- **SwitchCard Full-Tile Tap & Panel Layout Fix**: Made SwitchCard full-card tappable as a large ON/OFF switch button and fixed right-side panel animation glitch using `AnimatedAlign`.

## 📋 Remaining Tasks
- **A2. WebView Controls**: WebView full-screen toggle, separation layout adjustment.
- **E2. Default Fadeout Values**: Mapping default values for fader/automation objects.

## 🔧 Quick Context
- **App Version:** v1.3.37
- **Last commit:** Gemini3.7Flash(v1.3.37) - SwitchCard routing port toggle and WS RECV logging
- **Architecture:** Flutter app in `mod_controller/` with modular card-based UI
