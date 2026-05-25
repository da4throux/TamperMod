# TamperMod — Current Focus

## ✅ Completed (v1.3.27)
- **Advanced Discovery Robustness**: Fixed Backbone/DOM metadata scraping to extract name and label and defensively support plain objects, and updated updatePluginMetadata to automatically rename cards.
- **WebSocket param_set Support**: Added support for both space-separated and slash-separated parameter commands.
- **Optimistic State Sliders**: Made generic sliders smoothly movable by updating local state optimistically.
- **Compact Card Customization**: Added Compact Card checklist selector in Expanded view and scrollable list of selected parameters inside the Compact Card.

## ✅ Completed (v1.3.26)
- **Grid Layout Customization**: Spacer cards (compact/regular/expanded) in active canvas to align grid elements.
- **ALO Card Standardization**: Standardized sizes and gestures for ALO loopers in settings drawer (size indicators, double-tap size cycle).

## 📋 Remaining Tasks
- **A2. WebView Controls**: WebView full-screen toggle, separation layout adjustment.
- **E2. Default Fadeout Values**: Mapping default values for fader/automation objects.

## 🔧 Quick Context
- **App Version:** v1.3.27
- **Last commit:** Gemini3.5Flash(v1.3.27) - Make generic discovery robust with title renaming, fader optimistic updates, and compact card parameters selector
- **Architecture:** Flutter app in `mod_controller/` with modular card-based UI
