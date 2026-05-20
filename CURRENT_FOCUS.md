# TamperMod — Current Focus

## ✅ Last Completed (v1.1.10)
- Fixed app crash on tablet startup: Added null safety checks in `_updateAllGlowsInWebView()` method
- Added `if (!mounted) return;` guard to prevent WebView operations when widget is unmounted
- Wrapped looper controller access in try-catch block to handle initialization timing issues
- Fixed potential null pointer exception when accessing `_looperController.activeLooper` during app initialization
- Updated version to 1.1.10 in both `main.dart` and `pubspec.yaml` per atomic versioning rule

## 🔧 Currently In Progress
Nothing mid-flight. All changes committed and deployed to Pixel Tablet.

## ➡️ Recommended Next Step
First unchecked item in `SPECIFICATION.md` §4 Todo:
> Fix fadeout issues when running under `fade` mode in the Tampermonkey script.
> (`TamperMod.user.js` — fade target landing precision, transition errors from -40dB.)

## 📋 Quick Context
- **App:** Flutter (`mod_controller/`) — Pixel Tablet controller for MOD Dwarf pedalboard.
- **Transport:** WebSocket `ws://192.168.51.1/websocket` (MOD Dwarf proprietary protocol, space-separated commands).
- **Current version:** `1.1.10` (matches `kAppVersion` in `main.dart` and `pubspec.yaml`).
- **Key files:** `mod_controller/lib/main.dart`, `mod_controller/lib/services/websocket_service.dart`, `TamperMod.user.js`, `SPECIFICATION.md`.
- **Connected device:** Pixel Tablet (`3417105H801S8D`) via ADB — run `flutter run -d 3417105H801S8D` to deploy.
