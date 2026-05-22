# Implementation Plan: Advanced Discovery (Generic/Custom Cards for Unrecognized Devices)

This plan details the implementation of **Advanced Discovery** for unrecognized devices. When a new device is present on the pedalboard network that does not map to a hardcoded card type (like ALO Looper, Switch, or Gain), the application will dynamically render a fully-functional control card.

## User Review Required

> [!IMPORTANT]
> **Dynamic Metadata Scraping via WebView**:
> - **Mechanism**: Because the MOD Dwarf WebSocket broadcast only transmits current values and does not output parameter metadata (min, max, step, names), we inject a scraping script into the WebView.
> - **Double-Buffered Sync**: The scraper runs Backbone collection queries as a primary method and DOM scraping as a secondary fallback. It transfers the metadata back to the Flutter host via a new `DiscoveryChannel` Javascript channel.
> - **Automatic Refresh**: The scraper evaluates every 3 seconds and on page load, keeping control ranges up-to-date in real-time.

> [!NOTE]
> **Customizable Regular Card Layouts**:
> - In **Expanded mode**, a parameter checklist is displayed. Tapping a checkbox toggles the visibility of that specific parameter inside the device's customized **Regular card** layout.
> - Unconfigured devices default to displaying all parameters in their Regular card so that they are immediately usable.
> - Customized layouts are stored in SharedPreferences under the current layout configuration key, meaning they are fully preserved across reboots, duplication, and backups.

---

## Open Questions

None. The Backbone.js / DOM scraping fallback in the WebView provides reliable access to parameter metadata without modification to the MOD Dwarf firmware.

---

## Proposed Changes

### Data Models & Metadata Caching

#### [NEW] [parameter_metadata.dart](file:///c:/Users/damie/Dev/TamperMod/mod_controller/lib/models/parameter_metadata.dart)
- Define a model `ParameterMetadata` to represent control ranges:
  - `symbol` (String)
  - `name` (String)
  - `min` (double)
  - `max` (double)
  - `step` (double)
  - `isToggle` (bool)

#### [MODIFY] [plugin_instance.dart](file:///c:/Users/damie/Dev/TamperMod/mod_controller/lib/models/plugin_instance.dart)
- Import `parameter_metadata.dart`.
- Add a cached metadata container:
  ```dart
  final Map<String, ParameterMetadata> parameterMetadata = {};
  ```

---

### Communication & State Synchronization

#### [MODIFY] [websocket_service.dart](file:///c:/Users/damie/Dev/TamperMod/mod_controller/lib/services/websocket_service.dart)
- Add a method `updatePluginMetadata(String instance, List<ParameterMetadata> metadataList)`:
  - Find the plugin matching `instance`.
  - Clear and update its `parameterMetadata` map.
  - Trigger `notifyListeners()` to rebuild card widgets.

---

### Dashboard Controller Integration

#### [MODIFY] [dashboard_screen.dart](file:///c:/Users/damie/Dev/TamperMod/mod_controller/lib/screens/dashboard_screen.dart)
- Add state to track checked parameters:
  ```dart
  final Map<String, List<String>> _customCardVisibleParams = {};
  ```
- Update `_saveLayoutSettings()` and `_syncAndLoadLayoutSettings()`:
  - Serialize/deserialize `_customCardVisibleParams` as JSON string under the key `${key}_custom_card_visible_params`.
- Register the `DiscoveryChannel` JavaScript channel on `WebViewController`:
  - Receives JSON array of discovered plugins and their controls.
  - Parses into `ParameterMetadata` objects and updates `ModWebSocketService`.
- Implement `_injectMetadataDiscovery()` evaluating the Backbone/DOM scraper script:
  - Call it in `NavigationDelegate.onPageFinished` and periodically via a javascript timer (similar to `_injectBpmMonitor()`).
- Modify the `PlaceholderCard` instantiation in the build grid:
  - Pass the new callbacks and parameters:
    - `visibleParams`: `_customCardVisibleParams[pedal.instance] ?? []`
    - `onSizeToggled`: `() => _cyclePedalSize(pedal.instance)`
    - `onParamChanged`: `(port, val) => _webSocketService.setParamValue(instance: pedal.instance, port: port, value: val)`
    - `onParamVisibilityToggled`:
      ```dart
      (symbol, visible) {
        setState(() {
          final list = _customCardVisibleParams[pedal.instance] ?? [];
          if (visible) {
            if (!list.contains(symbol)) list.add(symbol);
          } else {
            list.remove(symbol);
          }
          _customCardVisibleParams[pedal.instance] = list;
        });
        _saveLayoutSettings();
      }
      ```

---

### Dynamic Generic Cards

#### [MODIFY] [placeholder_card.dart](file:///c:/Users/damie/Dev/TamperMod/mod_controller/lib/widgets/cards/placeholder_card.dart)
- Redesign `PlaceholderCard` to render full, interactive generic interfaces:
  - **Compact View**: Render title, bypass switch, and descriptive type label.
  - **Regular View**:
    - Build a 2-column scrollable grid of sliders and toggles for checked parameters (in `visibleParams`).
    - If `visibleParams` is empty (default), display ALL discovered parameters.
    - Style sliders with the pedal's `glowColor` for premium neon styling.
  - **Expanded View**:
    - **Header**: Title, size toggle, bypass switch, and Info button.
    - **Parameter Configuration Section**: Checklist of checkboxes for every discovered parameter in `pedal.parameters.keys`. Tapping toggles visibility.
    - **Control Grid**: Sliders/switches for ALL parameters.
- **Info Dialog**: Tapping the Info button displays parameter metadata details (Min, Max, Step, Symbol, Value) in a clean, stylish table.

---

### Settings Drawer Icons

#### [MODIFY] [settings_drawer.dart](file:///c:/Users/damie/Dev/TamperMod/mod_controller/lib/widgets/drawers/settings_drawer.dart)
- In `_buildMiniPuzzleTile()`, add `isGainOrVolume` check:
  ```dart
  final isGainOrVolume =
      uriLower.contains('gain') ||
      uriLower.contains('volume') ||
      uriLower.contains('amp') ||
      titleLower.contains('gain') ||
      titleLower.contains('volume');
  ```
- Change `typeIcon` determination:
  ```dart
  IconData typeIcon = Icons.tune; // default generic icon
  if (isLooper) {
    typeIcon = Icons.fiber_manual_record;
  } else if (isSwitch) {
    typeIcon = Icons.swap_horiz;
  } else if (isGainOrVolume) {
    typeIcon = Icons.adjust;
  }
  ```

---

## Verification Plan

### Automated Tests
- Run `flutter test` to verify compilation and baseline widget tests.

### Manual Verification
1. **Device Discovery**:
   - Open a pedalboard containing a non-standard device (e.g. guitarix cabinet, filter, chorus).
   - Verify it appears in the workspace as a `PlaceholderCard` and in the settings drawer with the icon `Icons.tune`.
2. **Metadata Verification**:
   - Verify that parameter sliders reflect the correct names and ranges scraped from the WebView.
   - Tap the **Info** button in Expanded mode and verify that a dialog displays accurate ranges and steps.
3. **Custom Regular Card Layout**:
   - Set the card to Expanded mode.
   - Uncheck a few checkboxes.
   - Switch the card to Regular mode.
   - Verify that unchecked sliders/switches are hidden, and checked ones remain visible and interactive.
4. **Layout Persistence**:
   - Reload the application. Verify that unchecked/checked settings are preserved.
   - Perform a layout backup and verify that custom parameter configurations are included in the backup and successfully restored.
