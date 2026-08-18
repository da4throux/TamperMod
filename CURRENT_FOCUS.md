# TamperMod — Current Focus

## ✅ Completed (v1.3.29)
- **WiFi Warning Dismissal & Direct USB Scope**: Made the WiFi route warning banner immediately dismissible on tap (or via close icon) and restricted warning display strictly to direct USB connections targeting `192.168.51.x` IPs.

## ✅ Completed (v1.3.28)
- **Chromebook (ARC/Hatch) Android Deployment & Bridge**: Documented ChromeOS Android container deployment and created `scripts/bridge_dwarf.sh` to forward USB-Ethernet `192.168.51.1:80` traffic to the Crostini bridge (`100.115.92.201:80`).
- **Development Toolchain Validation**: Installed Linux host dependencies for Flutter build system while maintaining Android as the target platform.

## 📋 Remaining Tasks
- **A2. WebView Controls**: WebView full-screen toggle, separation layout adjustment.
- **E2. Default Fadeout Values**: Mapping default values for fader/automation objects.

## 🔧 Quick Context
- **App Version:** v1.3.29
- **Last commit:** Gemini3.7Flash(v1.3.29) - Make WiFi warning dismissible on tap and restrict trigger to direct USB IPs
- **Architecture:** Flutter app in `mod_controller/` with modular card-based UI
