# TamperMod — Current Focus

## ✅ Completed (v1.3.42)
- **Immediate Dashboard Re-rendering on Puzzle Organizer Reorder**: Added missing `setState` call to `onLayoutSettingsChanged` in `DashboardScreen`, ensuring the main canvas immediately updates and reflects drag-and-drop reordering from the Puzzle Organizer panel in real-time.

## ✅ Completed (v1.3.41)
- **Configurable Dual Switch Layouts (2-Path Route & Clean On/Off Toggle)**: Added support for two distinct switch tile layouts:
  1. **2-Path Route Mode**: Dual interactive pills displaying custom labels for Path A (Down/0) and Path B (Up/1) with active highlight.
  2. **Clean On/Off Toggle Mode**: Prominent bold name with elegant status badge (`[ ● ON ]` / `[ ○ OFF ]`) and full card ambient glow, with no oversized toggle icon.
  - Added dedicated **Switch Settings Dialog** (pen button/long-press) to configure Layout Mode, Path A/B names, Active State definition (Normal 1=ON vs Inverted 0=ON), Title, and Glow Color with persistent storage.

## 📋 Remaining Tasks
- **A2. WebView Controls**: WebView full-screen toggle, separation layout adjustment.
- **E2. Default Fadeout Values**: Mapping default values for fader/automation objects.

## 🔧 Quick Context
- **App Version:** v1.3.42
- **Last commit:** Gemini3.7Flash(v1.3.42) - Immediate dashboard re-rendering on puzzle organizer reorder
- **Architecture:** Flutter app in `mod_controller/` with modular card-based UI
