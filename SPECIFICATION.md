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
* [x] Reposition card size toggle button to left of card name in compact view.
* [x] Reposition card size toggle button to left of card name in regular view.
* [x] Reposition card size toggle button to left of card name in expanded view.
* [x] Ensure card size toggle button position remains stable during card size changes.

### Todo Tasks
* [x] While clicking on the top right puzzle icon opens the controler layout drawer on the right side, I should be able to tap on it again to close the drawer, however, it appears fade in the background, and cannot be reached... Can you make this right drawer take the whole vertical, on the puzzle icon is always visible in this way.
* [x] Tapping reload on the UI bar (next to radar) should resync all the controler cards with the pedal board. If I change the volume of a gain directly on the pedalboard, it does not update on its control card, while having a regular polling could be a solution, as first step the reload should resync and fetch the new volume.
* [x] The Play Transport is not well fetched (shown as play when is stop in the pedalboard* [x] The Play Transport is well fetched and updated but the icon is reversed (showing play when it is actually stop that was selected)
* [x] For Gain controller, the fade triangles should have an outline (different color than the glow), the lower point of the triangle should be on the top edge of the volume slider (not in the middle of the slider)
* [x] For Gain Controler, in extended mode, the fade range should be defined with triangles, no need for a separate interface
* [x] The Fade-in and Fade-out curves should be reversed (starting at 100% for a Fade Out)
* [x] In Alo Looper, when pausing, the beat should continue, and stay in sync. Change Pausing icon to something closer to muting.
* [x] In ALO looper, the buttons should have more balanced size
* [x] In Alo looper, tapping Click Volume toggles to 0 and the current volume (kind of a mute)
* [x] In Alo looper, tapping Click Mix Setting toggles between 0, 50, and 100%
* [x] In Alo looper, tapping Threshold toggles betwen the minimu, -40dB and the maximum
* [ ] Please add a button to reload the web view
* [x] In Alo looper, the clear button should always be available to press
* [x] Bug: In Alo looper, pressing Mute made a grey screen.
* [x] In Alo looper extended, add three buttons: on (send a 1), off (send a 0), click (send a 1, wait 50ms and send a 0)
* [ ] tapping on a controler from the right drawer does not always bring the effect in view by scrolling accurately.
* [ ] Editting a controler s name by long pressing its name should also allow to change its glow. Then in the right drawer, double tapping a small type toggle its size (available: compact, regular, extended). ALO Looper glow is counted twice.
* [x] changing the icon to open the drawer to a puzzle (better than setting), remove "workspace settings, from the top. Re-taping the new puzzle icon close the drawer.
* [x] The same puzzle icon which is used to open the drawer, can be tap again when the drawer is open to clos it, no need for the cross in the top right corner of the drawer. the drawer.
* [ ] bug: the fader scope triangle, do not move as fast the finger dragging it (it runs half the length, which is unpleasant)
* [ ] double tapping on a fader scope triangle, set the gain to that level
* [ ] Add vertical Beat bar on the fading curve, and the alo play to make it more visible
* [ ] In Alo extended, there was a misunderstanding for on/off/click buttons, They should be focused on the active looper. (turn the looper button 1, off, and on / off). There should be only one timeline and buttons set (6 buttons) displayed, and above a tab for each Looper (from 1 to 6), to display the timeline and the concerned buttons. A tab should display a specific icon if is playing, or on pause.
* [ ] Alo in Regular Mode: quick selector of the current looper, small playing bar (for recording or playing), and record / mute / clear buttons
* [ ] Resolve target value landing issues when switching automation effects.
* [ ] Address fade transition errors where fade does not land exactly on 0 starting from -40dB.
* [ ] Store setInterval IDs in an external array for clean automation cancellation.
* [ ] Map default values for fadeout objects to minimize boilerplate definitions.
* [ ] Link maximum period length to host BPM (e.g. 2 times 4 bars).
* [ ] Optimize keystroke handlers inside `TamperMod.user.js` to prevent thread blocking.
* [ ] Standardize background-position shifts to match exact knob image heights.
* [ ] Verify that all asset knob GIFs have identical frame-step sizes.
* [ ] Implement key gesture to pause all active automations instantly.
* [ ] Add pedalboard presets to store configuration profiles in local browser memory.
* [ ] Build cross-fader transitions to toggle between two Gain channels.
* [ ] Build a graphical UI inside the web view to configure button links directly.
* [ ] Map midi CC commands directly to web interface parameters.