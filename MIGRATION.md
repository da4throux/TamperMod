# MOD Dwarf Live Controller - Flutter Migration Project

## 🎯 Project Overview
This project is migrating a legacy JavaScript Tampermonkey script (`TamperMod`) into a native, stage-ready Android Flutter app. The app acts as a live, multi-touch remote control for a MOD Dwarf guitar pedal.

We are completely abandoning DOM-scraping and UI-clicking. Instead, the Flutter app will communicate directly with the pedal's internal audio engine using WebSockets and JSON-RPC 2.0.

## 🏗 Core Architecture & Guidelines
1. **Connection:** The Android phone (Pixel 10 Pro) will connect to the MOD Dwarf via WiFi or a direct USB cable (USB Ethernet routing). The Dwarf's IP is `192.168.51.1`.
2. **Communication:** Use the `web_socket_channel` package to connect to `ws://192.168.51.1/v2/websocket`.
3. **No Backend:** This is a purely client-side Flutter app. Do not build a Node.js server.
4. **Data Protocol:** The Dwarf only understands strict JSON-RPC 2.0. To change *any* parameter (volume, looper state), send this exact payload structure:
   ```json
   {
     "jsonrpc": "2.0", 
     "method": "set_param_value", 
     "params": {
       "instance": "/graph/Gain_1", 
       "port": "Gain", 
       "value": -12.5
     }
   }
   ```
5. **Stage-Ready UI:** The app must be locked into fullscreen (hiding the Android status bar) and utilize `wakelock_plus` to prevent the screen from sleeping during a live performance.

---

## 🔍 Legacy Code Analysis (TamperMod JS -> Flutter Dart)

The old `TamperMod` script contains highly valuable musical logic (beat syncing, volume ramping). The AI agent must extract this math/logic while discarding the old DOM-manipulation hacks.

### 1. The Clock & Transport
* **Old Way (`getBPM()`):** Scraped the HTML DOM (`mod-transport-icon`) using regex to find the BPM.
* **New Way:** The WebSocket server broadcasts transport changes automatically. Listen to the `web_socket_channel` stream for incoming transport JSON messages, extract the BPM/Beat, and update the Flutter App State.

### 2. Beat-Synced Looping (ALO Looper)
* **Old Way (`updatePadBeat(pad)`, `startLoop()`, `cleanLoop()`):** Used `setTimeout`, calculated beat proximity, and literally triggered `.click()` events on the `pad.button` HTML elements.
* **New Way:** Keep the brilliant math that calculates `totalBeat`, `pad.positionBar`, and `pad.positionBeat`. However, instead of `pad.button.click()`, fire a WebSocket JSON-RPC message targeting the looper instance (e.g., `instance: "/graph/alo_2"`, `port: "loop1"`, `value: 1.0`).

### 3. Automated Volume Curves (Continuos)
* **Old Way (`actionLoop()`, `goThroughContinuos()`, `updateVolumes()`):** Calculated `stepsToTarget` based on a JavaScript `setInterval`, then triggered fake mouse drag events (`moveMouse()`, `simulateMouseEvent()`) to visually turn the knobs on the web GUI.
* **New Way:** Keep the `targetVolume`, `targetSlope`, and `continuo` logic that calculates *what* the volume should be at a given millisecond. Discard all mouse simulation. Instead, use a Dart `Ticker` or `Timer.periodic` to push the exact calculated dB value directly to the WebSocket.

### 4. User Interaction
* **Old Way (`setEventListeners()`):** Listened for physical keystrokes (`KeyA`, `Space`, `Period`) via `document.addEventListener('keydown')`.
* **New Way:** Replace the keyboard map with a grid of massive, high-contrast Flutter UI buttons. Use `GestureDetector` to handle touch events (e.g., `onTap`, `onLongPress`).

---

## 🚀 Implementation Phases for the AI Agent

**Phase 1: Foundation & Networking**
* Scaffold the Flutter app with `web_socket_channel` and `wakelock_plus`.
* Enforce fullscreen mode.
* Create a `ModWebSocketService` class that handles connecting, reconnecting, and sending the JSON-RPC formatted payloads.

**Phase 2: UI Prototyping**
* Build a simple grid layout.
* Create a test button that sends a `1.0` state change to `instance: "/graph/alo_2"`, `port: "loop1"`.
* Create a vertical slider that sends volume values (-60dB to +4dB) to `instance: "/graph/Gain_1"`, `port: "Gain"`.

**Phase 3: Logic Migration**
* Port the `updatePadBeat()` math into Dart to recreate the beat-synced looping.
* Port the `goThroughContinuos()` math into Dart to recreate the automated volume swells.