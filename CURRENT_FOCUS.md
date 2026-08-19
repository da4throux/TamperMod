# TamperMod — Current Focus

## ✅ Completed (v1.3.50)
- **Fix Unbounded Layout Crash in GainCard Expanded View**:
  1. Removed `Spacer()` inside `GainCard._buildExpandedView` which caused a fatal Flutter RenderFlex exception (`RenderFlex children have non-zero flex but incoming height constraints are unbounded`) when `cardHeight = null` in the Expanded card size, causing the black screen freeze.
  2. Hardened `VectorBezierCurve` mathematical solver against NaN propagation and infinite loops.

## ✅ Completed (v1.3.49)
- **Top AppBar View Selectors & Controls Auto-Populate**:
  1. Added View Mode Chips (`TILES | SPLIT | WEB`) directly into the top AppBar for instant 1-click view switching.
  2. Auto-populates active tiles list with all discovered plugins if custom order is empty, preventing black/blank screens.
  3. Added view-mode fallback guards in `_buildBodyContent`.

## 📋 Remaining Tasks
- **A2. WebView Controls**: WebView full-screen toggle, separation layout adjustment.
- **E2. Default Fadeout Values**: Mapping default values for fader/automation objects.

## 🔧 Quick Context
- **App Version:** v1.3.50
- **Last commit:** Gemini3.7Flash(v1.3.50) - Fix unbounded Spacer in GainCard expanded view
- **Architecture:** Flutter app in `mod_controller/` with modular card-based UI
