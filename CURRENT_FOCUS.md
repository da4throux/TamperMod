# TamperMod — Current Focus

## ✅ Completed (v1.3.92)
- **Interactive Sub-Pedal Hover Name Tag with Status Badge & Click-to-Locate**:
  1. **Removed Global Search Toggle**: Removed the `[ PEDAL SEARCH ]` toggle button in favor of an intuitive, direct hover and tag click interaction.
  2. **Interactive Sub-Pedal Tag**: Hovering over any pedal shows the name tag positioned right below the pedal visual (`rect.bottom + 6px`). Moving the cursor onto the tag keeps it permanently visible and interactive.
  3. **Placement Status Badges**: Displays `🧩 PLACED` (cyan) if the pedal is active on the dashboard, or `📦 AVAILABLE POOL` (amber) if it is currently in the inactive pool.
  4. **Click-to-Locate on Hover Tag**: Clicking the interactive tag prevents propagation to the webboard underneath and triggers the 5-second synchronized blinking strobe on the physical pedal, dashboard card, and puzzle tile, auto-scrolling the card into view.
  5. **Card Radar Focus Button**: Tapping the card radar button triggers the 5-second strobe blink on the physical pedal and puzzle tile without scrolling the dashboard list.
  6. **Clean Tile Board Tap**: Simple taps on mini puzzle tiles no longer trigger scrolling adjustments or blinking strobes.
  7. **Connection Failure Advice & One-Tap Copy**: Disconnected view provides troubleshooting advice and one-tap copy buttons for the Android network refresh command (`adb shell "svc wifi disable; sleep 1; svc wifi enable"`) and Crostini bridge script (`./scripts/bridge_dwarf.sh`).

## 📋 Remaining Tasks
- **A2. WebView Controls**: WebView full-screen toggle, separation layout adjustment.
- **E2. Default Fadeout Values**: Mapping default values for fader/automation objects.

## 🔧 Quick Context
- **App Version:** v1.3.92
- **Last commit:** Gemini3.7Flash(v1.3.92) - Interactive sub-pedal hover name tag with status badge, click-to-locate, card target without scrolling, and copyable connection fix commands
- **Architecture:** Flutter app in `mod_controller/` with modular card-based UI
