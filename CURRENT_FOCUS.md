# TamperMod — Current Focus

## ✅ Completed (v1.3.83)
- **Reliable Puzzle Board Tile-to-Card Scroll Navigation**:
  1. Replaced broken row-index math calculation in `_scrollToCard` with Flutter's native `Scrollable.ensureVisible` using a dynamic `GlobalKey` registry (`_cardKeys`).
  2. Reliably scrolls the dashboard cards list to bring any clicked tile into view, cleanly handling line breaks, spacers, compact/regular/expanded cards, and dynamic-height cards (such as ALO loopers).

## ✅ Completed (v1.3.82)
- **Compact Inactive Pool Hugging & Global `Ctrl+V` JSON Configuration Restore**:
  1. **Tight Inactive Pool Height**: Inactive pool hugs content tightly (max 155px with scroll) and active puzzle canvas takes 100% of remaining screen space with zero gap.
  2. **Global `Ctrl+V` Shortcut**: Pressing `Ctrl+V` (or `Cmd+V`) inspects clipboard for valid TamperMod JSON, prompts confirmation, and restores configurations immediately.

## ✅ Completed (v1.3.81)
- **Ctrl+S Backup Shortcut & Puzzle Board Real-time Placement / Foldable Pool**:
  1. **Global `Ctrl+S` / `Cmd+S` Shortcut**: Pressing Ctrl+S instantly copies backup JSON to clipboard with a confirmation toast.
  2. **Live Drag Placement from Inactive Pool**: Dragging an inactive tile over active canvas previews placement in real time.
  3. **Foldable Inactive Pool**: Tapping header collapses/expands the available pool.

## 📋 Remaining Tasks
- **A2. WebView Controls**: WebView full-screen toggle, separation layout adjustment.
- **E2. Default Fadeout Values**: Mapping default values for fader/automation objects.

## 🔧 Quick Context
- **App Version:** v1.3.83
- **Last commit:** Gemini3.7Flash(v1.3.83) - Reliable Scrollable.ensureVisible navigation on puzzle tile tap
- **Architecture:** Flutter app in `mod_controller/` with modular card-based UI
