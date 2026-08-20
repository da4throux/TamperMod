# TamperMod — Current Focus

## ✅ Completed (v1.3.87)
- **Pedal Search Enhancements & Vibrant Tile Board Category Icons**:
  1. **Pedal Search Off by Default**: Initialized `_isPedalSearchMode = false` by default.
  2. **Pedal Hover Tooltip**: Hovering over any pedal in the WebView pedalboard now displays a floating HUD tooltip with the pedal's full title and `🔍` indicator.
  3. **5-Second Synchronized Flashing Strobe**: When tapping a pedal in search mode, the physical pedal, dashboard card, and puzzle tile all flash in sync with a rapid 250ms breathing strobe for 5 seconds.
  4. **Tile Board Category Icons**: Active puzzle tiles in the drawer now feature high-contrast, category-tinted glowing icon badges with their respective effect family colors (⚡ orange Drive, 🌊 cyan Delay, 🌌 purple Reverb, etc.).

## ✅ Completed (v1.3.86)
- **Category Icons on Dashboard Cards & Expandable Full-Width Inactive Pool**:
  1. **Category Icons & Micro-Badges on Dashboard Cards**: Integrated `PluginCategoryHelper` into all dashboard card headers (`PlaceholderCard`, `GainCard`, `SwitchCard`, `LooperCard`, `LooperRegularCard`) and `SizeToggleButton`. Cards now prominently display their category icon (⚡ Drive, 🌊 Delay, 🌌 Reverb, 🔊 Gain, 🔀 Switch, 🔁 Looper, etc.) alongside the size toggle and category badge.
  2. **Expandable Inactive Pool (MIN / MID / MAX Segmented Toggle)**: Added a 3-way segmented expansion pill selector to the Inactive Pool header:
     - `MIN`: Collapses inactive pool to a slim 1-line header to maximize Active Canvas workspace.
     - `MID`: Balanced split view (5:4 flex ratio).
     - `MAX`: Expanded full-height inactive pool (2:7 flex ratio) to view and search available plugins comfortably.
  3. **Full-Width Single-Line Inactive Items**: Inactive pedals now display as full-width, single-line cards with category icon, untruncated name, category pill, and an `[+ ADD]` quick-action button.

## 📋 Remaining Tasks
- **A2. WebView Controls**: WebView full-screen toggle, separation layout adjustment.
- **E2. Default Fadeout Values**: Mapping default values for fader/automation objects.

## 🔧 Quick Context
- **App Version:** v1.3.87
- **Last commit:** Gemini3.7Flash(v1.3.87) - Pedal search hover name tooltip, 5s flashing strobe, and tile board category icons
- **Architecture:** Flutter app in `mod_controller/` with modular card-based UI

