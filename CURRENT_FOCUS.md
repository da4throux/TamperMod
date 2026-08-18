# TamperMod — Current Focus

## ✅ Completed (v1.3.33)
- **Top Bar Connection Fold Toggle**: Moved the dedicated connection setup toggle button exclusively to the top AppBar beside the `TAMPERMOD LIVE` title and connection status badge, keeping the toolbar clean.

## ✅ Completed (v1.3.32)
- **Collapsible Connection Setup Bar**: Enabled folding and unfolding the connection panel via an animated collapse (`AnimatedSize`) triggered by tapping the top AppBar title/status chip (with interactive chevron indicator) or the cable icon in the toolbar, saving screen real estate.

## ✅ Completed (v1.3.31)
- **Connection Panel Layout Optimization**: Reorganized the connection bar to group the IP preset dropdown, IP text input, CONNECT/DISCONNECT button, and Browser icon compactly together on the left side of the screen.

## ✅ Completed (v1.3.30)
- **IP Preset Selector & Persistence**: Added a quick dropdown menu in the connection bar with presets for Direct USB / Pixel Tablet (`192.168.51.1`), Chromebook Hatch Bridge (`100.115.92.201`), and Wi-Fi (`moddwarf.local`). Saved IP automatically persists in `SharedPreferences`.

## 📋 Remaining Tasks
- **A2. WebView Controls**: WebView full-screen toggle, separation layout adjustment.
- **E2. Default Fadeout Values**: Mapping default values for fader/automation objects.

## 🔧 Quick Context
- **App Version:** v1.3.33
- **Last commit:** Gemini3.7Flash(v1.3.33) - Move connection setup bar fold toggle exclusively to the top AppBar
- **Architecture:** Flutter app in `mod_controller/` with modular card-based UI
