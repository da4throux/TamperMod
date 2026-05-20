# TamperMod — Current Focus

## ✅ Last Completed (v1.1.8)
- Fixed drawer tile layout: two Regular tiles now share a row, matching main canvas proportions.
- Fixed control card overflow: Regular card height raised to 240px to accommodate the FADE row.
- Moved bottom toolbar out of `Scaffold.bottomNavigationBar` into the body Column (between IP bar and content) to avoid Android gesture bar conflict.
- Strengthened `.agentrules`: atomic version rule, mandatory SPECIFICATION.md updates, session start protocol, and agent handoff protocol.
- Updated `SPECIFICATION.md` to reflect all v1.1.8 UI/UX changes.

## 🔧 Currently In Progress
Nothing mid-flight. All changes committed and deployed to Pixel Tablet.

## ➡️ Recommended Next Step
First unchecked item in `SPECIFICATION.md` §4 Todo:
> Fix fadeout issues when running under `fade` mode in the Tampermonkey script.
> (`TamperMod.user.js` — fade target landing precision, transition errors from -40dB.)

## 📋 Quick Context
- **App:** Flutter (`mod_controller/`) — Pixel Tablet controller for MOD Dwarf pedalboard.
- **Transport:** WebSocket `ws://192.168.51.1/websocket` (MOD Dwarf proprietary protocol, space-separated commands).
- **Current version:** `1.1.8` (matches `kAppVersion` in `main.dart` and `pubspec.yaml`).
- **Key files:** `mod_controller/lib/main.dart`, `mod_controller/lib/services/websocket_service.dart`, `TamperMod.user.js`, `SPECIFICATION.md`.
- **Connected device:** Pixel Tablet (`3417105H801S8D`) via ADB — run `flutter run -d 3417105H801S8D` to deploy.
