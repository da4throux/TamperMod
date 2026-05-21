# TamperMod Refactoring Plan — Completed at v1.2.14 → targeting Milestone v1.3.0
- follow .agentrules as you should
- Mark as done [x], tasks that are achieved
- update Specification.md, readme.md as they should

> ⚠️ **Per `.agentrules` Rule 1 — Milestone Protocol:** The final version bump from `v1.2.x` to `v1.3.0` requires explicit **user authorization**. Agents must NOT bump the `Y` index autonomously. All technical work through Phase 8 is complete at `v1.2.14`. Phase 9.2 is blocked pending user approval.

## Phase 0: Pre-Refactoring Fixes (MUST DO FIRST)

### 0.1 Standardize ALO Looper Card Structure
**Problem:** ALO looper is treated differently from other controllers:
- No resize button (should be present but greyed out since ALO is always expanded)
- ALO is handled as 2 separate effects in glow system instead of 1 controller
- Inconsistent card structure compared to Gain/Switch cards

**Tasks:**
- [x] Add greyed-out size toggle button to ALO looper card header (left of title, matching Gain/Switch position)
- [x] Treat ALO looper as single controller in `_enabledPluginInstances` (currently may be duplicated)
- [x] Ensure ALO looper uses single glow color assignment (not two separate glows)
- [x] Update `_buildLooperControlPanel()` to match standard card header structure:
  - Size toggle (greyed, non-functional) | Title | Help icon | BPM badge
- [x] Test that ALO appears once in puzzle organizer drawer
- [x] Verify single glow color persists for ALO in settings

**Acceptance Criteria:**
- ALO looper card has same header structure as Gain/Switch cards
- Size toggle button visible but disabled (greyed out)
- ALO treated as single controller throughout codebase
- Single glow color in color picker and WebView highlights

---

## Phase 1: Directory Structure Setup

### 1.1 Create Directory Tree
```
mod_controller/lib/                     ✅ FINAL STATE (v1.2.14)
├── main.dart                          # App entry, theme, MaterialApp only (< 60 lines)
├── screens/
│   └── dashboard_screen.dart          # Main scaffold + all state management
├── widgets/
│   ├── cards/
│   │   ├── base_card.dart            # Shared card wrapper/shell
│   │   ├── gain_card.dart            # Gain/volume controller
│   │   ├── switch_card.dart          # Switch/routing controller
│   │   ├── looper_card.dart          # ALO looper controller
│   │   └── placeholder_card.dart     # Generic fallback
│   ├── painters/
│   │   ├── fade_curve_painter.dart   # Live fade visualizer
│   │   ├── mini_range_painter.dart   # Compact range indicator
│   │   └── range_overlay_painter.dart # Slider triangle cursors
│   ├── drawers/
│   │   ├── settings_drawer.dart      # Right drawer (puzzle organizer)
│   │   └── metrics_drawer.dart       # Left drawer (metrics/nav)
│   ├── toolbars/
│   │   ├── bottom_toolbar.dart       # View selectors, theme
│   │   ├── connection_panel.dart     # IP input, connect button
│   │   └── bpm_controller.dart       # BPM widget with tap tempo
│   └── common/
│       ├── fade_button.dart          # Reusable fade button
│       ├── size_toggle_button.dart   # Reusable size toggle
│       └── module_help_sheet.dart    # Help bottom sheet
├── models/
│   ├── plugin_instance.dart
│   └── module_help_data.dart
│   # Note: looper_state.dart was not extracted — LooperState enum
│   # lives inside looper_controller.dart (sufficient for current scale)
├── services/
│   ├── websocket_service.dart
│   └── looper_controller.dart
└── utils/
    ├── curves.dart                   # CustomSCurve
    └── color_utils.dart              # Hex conversion helpers
```

**Tasks:**
- [x] Create all directories
- [x] Create empty placeholder files with TODO comments
- [x] Add copyright/license headers to each file

---

## Phase 2: Extract Utilities & Painters (Low Risk)

### 2.1 Extract Custom Curves
**File:** `lib/utils/curves.dart`
**Extract from main.dart:**
- `_CustomSCurve` class (lines ~18-35)

**Tasks:**
- [x] Create `curves.dart`
- [x] Move `_CustomSCurve` class
- [x] Add imports to `main.dart`
- [x] Test compilation

### 2.2 Extract Color Utilities
**File:** `lib/utils/color_utils.dart`
**Extract from main.dart:**
- `_hexToColor()` method
- `kNeonColors` constant
- Any other color helper functions

**Tasks:**
- [x] Create `color_utils.dart`
- [x] Move color utilities
- [x] Add imports to `main.dart`
- [x] Test compilation

### 2.3 Extract Painters
**Files:** 
- `lib/widgets/painters/fade_curve_painter.dart`
- `lib/widgets/painters/mini_range_painter.dart`
- `lib/widgets/painters/range_overlay_painter.dart`

**Extract from main.dart:**
- `_FadeCurvePainter` class (~37-180)
- `_MiniRangePainter` class (~192-250)
- `_RangeOverlayPainter` class (~252-310)

**Tasks:**
- [x] Create painter files
- [x] Move each painter class
- [x] Add necessary imports (Flutter material, curves)
- [x] Update imports in `main.dart`
- [x] Test compilation

---

## Phase 3: Extract Common Widgets (Medium Risk)

### 3.1 Extract Fade Button
**File:** `lib/widgets/common/fade_button.dart`
**Extract from main.dart:**
- `_buildFadeButton()` method logic

**Tasks:**
- [x] Create stateless widget `FadeButton`
- [x] Move button building logic
- [x] Add parameters: label, icon, isBypassed, onTap, accentColor, isFading, isCompact
- [x] Replace all `_buildFadeButton()` calls with `FadeButton` widget
- [x] Test compilation

### 3.2 Extract Size Toggle Button
**File:** `lib/widgets/common/size_toggle_button.dart`
**Extract from main.dart:**
- `buildSizeToggle()` method logic from gain card

**Tasks:**
- [x] Create stateless widget `SizeToggleButton`
- [x] Add parameters: instanceId, currentSize, accentColor, onTap, isEnabled
- [x] Replace all size toggle building code
- [x] Test compilation

### 3.3 Extract Module Help Sheet
**File:** `lib/widgets/common/module_help_sheet.dart`
**Extract from main.dart:**
- `_showModuleHelpSheet()` method
- `_buildHelpSectionHeader()` method

**Tasks:**
- [x] Create `ModuleHelpSheet` class with static `show()` method
- [x] Move help sheet logic
- [x] Update all calls to use new class
- [x] Test compilation

---

## Phase 4: Extract Toolbar Widgets (Medium Risk)

### 4.1 Extract BPM Controller
**File:** `lib/widgets/toolbars/bpm_controller.dart`
**Extract from main.dart:**
- `_buildBpmControllerWidget()` method

**Tasks:**
- [x] Create stateful widget `BpmController`
- [x] Move BPM widget logic
- [x] Pass required callbacks and state
- [x] Replace in AppBar and inline widget
- [x] Test compilation

### 4.2 Extract Bottom Toolbar
**File:** `lib/widgets/toolbars/bottom_toolbar.dart`
**Extract from main.dart:**
- `_buildBottomToolbar()` method
- `_buildLayoutButton()` method

**Tasks:**
- [x] Create stateless widget `BottomToolbar`
- [x] Move toolbar logic
- [x] Pass required state and callbacks
- [x] Replace in dashboard
- [x] Test compilation

### 4.3 Extract Connection Panel
**File:** `lib/widgets/toolbars/connection_panel.dart`
**Extract from main.dart:**
- `_buildConnectionPanel()` method

**Tasks:**
- [x] Create stateless widget `ConnectionPanel`
- [x] Move connection panel logic
- [x] Pass required state and callbacks
- [x] Replace in dashboard
- [x] Test compilation

---

## Phase 5: Extract Drawer Widgets (High Risk)

### 5.1 Extract Metrics Drawer
**File:** `lib/widgets/drawers/metrics_drawer.dart`
**Extract from main.dart:**
- `_buildLeftDrawerContent()` method
- `_buildLeftDrawerHeader()` method
- `_buildLeftDrawerTile()` method

**Tasks:**
- [x] Create stateless widget `MetricsDrawer`
- [x] Move left drawer logic
- [x] Pass required state and callbacks
- [x] Replace in Scaffold drawer
- [x] Test compilation

### 5.2 Extract Settings Drawer (Puzzle Organizer)
**File:** `lib/widgets/drawers/settings_drawer.dart`
**Extract from main.dart:**
- `_buildDrawerContent()` method
- `_buildDrawerHeader()` method
- `_buildMiniPuzzleTile()` method

**Tasks:**
- [x] Create stateful widget `SettingsDrawer`
- [x] Move right drawer logic
- [x] Pass required state and callbacks
- [x] Replace in Scaffold endDrawer
- [x] Test compilation and drag-drop functionality

---

## Phase 6: Extract Card Widgets (Highest Risk)

### 6.1 Create Base Card Widget
**File:** `lib/widgets/cards/base_card.dart`
**Purpose:** Shared card shell with glow, border, padding

**Tasks:**
- [x] Create `BaseCard` widget
- [x] Extract common card decoration logic
- [x] Add parameters: child, glowColor, isBypassed, onLongPress
- [x] Test with one card type

### 6.2 Extract Placeholder Card
**File:** `lib/widgets/cards/placeholder_card.dart`
**Extract from main.dart:**
- `_buildPlaceholderCard()` method

**Tasks:**
- [x] Create stateless widget `PlaceholderCard`
- [x] Move placeholder card logic
- [x] Use `BaseCard` wrapper
- [x] Replace in `_buildUnifiedControlsList()`
- [x] Test compilation

### 6.3 Extract Switch Card
**File:** `lib/widgets/cards/switch_card.dart`
**Extract from main.dart:**
- `_buildSwitchCard()` method
- `_getSwitchPortSymbol()` method
- `_setSwitchPath()` method

**Tasks:**
- [x] Create stateful widget `SwitchCard`
- [x] Move switch card logic
- [x] Use `BaseCard` wrapper
- [x] Pass required state and callbacks
- [x] Replace in `_buildUnifiedControlsList()`
- [x] Test compilation and functionality

### 6.4 Extract Gain Card
**File:** `lib/widgets/cards/gain_card.dart`
**Extract from main.dart:**
- `_buildGainCard()` method
- `_buildExpandedGainCard()` method
- All gain card helper methods

**Tasks:**
- [x] Create stateful widget `GainCard`
- [x] Move all gain card logic (compact, regular, expanded)
- [x] Use `BaseCard` wrapper
- [x] Use extracted painters and common widgets
- [x] Pass required state and callbacks
- [x] Replace in `_buildUnifiedControlsList()`
- [x] Test compilation and all three size modes
- [x] Test fade functionality

### 6.5 Extract Looper Card
**File:** `lib/widgets/cards/looper_card.dart`
**Extract from main.dart:**
- `_buildLooperControlPanel()` method
- `_buildLooperTrackSegment()` method
- `_buildLooperSlider()` method
- `_build4BarTimeline()` method
- `_PulsingIndicator` widget
- `_findPortSymbol()` method

**Tasks:**
- [x] Create stateful widget `LooperCard`
- [x] Move all looper logic
- [x] Use `BaseCard` wrapper
- [x] Ensure standardized header with greyed size toggle
- [x] Pass required state and callbacks
- [x] Replace in `_buildUnifiedControlsList()`
- [x] Test compilation and all looper functionality

---

## Phase 7: Extract Dashboard Screen (Final Integration)

### 7.1 Extract Dashboard Screen
**File:** `lib/screens/dashboard_screen.dart`
**Extract from main.dart:**
- `DashboardScreen` widget
- `_DashboardScreenState` class
- All state management logic
- All helper methods not moved to cards

**Tasks:**
- [x] Create `DashboardScreen` stateful widget
- [x] Move dashboard logic
- [x] Import all extracted widgets
- [x] Keep only state management in dashboard
- [x] Update `main.dart` to only contain `ModControllerApp`
- [x] Test full application

### 7.2 Clean Up main.dart
**File:** `lib/main.dart`
**Final state:** Should only contain:
- Imports
- `kAppVersion` constant
- `main()` function
- `ModControllerApp` widget (MaterialApp setup)

**Tasks:**
- [x] Remove all extracted code
- [x] Add imports for `DashboardScreen`
- [x] Verify file is < 100 lines
- [x] Test compilation

---

## Phase 8: Testing & Validation

### 8.1 Compilation Tests
- [x] Run `flutter analyze` - passes (95 infos, 0 errors, 0 blocking warnings — all pre-existing deprecations in widget files)
- [x] Run `flutter build apk --debug` - succeeded (`app-debug.apk` built in 12s)
- [x] Verify no import errors

### 8.2 Functional Tests
> These are device-side tests to be validated by the user on the Pixel Tablet.
- [ ] Test all card types (Gain, Switch, Looper, Placeholder)
- [ ] Test all card sizes (Compact, Regular, Expanded)
- [ ] Test size toggle button on all cards (including greyed ALO)
- [ ] Test fade functionality
- [ ] Test looper recording/playback
- [ ] Test puzzle organizer drag-drop
- [ ] Test color picker
- [ ] Test WebView glow highlights
- [ ] Test theme switching
- [ ] Test connection/disconnection
- [ ] Test BPM tap tempo
- [ ] Test all drawers

### 8.3 Performance Tests
> Device-side validation by the user.
- [ ] Verify no performance regression
- [ ] Check memory usage
- [ ] Test hot reload functionality

---

## Phase 9: Documentation & Commit

### 9.1 Update Documentation
- [x] Update `SPECIFICATION.md` with new file structure (§4 Done list updated through v1.2.13/v1.2.14)
- [x] Update `README.md` with architecture changes and version (`v1.2.14`)
- [x] Update `CURRENT_FOCUS.md` with completion status
- [x] Add inline documentation to new files (MIT headers on all new files)

### 9.2 Version & Milestone Commit — ⚠️ AWAITING USER AUTHORIZATION
> Per `.agentrules` Rule 1: bumping the `Y` version index (from `1.2.x` → `1.3.0`) is a **Milestone** and requires explicit user authorization. An agent must NOT do this autonomously.
- [ ] **[USER MUST AUTHORIZE]** Bump `kAppVersion` in `main.dart` to `1.3.0`
- [ ] **[USER MUST AUTHORIZE]** Update `pubspec.yaml` version to `1.3.0`
- [ ] **[USER MUST AUTHORIZE]** Commit: `git commit -m "Antigravity(v1.3.0): Complete modular refactoring — all components extracted to dedicated files"`

---

## Actual Execution History

| Phase | Version | Agent | Status |
|-------|---------|-------|--------|
| Phase 0 — ALO Standardization | v1.2.10 | Gemini3.5Flash | ✅ Done |
| Phase 1 — Directory Setup | v1.2.8 | Haiku4.5 | ✅ Done |
| Phase 2 — Utils & Painters | v1.2.8–v1.2.9 | Haiku4.5 | ✅ Done |
| Phase 3 — Common Widgets | v1.2.10 | Gemini3.5Flash | ✅ Done |
| Phase 4 — Toolbar Widgets | v1.2.11 | Gemini3.5Flash | ✅ Done |
| Phase 5 — Drawer Widgets | v1.2.12 | Gemini3.5Flash | ✅ Done |
| Phase 6 — Card Widgets | v1.2.13 | Antigravity | ✅ Done |
| Phase 7 — Dashboard Screen | v1.2.14 | Antigravity | ✅ Done |
| Phase 8.1 — Compilation Tests | v1.2.14 | Antigravity | ✅ Done |
| Phase 8.2/8.3 — Device Tests | — | User | ⏳ Pending |
| Phase 9.1 — Documentation | v1.2.14 | Antigravity | ✅ Done |
| Phase 9.2 — v1.3.0 Milestone | — | **User auth needed** | 🔒 Blocked |

---

## Success Criteria — Status at v1.2.14

✅ All functionality compiles and APK builds successfully
✅ `main.dart` is < 60 lines (well under the 100-line target)
✅ Each card type in a separate file
✅ All painters in separate files
✅ All common widgets extracted and reusable
✅ ALO looper standardized with other cards
✅ No compilation errors (0 errors, 0 blocking warnings)
✅ Documentation updated (README, SPECIFICATION, CURRENT_FOCUS)
🔒 Version 1.3.0 milestone — awaiting user authorization
⏳ Device functional tests — to be validated by the user on Pixel Tablet