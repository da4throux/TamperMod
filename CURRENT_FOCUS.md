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
- **Device Testing**: Validate color consistency on Pixel Tablet (drawer tiles match workspace cards).
- **Next Feature** (from `SPECIFICATION.md` §4 Todo):
  - Add a button to reload the WebView (most impactful UX item remaining).
  - Fix fader scope triangle drag speed (runs at half rate).

## 📋 Quick Context
- **Connected device:** Pixel Tablet via ADB
- **App Version:** v1.3.1 (matches `main.dart` and `pubspec.yaml`)
