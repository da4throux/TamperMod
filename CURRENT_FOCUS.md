# TamperMod — Current Focus

## ✅ Last Completed (v1.2.3)
- Restored missing `_tapTimes` declaration in `_DashboardScreenState` to fix the Flutter release build compilation failure.
- Created a compact (half-width) form of the Gain card with name/size toggle, volume slider, mute toggle, and fade in/out buttons.
- Configured the power button on regular Gain cards to act as a software mute toggle.
- Mapped ALO looper click volume control to 1-10 steps (increasing 1 by 1) in UI.
- Refined ALO looper record logic to send flat 1.0 at start of recording and no tap at the end of recording.
- Refined ALO looper play/pause logic to send flat 1.0 (play) and 0.0 (pause).
- Verified release build successfully using `flutter build apk`.
- Updated application version to 1.2.3 in `main.dart` and `pubspec.yaml` per atomic versioning rule.

## 🔧 Currently In Progress
Nothing mid-flight. All changes committed and verified.

## ➡️ Recommended Next Step
First unchecked item in `SPECIFICATION.md` §4 Todo:
> Fix fadeout issues when running under `fade` mode in the Tampermonkey script.
> (`TamperMod.user.js` — fade target landing precision, transition errors from -40dB.)

## 📋 Quick Context
- **App:** Flutter (`mod_controller/`) — Pixel Tablet controller for MOD Dwarf pedalboard.
- **Transport:** WebSocket `ws://192.168.51.1/websocket` (MOD Dwarf proprietary protocol, space-separated commands).
- **Current version:** `1.2.3` (matches `kAppVersion` in `main.dart` and `pubspec.yaml`).
- **Key files:** `mod_controller/lib/main.dart`, `mod_controller/lib/services/websocket_service.dart`, `TamperMod.user.js`, `SPECIFICATION.md`.
- **Connected device:** Pixel Tablet (`3417105H801S8D`) via ADB — run `flutter run -d 3417105H801S8D` to deploy.
