# TamperMod — Current Focus

## ✅ Last Completed (v1.2.10)
- **Phase 3 Refactoring**: Extracted `FadeButton`, `SizeToggleButton`, and `ModuleHelpSheet` to separate common widgets.
- **Fade Curve Reversal**: Reversed curve/moving dot drawing for Fade Out in both local and extracted `FadeCurvePainter`.
- **ALO Looper**: Kept stopwatch running on pause to keep beat in sync; changed paused state text to MUTED and icon to `Icons.volume_off`. Equalized action button sizes. Tapped sliders toggle values:
  - Click Volume: Toggles between 0 and previous non-zero volume.
  - Mix Setting: Toggles between 0%, 50%, and 100%.
  - Threshold: Toggles between -60dB, -40dB, and 0dB.
- **Drawer Improvements**: Replaced drawer settings icon with a toggleable puzzle icon (`Icons.extension`); removed "Workspace Settings" header text.
- **Reload Resync**: Clearing `_localVolumes` on reload fetches and applies the new parameter volume correctly.

## 🔧 Currently In Progress
None.

## ➡️ Recommended Next Step
- Task 113: Outline for Gain controller fade triangles and positioning on the top edge of the volume slider.
- Task 121: Improve scrolling accuracy when tapping controller from right drawer.

## 📋 Quick Context
- **Connected device:** Pixel Tablet via ADB.
- **App Version:** v1.2.10 (dynamically matches `main.dart` and `pubspec.yaml`).
