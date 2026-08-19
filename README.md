# TamperMod - MOD Dwarf Live Remote Controller
please read and apply .agentrules

A native Flutter application for controlling the MOD Dwarf guitar pedal board in real-time during live performances. Replaces the legacy Tampermonkey script with a modern, stage-ready Android app.

## 🎯 Overview

**TamperMod** is a multi-touch remote control for the MOD Dwarf pedalboard, optimized for the Pixel Tablet. It communicates directly with the MOD Dwarf via WebSocket (JSON-RPC 2.0), eliminating DOM scraping and providing responsive, low-latency control.

- **Hardware Target:** Pixel Tablet (portrait & landscape)
- **Connection:** WiFi to MOD Dwarf (`192.168.51.1`)
- **Protocol:** WebSocket JSON-RPC 2.0
- **Current Version:** `1.3.58`

## 🏗 Architecture

### Components

1. **Flutter Controller** (`mod_controller/`)
   - State management for plugin instances, looper tracks, and parameter values
   - WebSocket service for real-time communication with MOD Dwarf
   - Responsive UI with neon glow effects and dual-layered highlights
   - Puzzle Organizer drawer for card visibility and reordering

2. **Tampermonkey Script** (`TamperMod.user.js`)
   - Injects visual highlights and glow overlays on the MOD Dwarf web GUI
   - Handles browser-side automation and visual feedback
   - Supports fade transitions and beat-synced looping

### Data Flow

```
Flutter App (Pixel Tablet / Chromebook ARC)
    ↓ (WebSocket JSON-RPC)
MOD Dwarf (192.168.51.1 / 100.115.92.201)
    ↓ (WebSocket broadcast)
Flutter App (parameter updates, BPM, transport)
    ↓ (JavaScript injection)
Tampermonkey Script (visual highlights on web GUI)
```

## 🎮 Key Features

### Workspace Dashboard
- **Dynamic Grid Layout:** Scrollable `Wrap` widget with custom control cards
- **Card Types:**
  - **Compact (C):** Minimal parameters (height: 240, customizable controls list for generic cards)
  - **Regular (R):** Standard sliders & switches (height: 240, 2 per row)
  - **Expanded (E):** Full-width detailed controls (height: 240)
  - **ALO Looper:** Full-width looper tracks (height: 450)

### Puzzle Organizer Drawer
- **Drag-and-Drop:** Reorder cards within Active Canvas or move to Available Pool
- **Gestures:**
  - Single Tap: Scroll main view to card and pulse highlight
  - Double Tap: Open color picker for neon glow customization
  - Long Press: Initiate drag-and-drop

### Bottom Toolbar
- Layout view selectors (Controls, Web, Split)
- Radar locate trigger (pulses all active pedal glows)
- Refresh/Reload pedalboard
- Light/Dark theme toggle (persisted)
- Version info display

### Visual Effects
- **Dual-Layered Glow:** Tight neon glow + wide ambient halo
- **Inset Glow:** Highlights on control knobs
- **Neon Color Palette:** Turquoise, Pink, Purple, Green, Orange

## 🚀 Getting Started

### Prerequisites
- Flutter SDK (latest stable)
- Android SDK / Pixel Tablet or Chromebook with Android (ARCVM) enabled
- MOD Dwarf connected via USB or Wi-Fi network

### Installation & Deployment

1. Clone the repository:
   ```bash
   git clone https://github.com/da4throux/TamperMod.git
   cd TamperMod
   ```

2. Install Flutter dependencies:
   ```bash
   cd mod_controller
   flutter pub get
   ```

3. Deploying to Devices:

   - **Target A: Pixel Tablet (Primary Target)**
     1. Enable USB or Wireless Debugging on the tablet.
     2. Verify connection: `adb devices`
     3. Deploy:
        ```bash
        flutter run -d <tablet_device_id>
        ```

   - **Target B: Chromebook Android Subsystem (Hatch / ARCVM)**
     1. In ChromeOS Settings → Developers → Develop Android apps → Enable ADB debugging.
     2. Connect ADB to ARC container:
        ```bash
        adb connect arc
        # or adb connect 100.115.92.2:5555
        ```
     3. Start the MOD Dwarf USB bridge (forwards `192.168.51.1:80` to Crostini `100.115.92.201:80`):
        ```bash
        ./scripts/bridge_dwarf.sh
        ```
     4. Launch the app on Hatch:
        ```bash
        flutter run -d arc:5555
        ```
     5. In the TamperMod app IP bar, enter `100.115.92.201` and tap **CONNECT**.

### Tampermonkey Setup

1. Install Tampermonkey browser extension
2. Create a new script and paste the contents of `TamperMod.user.js`
3. Navigate to `http://moddwarf.local/` to activate the script

## 📋 Project Structure

```
TamperMod/
├── mod_controller/              # Flutter application
│   ├── lib/
│   │   ├── main.dart           # Main app & dashboard
│   │   ├── models/
│   │   │   ├── plugin_instance.dart
│   │   │   ├── parameter_metadata.dart
│   │   │   └── module_help_data.dart
│   │   └── services/
│   │       ├── websocket_service.dart
│   │       └── looper_controller.dart
│   ├── pubspec.yaml            # Dependencies & version
│   └── ...
├── scripts/
│   └── bridge_dwarf.sh         # ChromeOS ARC network bridge helper
├── TamperMod.user.js           # Tampermonkey injection script
├── SPECIFICATION.md            # Architecture & UI/UX rules
├── CURRENT_FOCUS.md            # Agent handoff document
├── .agentrules                 # Agent operational protocols
└── README.md                   # This file
```

## 🔧 Development

### Version Management

The app uses strict atomic versioning:
- Update `mod_controller/lib/main.dart`: `const String kAppVersion = 'X.Y.Z';`
- Update `mod_controller/pubspec.yaml`: `version: X.Y.Z`
- Both must match the git commit tag

### Git Commit Protocol

- **Micro-Saves (vX.Y.Z):** After implementing a working feature or bug fix
  ```bash
  git commit -m "agent(vX.Y.Z): [brief description]"
  ```
- **Milestones (vX.Y.0):** Requires user authorization for major feature blocks

### Documentation

- **SPECIFICATION.md:** Source of truth for architecture, UI rules, and feature progress
- **CURRENT_FOCUS.md:** Handoff document for multi-agent sessions
- **.agentrules:** Operational protocols for agents

## 📝 Current Todo

See `SPECIFICATION.md` §4 for the complete feature roadmap. Current priorities:

- [ ] Fix fadeout issues in `fade` mode (Tampermonkey script)
- [ ] Resolve target value landing when switching automation effects
- [ ] Address fade transition errors from -40dB
- [ ] Store setInterval IDs for clean automation cancellation
- [ ] Map default values for fadeout objects
- [ ] Link maximum period length to host BPM
- [ ] Optimize keystroke handlers to prevent thread blocking
- [ ] Standardize background-position shifts for knob images
- [ ] Verify all asset knob GIFs have identical frame-step sizes
- [ ] Implement key gesture to pause all active automations
- [ ] Add pedalboard presets (local browser memory)
- [ ] Build cross-fader transitions for dual Gain channels
- [ ] Build graphical UI for button link configuration
- [ ] Map MIDI CC commands to web interface parameters

## 🎵 Hardware Info

- **MOD Dwarf:** https://www.moddevices.com/
- **ALO Looper:** https://github.com/devcurmudgeon/alo
- **WebSocket Protocol:** MOD Dwarf proprietary (space-separated commands)

## 📄 License

Personal project. For more information, see the original repository.

## 👤 Author

**da4throux** — Developed for live performance control of the MOD Dwarf pedalboard.

---

**Last Updated:** v1.3.28 (May 2026)
