# TamperMod — Current Focus

## ✅ Completed (v1.3.84)
- **Pedal Search Mode (WebView Click-to-Focus & Multi-View Synchronized Blinking)**:
  1. **Floating Toggle Switch Below MOD Logo**: Added a sleek glassmorphic pill switch `[ 🔍 PEDAL SEARCH ]` floating at `top: 48, left: 10` on the WebView pedalboard view, right beneath the MOD logo.
  2. **DOM Click Interception**: Injected a capture-phase JavaScript event listener into the WebView DOM that sends clicked pedal `instanceId`s over `PedalClickChannel`.
  3. **Synchronized Multi-View Blinking & Auto-Scroll**:
     - Webboard: Blinks the physical pedal with a bright neon highlight for 2 seconds.
     - Dashboard Card: Smoothly scrolls the target card to the top (`Scrollable.ensureVisible`) and triggers a glowing white/neon animated halo.
     - Puzzle Board: Auto-scrolls the active puzzle canvas to the tile and pulses its glowing border in sync.

## ✅ Completed (v1.3.83)
- **Reliable Puzzle Board Tile-to-Card Scroll Navigation**:
  1. Replaced broken row-index math calculation in `_scrollToCard` with Flutter's native `Scrollable.ensureVisible` using a dynamic `GlobalKey` registry (`_cardKeys`).
  2. Reliably scrolls the dashboard cards list to bring any clicked tile into view, cleanly handling line breaks, spacers, compact/regular/expanded cards, and dynamic-height cards.

## 📋 Remaining Tasks
- **A2. WebView Controls**: WebView full-screen toggle, separation layout adjustment.
- **E2. Default Fadeout Values**: Mapping default values for fader/automation objects.

## 🔧 Quick Context
- **App Version:** v1.3.84
- **Last commit:** Gemini3.7Flash(v1.3.84) - Pedal Search mode with floating switch below MOD logo and multi-view blinking
- **Architecture:** Flutter app in `mod_controller/` with modular card-based UI
