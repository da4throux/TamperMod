# TamperMod — Current Focus

## ✅ Completed (v1.3.16)
- **BPM Fetching & Setting Fix**:
  - Implemented handling of the `transport <rolling> <beatsPerBar> <bpm>` command in `ModWebSocketService` to correctly parse and update BPM.
  - Modified `setBpm` to send the `transport-bpm <value>` command which is the correct command expected by the `mod-ui` Python server.
  - Removed empty `bpm` and `transport_bpm` commands on connection which were triggering `IndexError` on the Python host.
  - Added WebView DOM scraping fallback using JavaScript Channel (`BpmChannel`) and a periodic monitor to scrape host BPM from the status bar.
- **Widget Test Suite Fix**:
  - Implemented missing `setPlatformNavigationDelegate`, `addJavaScriptChannel`, and `removeJavaScriptChannel` overrides in the `FakePlatformWebViewController` mock.
  - Configured mock `SharedPreferences` initial values and set widget test physical viewport to `1280x800` to avoid layout overflows.

## ✅ Completed (v1.3.15)
- **Gain Regular & Extended Card UI**: 
  - Fade In and Fade Out buttons now properly share half width side-by-side using `Expanded`.
- **BPM Fetching & Setting**:
  - `ModWebSocketService` now explicitly requests BPM on connection using both `bpm` and `transport_bpm` commands.
  - Setting BPM now safely sends both commands to ensure compatibility with MOD Dwarf.
- **ALO Regular Card UI**:
  - Reorganized the 6 loop tracks timeline into two columns (3 rows each) to reduce overall height.
  - Increased track opacity while playing to 0.5 for better visibility.
- **ALO Looper Sync**:
  - Recording now waits for the *next beat* using an internal global stopwatch before actually starting, creating a perfect quantized sync point.

## ✅ Completed (v1.3.14)

## ✅ Completed (v1.3.13)
- **ALO Looper Size Toggle Fixed**:
  - Added `onSizeToggled` callback parameter to both LooperCard and LooperRegularCard
  - Wired SizeToggleButton to call dashboard's `_cyclePedalSize()` method
  - Size toggle now properly switches between 'expanded' and 'regular' modes
  - Both looper card variants now fully functional with working size toggle

## ✅ Completed (v1.3.12)
- **ALO Looper On/Off/Click Buttons Fixed**:
  - ON button: Now properly sets loop to playing state with green visual feedback
  - OFF button: Pauses/mutes the loop with grey visual feedback
  - CLICK button: Uses manualTrigger() to simulate foot switch tap
  - All buttons now integrate with LooperController for proper state management
  - Visual feedback shows current state (playing = green highlight, paused = grey highlight)

- **Regular Mode Confirmed Working**:
  - LooperRegularCard exists and is fully functional
  - Size toggle properly switches between 'expanded' and 'regular' modes
  - Dashboard correctly renders both card types based on _pedalSizes setting

## ✅ Completed (v1.3.11)
- **Beat Bar & Beat Dot Visualization Fixes**
- **ALO Looper Mode Toggle Fixed**
- **Gain Compact Card Layout Refactored**

## 📋 Remaining Tasks
- **GROUP A Task A2**: WebView Controls Enhancement
- **GROUP D Task D1**: Local Database for Pedalboard Configurations
- **GROUP E Task E2**: Default Fadeout Values
- **GROUP F Tasks**: Future enhancements

## 🔧 Quick Context
- **App Version:** v1.3.16
- **Last commit:** Gemini2.5Flash(v1.3.16) - Fix WebView test mock and implement DOM-based BPM fallback fetching
- **Architecture:** Flutter app in `mod_controller/` with modular card-based UI
- **Status:** All v1.3.16 features complete and fully functional
