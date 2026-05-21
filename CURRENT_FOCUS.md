# TamperMod — Current Focus

## ✅ Completed (v1.3.10)
- **Beat Bar & Beat Dot Visualization Fixes**:
  - Fixed beat bar separators: 3 lines for 4 bars (not 5) in fade curve painter
  - Fixed beat dots in ALO looper timeline: 3 dots per bar (not 4)
  - Dots now light up only when the moving bar aligns with them
  - Dot size increases when active (8px vs 4px)
  - Applied to all looper visualizations (extended and regular modes)

- **ALO Looper Mode Toggle Fixed**:
  - Enabled size toggle button for ALO loopers
  - Users can now toggle between extended and regular modes
  - Dashboard's `_cyclePedalSize()` now properly handles ALO looper toggling
  - Both LooperCard (extended) and LooperRegularCard (regular) are fully functional

- **Gain Compact Card Layout**:
  - Fade IN and Fade OUT buttons now stacked vertically (Column instead of Row)
  - Proper spacing between buttons (4px SizedBox)

## 📋 Remaining Tasks
- **On/Off/Click buttons**: Move below Record/Mute/Clear row and target the loop
- **GROUP A Task A2**: WebView Controls Enhancement
- **GROUP D Task D1**: Local Database for Pedalboard Configurations
- **GROUP E Task E2**: Default Fadeout Values
- **GROUP F Tasks**: Future enhancements

## 🔧 Quick Context
- **App Version:** v1.3.10 (updated main.dart and pubspec.yaml)
- **Last commit:** Claude-Haiku-4.5(v1.3.10) - Beat dots and ALO toggle fixes
- **Architecture:** Flutter app in `mod_controller/` with modular card-based UI
- **Status:** All beat visualizations now correct (3 separators, 3 dots per bar)
