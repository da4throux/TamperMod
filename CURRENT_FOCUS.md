# TamperMod — Current Focus

## ✅ Last Completed (v1.3.1)
- **SPECIFICATION.md cleanup**: All `[x]` done items moved from Todo to Done section; new §3.5 color palette rules added.
- **Color system fix**: Drawer tile colors now always match workspace card colors — all plugins (including ALO) use the same `getLeastUsedColor()` logic.
- **Palette expanded**: `kNeonColors` in `color_utils.dart` expanded from 5 to 10 colors. Duplicate in `dashboard_screen.dart` removed.
- **ALO override removed**: `#FF0055` hardcoded default for ALO loopers is gone; ALO is treated as a regular card like any other.
- **Least-used auto-assignment**: New plugins without a saved color automatically get the least-represented color from the palette.
- **Color picker counts fixed**: Removed stale ALO-specific count override from the color picker dialog.

## 🔧 Currently In Progress
- Nothing — v1.3.1 committed.

## ➡️ Recommended Next Step
- **SPECIFICATION.md Reorganized**: All 24 pending tasks now grouped into 6 categories (A-F) for easier assignment to different AI models.
- **Next Feature** (from `SPECIFICATION.md` §4 Todo):
  - **GROUP A** (UI/UX - 6 tasks): Best for simpler models - WebView controls, drawer fixes, dialog enhancements
  - **GROUP B** (Fader - 3 tasks): Medium complexity - triangle drag fix, beat bars, precision fixes
  - **GROUP C** (ALO - 3 tasks): Medium-high complexity - extended mode, regular mode, label fixes
  - **GROUP D** (Database - 1 task): High complexity - local database for pedalboard configs
  - **GROUP E** (Tech Debt - 2 tasks): Low complexity - setInterval cleanup, default values
  - **GROUP F** (Future - 9 tasks): Varies - BPM linking, MIDI, presets, cross-fader

## 📋 Quick Context
- **Connected device:** Pixel Tablet via ADB
- **App Version:** v1.3.1 (matches `main.dart` and `pubspec.yaml`)
