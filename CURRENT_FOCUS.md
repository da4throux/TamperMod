# TamperMod — Current Focus

## ✅ Completed (v1.3.99)
- **Safe Post-Frame Highlight & Expansion Timers**:
  1. **Safe Inactive Pool Expansion on Highlight**: Deferral of drawer pool expansion state mutations to `WidgetsBinding.instance.addPostFrameCallback` inside `_scrollToHighlightedTile`, preventing rebuild collisions during Flutter layout and mouse pointer event dispatch.
  2. **Safe Strobe Pulse & JavaScript Message Dispatch**: Wrapped the 250ms breathing strobe periodic timer and `PedalClickChannel` message callback in `addPostFrameCallback`, guaranteeing `MouseTracker` never throws assertion failures during pointer movement and gesture events.

## 📋 Remaining Tasks
- **A2. WebView Controls**: WebView full-screen toggle, separation layout adjustment.
- **E2. Default Fadeout Values**: Mapping default values for fader/automation objects.

## 🔧 Quick Context
- **App Version:** v1.3.99
- **Last commit:** Gemini3.7Flash(v1.3.99) - Safe post-frame highlight strobe and pool expansion handling
- **Architecture:** Flutter app in `mod_controller/` with modular card-based UI
