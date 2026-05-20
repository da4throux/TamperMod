# Specification Blueprint: TamperMod

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
  * **Compact (C):** Compact card (height: 90) representing minimal parameters.
  * **Regular (R):** Standard card (height: 220) with common sliders and switches.
  * **Expanded (E):** Fully expanded card (height: 320) with inline title edits and detailed sliders.
  * *ALO Loopers default to Expanded.*

### 3.2 Puzzle Organizer Settings Drawer
* scale-down grid layout representing workspace cards.
* Supports **Drag-and-Drop** to rearrange cards.
* Interactive gestures:
  * **Single Tap:** Scrolls main view to and pulses the target card.
  * **Double Tap:** Opens a color picker to adjust the neon glow color of the card.
  * **Long Press:** Initiates Drag-and-Drop to rearrange cards (active/inactive status is changed by dragging cards between the Active canvas and the Inactive pool).

### 3.3 Bottom Navigation Bar
* Following functionalities:
  * Layout view selectors (Split, Controls, Web).
  * Radar locate trigger button.
  * Refresh/Reload pedalboard trigger.
  * Light/Dark Theme toggle with SharedPreferences persistence.
  * Current version info display (`v1.1.2+12`).

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
* [x] Create "Puzzle Organizer" right drawer layout with tap, double-tap, long-press, and drag-and-drop.
* [x] Design sticky bottom navigation bar and simplify connection panel next to IP.
* [x] Integrate dual-layered box-shadow neon glows in WebView.
* [x] Implement dark/light theme switching and SharedPreferences persistence.

### Todo Tasks
* [ ] Fix fadeout issues when running under `fade` mode in the Tampermonkey script.
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