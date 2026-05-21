# TamperMod — Current Focus

## ✅ Last Completed (v1.2.11)
- **Phase 4 Refactoring**: Extracted `BpmController`, `BottomToolbar`, and `ConnectionPanel` to `lib/widgets/toolbars/`.
- **Bug Fixes**: Resolved ALO Looper mute crash (caused by invalid Material swatch grey color indexes `650`/`750`).
- **Transport controls**: Reversed Play/Stop transport button state display to match actual state (Play icon when active, Stop icon when stopped).
- **ALO Looper**: Made `CLEAR` button always active with a solid amber border. Added `ON`, `OFF`, and `CLICK` action buttons to the Click Volume controls.
- **Settings Drawer**: Closed drawer when tapping the puzzle icon in AppBar again. Removed close cross button and header text from settings drawer.

## 🔧 Currently In Progress
None.

## ➡️ Recommended Next Step
- **Phase 5 Refactoring**: Extract drawer widgets (`MetricsDrawer` to `lib/widgets/drawers/metrics_drawer.dart` and `SettingsDrawer` to `lib/widgets/drawers/settings_drawer.dart`).

## 📋 Quick Context
- **Connected device:** Pixel Tablet via ADB.
- **App Version:** v1.2.11 (dynamically matches `main.dart` and `pubspec.yaml`).
