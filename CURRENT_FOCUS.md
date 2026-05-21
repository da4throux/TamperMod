# TamperMod — Current Focus

## ✅ Last Completed (v1.2.8)
- **Phase 0.1 - ALO Looper Card Header Standardization**: Added greyed-out, non-functional size toggle button to ALO looper card header (left side, before title) using `Icons.aspect_ratio` icon. Matches visual design of Gain/Switch card size toggles.
- **Phase 0.2 - ALO Looper Single-Controller Treatment**: Verified ALO looper is correctly treated as single controller in `_enabledPluginInstances`, uses single glow color assignment via `_pedalGlowColors` map, appears once in puzzle organizer drawer, and single glow color persists via SharedPreferences.
- **Phase 0.3 - ALO Looper Auto-Expand Fix**: Removed internal scrolling from ALO looper card by replacing `Expanded` + `SingleChildScrollView` with `Column(mainAxisSize: MainAxisSize.min)`. Card now auto-expands to fit content without scrolling, matching behavior of other controllers.
- **Phase 0.4 - ALO Looper Overflow Fix**: Changed `cardHeight = 450.0` to `cardHeight = null` to allow ALO looper card to auto-expand to fit all content without overflow. Card now expands to required height like other extended controllers.
- Updated `kAppVersion` → `1.2.8`, `pubspec.yaml`, and committed at `afe9150`.

## ✅ Phase 1: Directory Structure Setup (Complete)
- Created complete modular directory tree under `mod_controller/lib/`
- Created 19 placeholder files with TODO comments for future extraction
- All files organized by component type (screens, widgets, utils, services, models)
- Compilation verified: `flutter analyze` passed with no new errors
- Committed at `f3a5ae3`

## ✅ Phase 2: Extract Utilities & Painters (Complete)
- **Phase 2.1:** Extracted `_CustomSCurve` → `lib/utils/curves.dart` (CustomSCurve class)
- **Phase 2.2:** Extracted color utilities → `lib/utils/color_utils.dart` (hexToColor, hexToRgba, kNeonColors)
- **Phase 2.3:** Extracted painters → `lib/widgets/painters/*.dart`:
  - `FadeCurvePainter` (live fade curve visualizer with grid, range lines, moving dot)
  - `MiniRangePainter` (vertical range indicator with triangle handles)
  - `RangeOverlayPainter` (range cursor overlay on volume slider)
- Compilation verified: `flutter analyze` passed (112 pre-existing issues, no new errors)
- Updated version: `1.2.9` in both `main.dart` and `pubspec.yaml`
- Committed at `dae3c9b` (Haiku4.5)

## 🔧 Currently In Progress
Phase 2 (Utilities & Painters Extraction) complete. Ready to begin Phase 3 (Extract Common Widgets).

## ➡️ Recommended Next Step
Phase 3: Extract Common Widgets (medium-risk extraction)
- Extract `FadeButton` widget to `lib/widgets/common/fade_button.dart`
- Extract `SizeToggleButton` widget to `lib/widgets/common/size_toggle_button.dart`
- Extract `ModuleHelpSheet` to `lib/widgets/common/module_help_sheet.dart`
- Test compilation and UI rendering after each extraction

## 📋 Quick Context
- **App:** Flutter (`mod_controller/`) — Pixel Tablet controller for MOD Dwarf pedalboard.
- **Transport:** WebSocket `ws://192.168.51.1/websocket` (MOD Dwarf proprietary protocol, space-separated commands).
- **Current version:** `1.2.8` (matches `kAppVersion` in `main.dart` and `pubspec.yaml`).
- **Key files:** `mod_controller/lib/main.dart`, `mod_controller/lib/services/websocket_service.dart`, `TamperMod.user.js`, `SPECIFICATION.md`.
- **Connected device:** Pixel Tablet (`3417105H801S8D`) via ADB — run `flutter run -d 3417105H801S8D` to deploy.

