# TamperMod — Current Focus

## ✅ Completed (v1.3.22)
- **ALO Compact Card UI Optimization & Interactivity**:
  - Reduced the small timeline height from 60px to 48px and compacted card margins/padding to completely prevent vertical layout overflow within the 240px card height.
  - Removed the edit icon from the ALO cards title; long pressing the title text/icon or the size toggle button opens the rename/color customization dialog.
  - Made the Record button dynamic: it toggles to "CANCEL" mode (showing Cancel text and icon) when counting-in or recording, calling clearLoop to cancel.
  - Made the small timeline track rows interactive: clicking a row selects the corresponding loop, and the active loop row displays a highlighted background.

## ✅ Completed (v1.3.21)
- **Card Customization & Long Press Bindings**:
  - Fixed the color selection state scoping bug in the rename/customize dialog.
  - Bound the size toggle button (scaler) long-press gesture to trigger the rename/customize dialog.

## ✅ Completed (v1.3.20)
- **Synchronized Interactive BPM Popup Dialog**:
  - Tapping on the BPM display (top bar or ALO card badges) opens a dialog containing side-by-side exact typing text field and rotary `BpmKnob`.
  - Added a tap listener on `BpmKnob` that rounds the BPM to the nearest multiple of 5 (ending in 0 or 5), clamped to `[20.0, 280.0]`.
  - Bi-directional real-time sync between the text field and the knob ensures updates are immediately visible without cursor or focus disruption.
- **Clickable ALO Badge**:
  - Wrapped ALO looper card metronome badges with GestureDetector invoking the BPM dialog.

## ✅ Completed (v1.3.19)
- **ALO Compact Card Loop Timeline Columns**:
  - Reorganized the loop playback progress bar rows into 3 columns (2 rows each) instead of 2 columns (3 rows each).
  - This increases the horizontal space for each track, resolving a layout overflow on compact screen viewports.

## ✅ Completed (v1.3.18)
- **Multi-Configuration Support per Pedalboard**:
  - Implemented local persistence layout configuration mechanism isolated per pedalboard via mathematical hash base key and user configurations.
  - Added a Layout Configuration section at the top of the Settings Drawer allowing user to switch, duplicate, rename, and delete configurations.
  - Config state updates are automatically saved to SharedPreferences under the active config.

## ✅ Completed (v1.3.17)
- **WebView Reload Button**:
  - Added an explicit reload button (using `Icons.cached`) to the bottom toolbar.
  - Linked to `_webViewController.reload()` to force manual web interface synchronization.
- **BPM Rotary Knob**:
  - Implemented a custom `BpmKnob` and custom painter `BpmKnobPainter` next to the BPM text display.
  - Bounded to `20-280` BPM range. Adjusts value via intuitive vertical drag gestures.
  - Supports double-tap to reset to `120.0` BPM.
  - Wired to `_webSocketService.setBpm` to update global host tempo.

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
- **GROUP A Task A2**: WebView Controls Enhancement (Remaining: full screen and separation scaling)
- **GROUP E Task E2**: Default Fadeout Values
- **GROUP F Tasks**: Future enhancements

## 🔧 Quick Context
- **App Version:** v1.3.22
- **Last commit:** Gemini2.5Flash(v1.3.22) - Optimize compact ALO Card layout, remove edit icon, and make small timeline interactive
- **Architecture:** Flutter app in `mod_controller/` with modular card-based UI
- **Status:** All v1.3.22 features complete and fully functional
