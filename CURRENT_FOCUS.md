# TamperMod — Current Focus

## ✅ Last Completed (v1.2.8)
- **Phase 0.1 - ALO Looper Card Header Standardization**: Added greyed-out, non-functional size toggle button to ALO looper card header (left side, before title) using `Icons.aspect_ratio` icon. Matches visual design of Gain/Switch card size toggles.
- **Phase 0.2 - ALO Looper Single-Controller Treatment**: Verified ALO looper is correctly treated as single controller in `_enabledPluginInstances`, uses single glow color assignment via `_pedalGlowColors` map, appears once in puzzle organizer drawer, and single glow color persists via SharedPreferences.
- **Phase 0.3 - ALO Looper Auto-Expand Fix**: Removed internal scrolling from ALO looper card by replacing `Expanded` + `SingleChildScrollView` with `Column(mainAxisSize: MainAxisSize.min)`. Card now auto-expands to fit content without scrolling, matching behavior of other controllers.
- Updated `kAppVersion` → `1.2.8`, `pubspec.yaml`, and committed at `1816222`.

## 🔧 Currently In Progress
Phase 0 (ALO Looper Refactoring) complete. Committed at v1.2.8, `flutter analyze` passed with pre-existing warnings (no new errors).

## ➡️ Recommended Next Step
First unchecked item in `SPECIFICATION.md` §4 Todo:
> Fix fadeout issues when running under `fade` mode in the Tampermonkey script.
> (`TamperMod.user.js` — fade target landing precision, transition errors from -40dB.)

## 📋 Quick Context
- **App:** Flutter (`mod_controller/`) — Pixel Tablet controller for MOD Dwarf pedalboard.
- **Transport:** WebSocket `ws://192.168.51.1/websocket` (MOD Dwarf proprietary protocol, space-separated commands).
- **Current version:** `1.2.8` (matches `kAppVersion` in `main.dart` and `pubspec.yaml`).
- **Key files:** `mod_controller/lib/main.dart`, `mod_controller/lib/services/websocket_service.dart`, `TamperMod.user.js`, `SPECIFICATION.md`.
- **Connected device:** Pixel Tablet (`3417105H801S8D`) via ADB — run `flutter run -d 3417105H801S8D` to deploy.

