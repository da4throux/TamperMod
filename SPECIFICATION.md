# Specification Blueprint: TamperMod
Please read and apply .agenrules

## 1. Architecture Overview
* **Frontend Controller:** Flutter application (`mod_controller`) managing state, websocket communication, and tablet UI.
* **Target Device:** Specifically optimized for the Pixel Tablet in both portrait and landscape orientations.
* **Browser Injection:** Tampermonkey user script (`TamperMod.user.js`) intercepting web page events and automating pedal board controls on `moddwarf.local`.
* **Communication Protocol:** 
  * WebSocket connection (`ws://<ip>/websocket`) from the Flutter controller to the MOD Dwarf host to listen for and transmit parameter changes (`param_set`), BPM updates, and transport rolling status.
  * Injected JavaScript via `WebViewController` to handle dynamic visual highlight overlays and dual-layered glows on the MOD Dwarf web GUI.

---

## 2. Core Data Models & Objects

### 2.1 PluginInstance
* Exposes properties for active plugins on the pedalboard:
  * `instance` (String): Unique identifier of the plugin instance (e.g. `/graph/mono`, `/graph/alo_1`).
  * `uri` (String): Raw URI of the plugin (e.g. `http://guitarix.sourceforge.net/plugins/gx_cabinet`).
  * `title` (String): Display title parsed and cleaned from the instance ID.
  * `gainPortSymbol` (String?): Dynamic port symbol identified for gain control (e.g., `Gain`, `volume`, `level`).
  * `parameters` (Map<String, double>): Current map of parameter values updated in real time.
  * `isBypassed` (bool): Bypass state of the plugin instance.

### 2.2 LooperState
* ALO looper doc: https://github.com/devcurmudgeon/alo
* Defines states of the ALO looper tracks:
  * `empty`: Track contains no loop data.
  * `countIn`: Host transport is running count-in before recording.
  * `recording`: Track is actively recording input.
  * `playing`: Track is playing back loop memory.
  * `paused`: Track playback is paused.

### 2.3 ModuleHelpData
* Defines registry metadata for cards (Gain, Switch, Looper) detailing:
  * `overview` (String): Brief explanation of card functionality.
  * `parameters` (List<String>): Key editable parameters.
  * `hotkeys` (List<String>): Configured hotkeys mapped in client/script interfaces.
  * `underTheHood` (String): Underlying port/WebSocket logic.

---

## 3. UI/UX & Flow Rules

### 3.1 Workspace Dashboard Layout
* **Dynamic Grid:** Built using a scrollable `Wrap` widget containing custom card instances.
* **Card Sizing System:**
  * **Compact (C):** Compact card (height: 240) representing minimal parameters. Size-toggle icon (left of name)/Name, gain dB, volume slider, speaker mute icon. Fade IN and OUT buttons stacked vertically side-by-side with a mini range indicator bar.
  * **Regular (R):** Standard card (height:240). Long-press on title = rename. Speaker icon (rightmost) = mute toggle. Size-toggle icon (left of title) cycles compact→regular→expanded→compact. Fixed-width 72px dB box. Mini range indicator in the min/max row. No power button.
  * **Expanded (E):** Full-width card (height: 520). Includes all Regular features plus: Size-toggle icon (left of title), RangeSlider for fade start/end cursors, fade shape selector (Linear/S1/S2/S3/Custom), custom S-curve sliders with clipboard EXPORT, and a live CustomPainter fade curve visualiser with moving dot.
  * *ALO Loopers always use full row width at height 450.*

### 3.2 Puzzle Organizer Settings Drawer
* Scale-down grid layout mirroring the workspace card arrangement (two Regular tiles per row, same proportions as the main canvas).
* **Card Visibility:** Controlled exclusively by dragging tiles between the **Active Canvas** (upper zone) and the **Available Pool** (lower inactive zone). No toggle buttons.
* **Drag-and-Drop:** Long Press on a tile initiates drag to reorder within the canvas or move between zones.
* Interactive gestures:
  * **Single Tap:** Scrolls main view to and pulses the target card.
  * **Double Tap:** Opens a color picker to adjust the neon glow color of the card.
  * **Long Press:** Initiates Drag-and-Drop to rearrange cards or change active/inactive status.
* **Color consistency rule:** Drawer tile colors MUST always match the workspace card color. All plugins use the same color assignment logic — no type-specific default overrides.

### 3.3 Bottom Toolbar
* Positioned **inside the body Column**, above the IP connection bar (connection panel) at the top of the body Column.
* Functionalities:
  * Layout view selectors (Controls, Web, Split).
  * Radar locate trigger button (pulses all active pedal glows in the Web GUI).
  * Refresh/Reload pedalboard trigger.
  * Light/Dark Theme toggle with SharedPreferences persistence.
  * Current version info display.

### 3.4 Dual-Layered Glow Effects
* Highlights on the WebView canvas feature dual box-shadow configurations:
  * A tight, very bright neon glow directly surrounding the device boundary (`0 0 20px 8px <color>`).
  * A wider, far-reaching soft ambient halo spreading light outward (`0 0 180px 4px <color>`).
  * Inset glow to highlight control knobs (`inset 0 0 15px <color>`).

### 3.5 Neon Color Palette
* A shared palette of 10 neon colors is used for plugin glow assignment.
* **Auto-assignment rule:** When a new plugin appears with no saved color, it is automatically assigned the color currently **least used** across all active plugins.
* The color picker shows all 10 colors with a usage-count badge.

---

## 4. Feature Implementation Progress

### Done
* [x] Initialize baseline Flutter controller project setup.
* [x] Create base Tampermonkey injection script structure.
* [x] Implement dynamic BPM value reflection in the Flutter UI.
* [x] Map `pedals_families` object parameters to volume controls.
* [x] Implement dual-track ALO Looper UI with volume/mix/threshold sliders.
* [x] Create "Puzzle Organizer" right drawer with tap, double-tap (color picker), long-press drag-and-drop, and visibility via drag between Active Canvas and Available Pool zones.
* [x] Design bottom toolbar (repositioned above connection bar) with view selectors, radar, refresh, theme toggle, and version display.
* [x] Integrate dual-layered box-shadow neon glows in WebView.
* [x] Implement dark/light theme switching and SharedPreferences persistence.
* [x] Fix control card overflow — Regular card height set to 240px to fully accommodate the fade row.
* [x] Fix drawer tile layout so two Regular tiles share a row, mirroring the main canvas proportions.
* [x] Simplify settings drawer by removing open in browser and version banner, and reposition bottom toolbar (UI bar) above connection bar.
* [x] Implement compact form of Gain card (half-width) with name/size toggle, volume slider/mute toggle, and fade in/out buttons.
* [x] Map regular Gain card power settings button to toggle mute (software muting) instead of bypass.
* [x] Map ALO looper click volume slider to discrete 1-10 range in UI.
* [x] Update ALO looper record logic to send flat 1.0 at start of recording and nothing more.
* [x] Update ALO looper play/pause logic to send flat 1.0 (play) / 0.0 (pause).
* [x] Fix compilation error by restoring missing _tapTimes state field.
* [x] Compact Gain card: Fade IN/OUT buttons stacked vertically (same 110px height), mini range indicator bar beside them.
* [x] Regular Gain card: remove power button, add speaker mute icon, long-press title = rename, fixed 72px dB box, range mini-indicator in min/max row, size-toggle cycles compact→regular→expanded.
* [x] Expanded Gain card: RangeSlider for fade start/end cursors, shape selector (Linear/S1/S2/S3/Custom), custom S-curve sliders + clipboard EXPORT, live CustomPainter fade visualizer with moving dot (height 520px).
* [x] Fade engine: uses per-pedal range cursors and selected curve shape (linear/easeInOut/easeIn/easeOut/custom); tracks _fadeProgress for visualizer.
* [x] Increase card size toggle button size for better finger tap accessibility.
* [x] Reposition card size toggle button to left of card name in compact/regular/expanded views; position is stable during size changes.
* [x] Right drawer (puzzle icon) takes whole vertical height so icon is always reachable; tapping puzzle icon again closes the drawer.
* [x] Tapping reload on the UI bar resyncs all controller cards with the pedalboard (fetches current volume from server).
* [x] Fix Play Transport icon: was reversed (showing play when stop was active).
* [x] Gain card fade triangles: outline in different color; lower point on top edge of volume slider.
* [x] Expanded Gain card: fade range defined with triangles directly on the curve, no separate interface.
* [x] Fade-in and Fade-out curves reversed (Fade Out starts at 100%).
* [x] ALO Looper: pausing keeps beat in sync; pause icon changed to mute-style icon.
* [x] ALO Looper: buttons have more balanced size.
* [x] ALO Looper: tapping Click Volume toggles between 0 and current volume (mute toggle).
* [x] ALO Looper: tapping Click Mix Setting cycles 0 → 50 → 100%.
* [x] ALO Looper: tapping Threshold cycles between minimum, -40 dB, and maximum.
* [x] ALO Looper: Clear button always available to press.
* [x] Bug fix: ALO Looper Mute button caused grey screen.
* [x] ALO Looper extended: three extra buttons — On (send 1), Off (send 0), Click (send 1, wait 50ms, send 0).
* [x] Drawer icon changed to puzzle piece; tapping it again closes the drawer (no separate close button needed).
* [x] Complete modular refactoring (v1.3.0): main.dart < 60 lines; all cards, drawers, toolbars, painters, and utilities in dedicated files.
* [x] Color system: drawer tile colors always match workspace card colors; palette expanded to 10 neon colors; new plugins auto-assigned the least-used color; ALO looper treated identically to other plugins.
* [x] WiFi warning on connect: if WiFi is active when tapping Connect, an amber SnackBar warns that WiFi blocks the USB Ethernet route to MOD Dwarf and instructs the user to turn off WiFi.

### Todo Tasks (Grouped by Category)

---

## GROUP A: UI/UX Improvements (High Priority - 6 tasks)
*Complexity: Low-Medium | Est. Time: 1-2 hours | Suitable for: Simpler models*

### A1. WiFi Auto-Disable on Connect
* [x] If WiFi is on, offer to turn it off when showing the alert snackbar on connect.
* [x] Added "SETTINGS" button to WiFi warning snackbar that opens Android WiFi settings via MethodChannel.

### A2. WebView Controls Enhancement
* [ ] Add a button to reload the web view, and resize to full screen.
* [ ] Add ability to adjust the separation between the workspace and the web view.

### A3. Drawer Scroll Accuracy Fix
* [x] Tapping on a controller from the right drawer now brings the effect in view by scrolling accurately.
* [x] Improved `_scrollToCard()` to calculate accurate scroll offsets based on card dimensions and spacing.

### A4. Edit Dialog Enhancement
* [x] Editing a controller's name by long pressing its name now also allows changing its glow color.
* [x] Integrated color picker in the same rename dialog using StatefulBuilder for local state management.

### A5. Drawer Double-Tap Size Toggle
* [x] In the right drawer, double tapping a tile now cycles through sizes (compact, regular, expanded).
* [x] Non-loopers cycle C→R→E→C; loopers and inactive tiles open color picker on double-tap.

### A6. Fader Triangle Drag Speed Fix (Critical UX Bug)
* [x] Fixed: the fader scope triangle now moves at 1:1 speed with the dragging finger.
* [x] Corrected delta calculation in triangle drag handlers for responsive tracking.

---

## GROUP B: Fader/Automation Enhancements (Medium Priority - 3 tasks)
*Complexity: Medium | Est. Time: 2-3 hours | Suitable for: Intermediate models*

### B1. Double-Tap Triangle Instant Set
* [x] Double tapping on a fader scope triangle sets the gain to that level.
* [x] Added onDoubleTap handlers to both left and right triangle drag handles.
* [x] Left triangle double-tap sets gain to fade range start value.
* [x] Right triangle double-tap sets gain to fade range end value.

### B2. Beat Bar Visualization
* [ ] Add vertical Beat bar on the fading curve and the ALO play bar to make timing more visible.

### B3. Fade Transition Precision Fix
* [ ] Resolve target value landing issues when switching automation effects.
* [ ] Address fade transition errors where fade does not land exactly on 0 starting from -40dB.

---

## GROUP C: ALO Looper Improvements (Medium Priority - 3 tasks)
*Complexity: Medium-High | Est. Time: 2-3 hours | Suitable for: Intermediate models*

### C1. ALO Extended Mode Redesign
* [ ] In Alo extended, on/off/click buttons should target the active looper. One timeline + 6 buttons; tabs above (one per Looper 1–6) showing play/pause state icon.

### C2. ALO Regular Mode Implementation
* [ ] ALO Regular Mode: quick selector of current looper, small playing bar (recording or playing), and Record / Mute / Clear buttons.

### C3. Threshold Label Fix
* [x] In ALO Regular: threshold label should stay on one line at fixed size (currently jumps between 1 and 2 lines depending on dB value).
* [x] Added `isThresholdLabel` parameter to `_buildLooperSlider()` function.
* [x] Applied `maxLines: 1` and `TextOverflow.ellipsis` to threshold label when flag is true.
* [x] Threshold label now maintains consistent single-line display regardless of dB value.

---

## GROUP D: Data Persistence (High Priority - 1 task)
*Complexity: High | Est. Time: 3-4 hours | Suitable for: Advanced models*

### D1. Local Database for Pedalboard Configurations
* [ ] Save in a local database the different configuration made for the application (by pedalboard name, as I could switch from a pedalboard to another).

---

## GROUP E: Code Quality/Technical Debt (Low Priority - 2 tasks)
*Complexity: Low-Medium | Est. Time: 1-2 hours | Suitable for: Simpler models*

### E1. setInterval Cleanup
* [x] Store setInterval IDs in an external array for clean automation cancellation.
* [x] Created `activeIntervals` global array to track all setInterval IDs.
* [x] Implemented `registerInterval(id)` function to add intervals to tracking array.
* [x] Implemented `clearAllIntervals()` function to cleanly cancel all active intervals.
* [x] Updated both setInterval calls to register their IDs for later cleanup.

### E2. Default Fadeout Values
* [ ] Map default values for fadeout objects to minimize boilerplate definitions.

---

## GROUP F: Future Enhancements (Low Priority - 9 tasks)
*Complexity: Varies | Est. Time: Varies | Suitable for: Advanced models*

### F1. Link Maximum Period to Host BPM
* [ ] Link maximum period length to host BPM (e.g. 2 times 4 bars).

### F2. Optimize Keystroke Handlers
* [ ] Optimize keystroke handlers inside `TamperMod.user.js` to prevent thread blocking.

### F3. Standardize Background-Position Shifts
* [ ] Standardize background-position shifts to match exact knob image heights.

### F4. Verify Asset Knob GIFs
* [ ] Verify that all asset knob GIFs have identical frame-step sizes.

### F5. Pause All Automations Gesture
* [ ] Implement key gesture to pause all active automations instantly.

### F6. Pedalboard Presets
* [ ] Add pedalboard presets to store configuration profiles in local browser memory.

### F7. Cross-Fader Transitions
* [ ] Build cross-fader transitions to toggle between two Gain channels.

### F8. Graphical UI for Button Links
* [ ] Build a graphical UI inside the web view to configure button links directly.

### F9. MIDI CC Command Mapping
* [ ] Map midi CC commands directly to web interface parameters.

---

## Completed Tasks (v1.3.2 and earlier)
* [x] Initialize baseline Flutter controller project setup.
* [x] Create base Tampermonkey injection script structure.
* [x] Implement dynamic BPM value reflection in the Flutter UI.
* [x] Map `pedals_families` object parameters to volume controls.
* [x] Implement dual-track ALO Looper UI with volume/mix/threshold sliders.
* [x] Create "Puzzle Organizer" right drawer with tap, double-tap (color picker), long-press drag-and-drop, and visibility via drag between Active Canvas and Available Pool zones.
* [x] Design bottom toolbar (repositioned above connection bar) with view selectors, radar, refresh, theme toggle, and version display.
* [x] Integrate dual-layered box-shadow neon glows in WebView.
* [x] Implement dark/light theme switching and SharedPreferences persistence.
* [x] Fix control card overflow — Regular card height set to 240px to fully accommodate the fade row.
* [x] Fix drawer tile layout so two Regular tiles share a row, mirroring the main canvas proportions.
* [x] Simplify settings drawer by removing open in browser and version banner, and reposition bottom toolbar (UI bar) above connection bar.
* [x] Implement compact form of Gain card (half-width) with name/size toggle, volume slider/mute toggle, and fade in/out buttons.
* [x] Map regular Gain card power settings button to toggle mute (software muting) instead of bypass.
* [x] Map ALO looper click volume slider to discrete 1-10 range in UI.
* [x] Update ALO looper record logic to send flat 1.0 at start of recording and nothing more.
* [x] Update ALO looper play/pause logic to send flat 1.0 (play) / 0.0 (pause).
* [x] Fix compilation error by restoring missing _tapTimes state field.
* [x] Compact Gain card: Fade IN/OUT buttons stacked vertically (same 110px height), mini range indicator bar beside them.
* [x] Regular Gain card: remove power button, add speaker mute icon, long-press title = rename, fixed 72px dB box, range mini-indicator in min/max row, size-toggle cycles compact→regular→expanded.
* [x] Expanded Gain card: RangeSlider for fade start/end cursors, shape selector (Linear/S1/S2/S3/Custom), custom S-curve sliders + clipboard EXPORT, live CustomPainter fade visualizer with moving dot (height 520px).
* [x] Fade engine: uses per-pedal range cursors and selected curve shape (linear/easeInOut/easeIn/easeOut/custom); tracks _fadeProgress for visualizer.
* [x] Increase card size toggle button size for better finger tap accessibility.
* [x] Reposition card size toggle button to left of card name in compact/regular/expanded views; position is stable during size changes.
* [x] Right drawer (puzzle icon) takes whole vertical height so icon is always reachable; tapping puzzle icon again closes the drawer.
* [x] Tapping reload on the UI bar resyncs all controller cards with the pedalboard (fetches current volume from server).
* [x] Fix Play Transport icon: was reversed (showing play when stop was active).
* [x] Gain card fade triangles: outline in different color; lower point on top edge of volume slider.
* [x] Expanded Gain card: fade range defined with triangles directly on the curve, no separate interface.
* [x] Fade-in and Fade-out curves reversed (Fade Out starts at 100%).
* [x] ALO Looper: pausing keeps beat in sync; pause icon changed to mute-style icon.
* [x] ALO Looper: buttons have more balanced size.
* [x] ALO Looper: tapping Click Volume toggles between 0 and current volume (mute toggle).
* [x] ALO Looper: tapping Click Mix Setting cycles 0 → 50 → 100%.
* [x] ALO Looper: tapping Threshold cycles between minimum, -40 dB, and maximum.
* [x] ALO Looper: Clear button always available to press.
* [x] Bug fix: ALO Looper Mute button caused grey screen.
* [x] ALO Looper extended: three extra buttons — On (send 1), Off (send 0), Click (send 1, wait 50ms, send 0).
* [x] Drawer icon changed to puzzle piece; tapping it again closes the drawer (no separate close button needed).
* [x] Complete modular refactoring (v1.3.0): main.dart < 60 lines; all cards, drawers, toolbars, painters, and utilities in dedicated files.
* [x] Color system: drawer tile colors always match workspace card colors; palette expanded to 10 neon colors; new plugins auto-assigned the least-used color; ALO looper treated identically to other plugins.
* [x] WiFi warning on connect: if WiFi is active when tapping Connect, an amber SnackBar warns that WiFi blocks the USB Ethernet route to MOD Dwarf and instructs the user to turn off WiFi.
* [x] Fix drawer tile color: must always match the workspace card color (all plugins treated equally — no type-specific default overrides).
* [x] Expand neon color palette from 5 to 10 colors for more variety.
* [x] When a new plugin is added with no saved color, auto-assign the least-used color from the palette.
