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

- **ALO Extended Mode On/Off/Click Buttons**:
  - Moved below Record/Mute/Clear action row
  - Buttons now target the selected loop (send to loop_X port)
  - ON button: sends 1.0 to loop port
  - OFF button: sends 0.0 to loop port
  - CLICK button: sends 1.0, waits 50ms, then sends 0.0

## 📋 Remaining Tasks
- **GROUP A Task A2**: WebView Controls Enhancement
- **GROUP D Task D1**: Local Database for Pedalboard Configurations
- **GROUP E Task E2**: Default Fadeout Values
- **GROUP F Tasks**: Future enhancements

## 🔧 Quick Context
- **App Version:** v1.3.10 (updated main.dart and pubspec.yaml)
- **Last commit:** Claude-Haiku-4.5(v1.3.10) - On/Off/Click buttons repositioned
- **Architecture:** Flutter app in `mod_controller/` with modular card-based UI
- **Status:** All ALO extended mode features complete and functional
