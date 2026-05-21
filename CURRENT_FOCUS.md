# TamperMod — Current Focus

## ✅ Last Completed (v1.3.4)
- **Group A UI/UX Improvements** (5 of 6 tasks completed):
  - **A1. WiFi Auto-Disable on Connect**: Added "SETTINGS" button to WiFi warning snackbar that opens Android WiFi settings via MethodChannel
  - **A3. Drawer Scroll Accuracy Fix**: Improved `_scrollToCard()` to calculate accurate scroll offsets based on card dimensions and spacing
  - **A4. Edit Dialog Enhancement**: Renamed dialog now includes integrated color picker in the same dialog (StatefulBuilder for local state)
  - **A5. Drawer Double-Tap Size Toggle**: Double-tap on drawer tiles now cycles through sizes (C→R→E→C) for non-loopers; loopers/inactive tiles open color picker
  - **A6. Fader Triangle Drag Speed Fix**: Triangle drag now uses correct delta calculation for responsive 1:1 finger tracking

## 🔧 Currently In Progress
- Nothing — v1.3.4 committed.

## ➡️ Recommended Next Step
- **A2. WebView Controls Enhancement** (remaining from Group A):
  - Add fullscreen toggle button for WebView (pinch-zoom/pan without controls overlay)
  - Add separation slider between workspace and web view
  - Requires UI refactoring to support dynamic layout adjustments
- **GROUP B** (Fader/Automation - 3 tasks): Medium complexity - triangle double-tap, beat bars, precision fixes
- **GROUP C** (ALO Looper - 3 tasks): Medium-high complexity - extended/regular mode redesign

## 📋 Quick Context
- **Connected device:** Pixel Tablet via ADB
- **App Version:** v1.3.4 (matches `main.dart` and `pubspec.yaml`)
- **Last commit:** Cline(v1.3.4) - Group A improvements
