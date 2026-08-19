# TamperMod — Current Focus

## ✅ Completed (v1.3.35)
- **Inline Puzzle Organizer Panel**: Replaced overlay `endDrawer` (with scrim/blur) with an `AnimatedContainer` inline panel that slides in from the right. The panel pushes/narrows the tile board without overlaying or reloading the WebView. No blur, no scrim — the controls area shrinks while the web interface stays untouched.

## ✅ Completed (v1.3.34)
- **Simultaneous Dual-Row Toolbars Folding**: Unified folding so that tapping the top bar cable toggle (or title/status chip) folds BOTH the toolbar (layout views, radar, reload, theme, version) and the connection setup panel simultaneously in a smooth animation, maximizing vertical canvas area.

## 📋 Remaining Tasks
- **A2. WebView Controls**: WebView full-screen toggle, separation layout adjustment.
- **E2. Default Fadeout Values**: Mapping default values for fader/automation objects.

## 🔧 Quick Context
- **App Version:** v1.3.35
- **Last commit:** ClaudeSonnet4.6(v1.3.35) - Replace overlay drawer with inline push panel
- **Architecture:** Flutter app in `mod_controller/` with modular card-based UI
