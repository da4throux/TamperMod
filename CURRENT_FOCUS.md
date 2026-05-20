# TamperMod — Current Focus

## ✅ Last Completed (v1.2.5)
- **Compact Gain card**: Fade IN/OUT buttons stacked vertically (same 110px height); mini range indicator beside buttons.
- **Regular Gain card**: Power button removed; speaker icon (volume_up/off) is now mute toggle; long-press title = rename; dB box fixed width (72px); range mini-indicator between min/max labels; size-toggle cycles compact→regular→expanded→compact.
- **Expanded Gain card** (new, 520px): RangeSlider for fade start/end cursors, 5-shape selector (LINEAR/S1/S2/S3/CUSTOM), custom S-curve sliders (cx/cy/slope) + EXPORT to clipboard, live CustomPainter fade curve visualizer with moving dot.
- **Fade engine**: now uses per-pedal range cursors and selected shape curve; tracks `_fadeProgress` for the visualizer dot.
- Added `_CustomSCurve`, `_FadeCurvePainter`, `_MiniRangePainter` top-level classes.
- Persisted new state: `_fadeRangeStart`, `_fadeRangeEnd`, `_fadeShapes`, `_fadeCustomParams`.
- Updated `kAppVersion` → `1.2.5` and `pubspec.yaml`.

## 🔧 Currently In Progress
Nothing mid-flight. Build verification in progress.

## ➡️ Recommended Next Step
First unchecked item in `SPECIFICATION.md` §4 Todo:
> Fix fadeout issues when running under `fade` mode in the Tampermonkey script.
> (`TamperMod.user.js` — fade target landing precision, transition errors from -40dB.)

## 📋 Quick Context
- **App:** Flutter (`mod_controller/`) — Pixel Tablet controller for MOD Dwarf pedalboard.
- **Transport:** WebSocket `ws://192.168.51.1/websocket` (MOD Dwarf proprietary protocol, space-separated commands).
- **Current version:** `1.2.5` (matches `kAppVersion` in `main.dart` and `pubspec.yaml`).
- **Key files:** `mod_controller/lib/main.dart`, `mod_controller/lib/services/websocket_service.dart`, `TamperMod.user.js`, `SPECIFICATION.md`.
- **Connected device:** Pixel Tablet (`3417105H801S8D`) via ADB — run `flutter run -d 3417105H801S8D` to deploy.

