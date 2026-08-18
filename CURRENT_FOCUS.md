# TamperMod — Current Focus

## ✅ Completed (v1.3.31)
- **Connection Panel Layout Optimization**: Reorganized the connection bar to group the IP preset dropdown, IP text input, CONNECT/DISCONNECT button, and Browser icon compactly together on the left side of the screen.

## ✅ Completed (v1.3.30)
- **IP Preset Selector & Persistence**: Added a quick dropdown menu in the connection bar with presets for Direct USB / Pixel Tablet (`192.168.51.1`), Chromebook Hatch Bridge (`100.115.92.201`), and Wi-Fi (`moddwarf.local`). Saved IP automatically persists in `SharedPreferences`.

## ✅ Completed (v1.3.29)
- **WiFi Warning Dismissal & Direct USB Scope**: Made the WiFi route warning banner immediately dismissible on tap (or via close icon) and restricted warning display strictly to direct USB connections targeting `192.168.51.x` IPs.

## ✅ Completed (v1.3.28)
- **Chromebook (ARC/Hatch) Android Deployment & Bridge**: Documented ChromeOS Android container deployment and created `scripts/bridge_dwarf.sh` to forward USB-Ethernet `192.168.51.1:80` traffic to the Crostini bridge (`100.115.92.201:80`).

## 📋 Remaining Tasks
- **A2. WebView Controls**: WebView full-screen toggle, separation layout adjustment.
- **E2. Default Fadeout Values**: Mapping default values for fader/automation objects.

## 🔧 Quick Context
- **App Version:** v1.3.31
- **Last commit:** Gemini3.7Flash(v1.3.31) - Group IP preset dropdown, text field, and connect button compactly on the left
- **Architecture:** Flutter app in `mod_controller/` with modular card-based UI
