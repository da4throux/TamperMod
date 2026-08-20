# TamperMod — Current Focus

## ✅ Completed (v1.3.88)
- **Pedal Search Hover Resolution & Inactive Pool Tile Flashing**:
  1. **Accurate Pedal Names with Custom Name Support**: Hover tooltip in WebView now reads directly from plugin metadata and user custom names: formats as `[ORIGINAL TITLE] / [CUSTOM NAME]` (e.g. `SWITCHBOX / CLEAN-CRUNCH`) or `[ORIGINAL TITLE]` (e.g. `SWITCHBOX`), completely eliminating internal knob/switch label misreadings.
  2. **Available Pool Tile Flashing & Auto-Scroll**: When a pedal in the inactive pool is clicked or searched, the inactive pool tile pulses with high-intensity neon strobe for 5 seconds and auto-scrolls into view (auto-expanding the pool if set to minimal).
  3. **Universal 5-Second Flashing Trigger**: Clicking any mini puzzle tile (active or inactive) or any card's radar focus button now immediately triggers the synchronized 5-second flashing strobe across the web pedal, the dashboard card, and the puzzle board tile.

## ✅ Completed (v1.3.87)
- **Pedal Search Enhancements & Vibrant Tile Board Category Icons**:
  1. **Pedal Search Off by Default**: Initialized `_isPedalSearchMode = false` by default.
  2. **Pedal Hover Tooltip**: Hovering over any pedal in the WebView pedalboard now displays a floating HUD tooltip with the pedal's full title and `🔍` indicator.
  3. **5-Second Synchronized Flashing Strobe**: When tapping a pedal in search mode, the physical pedal, dashboard card, and puzzle tile all flash in sync with a rapid 250ms breathing strobe for 5 seconds.
  4. **Tile Board Category Icons**: Active puzzle tiles in the drawer now feature high-contrast, category-tinted glowing icon badges with their respective effect family colors (⚡ orange Drive, 🌊 cyan Delay, 🌌 purple Reverb, etc.).

## 📋 Remaining Tasks
- **A2. WebView Controls**: WebView full-screen toggle, separation layout adjustment.
- **E2. Default Fadeout Values**: Mapping default values for fader/automation objects.

## 🔧 Quick Context
- **App Version:** v1.3.88
- **Last commit:** Gemini3.7Flash(v1.3.88) - Pedal hover accurate title and custom name, inactive pool tile flashing, and universal puzzle tile flash trigger
- **Architecture:** Flutter app in `mod_controller/` with modular card-based UI

