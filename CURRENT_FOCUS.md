# TamperMod — Current Focus

## ✅ Completed (v1.3.91)
- **Pedal Search Exploration Mode & Smart Hover Positioning**:
  1. **Permanent Hover in Search Mode**: When Pedal Search is ON, the hover tooltip stays permanent while exploring across pedals.
  2. **Touch/Event Shield in Search Mode**: When Pedal Search is ON, default MOD GUI interactions (zooming, opening edit windows, dragging cables) are blocked to prevent accidental UI changes, while tapping a pedal triggers the 5-second synchronized flash strobe.
  3. **Auto-Disappearing Tooltip when Search is OFF**: When Pedal Search is OFF, hover tooltip disappears after 2.5 seconds to avoid obstructing regular pedal tweaking, and standard MOD GUI touch events are fully enabled.
  4. **Sub-Pedal Tooltip Placement**: Tooltip is positioned directly below the pedal visual (`rect.bottom + 8px`, horizontally centered) so it never blocks the pedal graphics.

## ✅ Completed (v1.3.90)
- **Eliminate Sub-Pixel Horizontal Overflows in Compact Tiles**:
  1. Wrapped compact (`C`) puzzle tile contents in `FittedBox(fit: BoxFit.scaleDown)` and tuned padding (`horizontal: 2.0`) so that even on narrow 4-column organizer panels, tiles scale smoothly and will never produce sub-pixel overflow banners.

## 📋 Remaining Tasks
- **A2. WebView Controls**: WebView full-screen toggle, separation layout adjustment.
- **E2. Default Fadeout Values**: Mapping default values for fader/automation objects.

## 🔧 Quick Context
- **App Version:** v1.3.91
- **Last commit:** Gemini3.7Flash(v1.3.91) - Permanent exploration hover in search mode, event shielding, auto-fade when search off, and sub-pedal tooltip placement
- **Architecture:** Flutter app in `mod_controller/` with modular card-based UI

