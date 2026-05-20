# TamperMod — Current Focus

## ✅ Last Completed (v1.2.1)
- Repositioned the bottom toolbar (UI bar) above the connection panel.
- Simplified settings drawer: removed "Open Pedalboard in Browser" button and all duplicate version text references.
- Aligned workspace active card sorting with settings drawer order.
- Added drag-and-drop to empty space in settings drawer to move tiles to the end.
- Updated version to 1.2.1 in both `main.dart` and `pubspec.yaml` per atomic versioning rule.

## 🔧 Currently In Progress
Nothing mid-flight. All changes committed and verified.

## ➡️ Recommended Next Step
First unchecked item in `SPECIFICATION.md` §4 Todo:
> Fix fadeout issues when running under `fade` mode in the Tampermonkey script.
> (`TamperMod.user.js` — fade target landing precision, transition errors from -40dB.)

## 📋 Quick Context
- **App:** Flutter (`mod_controller/`) — Pixel Tablet controller for MOD Dwarf pedalboard.
- **Transport:** WebSocket `ws://192.168.51.1/websocket` (MOD Dwarf proprietary protocol, space-separated commands).
- **Current version:** `1.2.1` (matches `kAppVersion` in `main.dart` and `pubspec.yaml`).
- **Key files:** `mod_controller/lib/main.dart`, `mod_controller/lib/services/websocket_service.dart`, `TamperMod.user.js`, `SPECIFICATION.md`.
- **Connected device:** Pixel Tablet (`3417105H801S8D`) via ADB — run `flutter run -d 3417105H801S8D` to deploy.

