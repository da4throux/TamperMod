# TamperMod — Current Focus

## ✅ Completed (v1.3.28)
- **Chromebook (ARC/Hatch) Android Deployment & Bridge**: Documented ChromeOS Android container deployment and created `scripts/bridge_dwarf.sh` to forward USB-Ethernet `192.168.51.1:80` traffic to the Crostini bridge (`100.115.92.201:80`).
- **Development Toolchain Validation**: Installed Linux host dependencies for Flutter build system while maintaining Android as the target platform.

## ✅ Completed (v1.3.27)
- **Advanced Discovery Robustness**: Fixed Backbone/DOM metadata scraping to extract name and label and defensively support plain objects, and updated updatePluginMetadata to automatically rename cards.
- **WebSocket param_set Support**: Added support for both space-separated and slash-separated parameter commands.
- **Optimistic State Sliders**: Made generic sliders smoothly movable by updating local state optimistically.
- **Compact Card Customization**: Added Compact Card checklist selector in Expanded view and scrollable list of selected parameters inside the Compact Card.

## 📋 Remaining Tasks
- **A2. WebView Controls**: WebView full-screen toggle, separation layout adjustment.
- **E2. Default Fadeout Values**: Mapping default values for fader/automation objects.

## 🔧 Quick Context
- **App Version:** v1.3.28
- **Last commit:** Gemini3.7Flash(v1.3.28) - Document ChromeOS ARC bridge and add bridge_dwarf script
- **Architecture:** Flutter app in `mod_controller/` with modular card-based UI
