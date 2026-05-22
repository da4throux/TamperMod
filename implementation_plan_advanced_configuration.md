# Implementation Plan: Layout Configuration Backup & Restore (File Sharing & Picking)

This plan details the implementation of a backup and restore system for layout configurations. By leveraging Android's native **Share Sheet** and **Storage Access Framework (SAF)**, we can allow the user to save and load their configurations directly from/to Google Drive or local storage without requiring OAuth accounts, Google Cloud console configuration, or system storage permissions.

## User Review Required

> [!IMPORTANT]
> **Cloud & Google Drive Integration**:
> - **Export**: To save layout configurations to Google Drive, the app will serialize the settings to JSON, write it to a temporary file, and launch the Android **Share Sheet** (via the `share_plus` package). On your Pixel Tablet, the system share sheet will naturally show **"Save to Drive"** (Google Drive) and **"Save to Files"** (local directories) as options.
> - **Import**: To restore configurations, the app will open the native Android **File Picker** (via the `file_picker` package). The Android file picker lets you browse your local directories as well as your connected **Google Drive** folders directly.
> - **No OAuth Overhead**: This approach is 100% secure, relies on Android's built-in system capability, and avoids setting up API client IDs in Google Cloud Console.

### Will the Backup File Be Sensitive to Versioning?

**No, the backup file is highly resilient to versioning.**
* **New App Versions / New Keys**: If you update the app and restore an older layout backup, the app will overwrite the configurations for existing cards. Any new keys or new cards introduced in the update will simply fallback to their defaults on startup (e.g. automatically auto-assigning colors and regular sizes to new cards).
* **Missing Cards**: If you restore a backup containing settings for a card that is no longer on the active pedalboard, the app simply ignores those settings.
* **No Crashes**: SharedPreferences storage uses flat JSON strings and primitive key-value pairs; it has no rigid schema structure that would cause crashes when keys are added or removed.

---

## Open Questions

None. The integration of `share_plus` and `file_picker` provides the best possible user experience while remaining robust and simple.

---

## Proposed Changes

### Project Dependencies

#### [MODIFY] [pubspec.yaml](file:///c:/Users/damie/Dev/TamperMod/mod_controller/pubspec.yaml)
- Add `share_plus: ^7.2.1` to dependencies.
- Add `file_picker: ^8.0.0` to dependencies.

---

### Dashboard & Layout State Management

#### [MODIFY] [dashboard_screen.dart](file:///c:/Users/damie/Dev/TamperMod/mod_controller/lib/screens/dashboard_screen.dart)

- **Backup / Restore File Operations**:
  - Implement `_exportConfigurationsToFile()`:
    - Serialize all configurations starting with `pedalboard_` and the `is_dark_mode` preference into a JSON map.
    - Write this map to a temporary file named `tampermod_layouts_backup.json` in the app's temporary directory.
    - Call `Share.shareXFiles([XFile(tempPath)], subject: 'TamperMod Layout Backup')`.
    - This will open the native Android share dialog, enabling "Save to Drive".
  - Implement `_importConfigurationsFromFile()`:
    - Call `FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['json'])`.
    - If a file is selected:
      - Read its bytes and decode them to a JSON string.
      - Validate that the JSON structure is not empty and contains keys prefixed with `pedalboard_`.
      - Confirm the overwrite with the user: *"This will overwrite existing configurations. Continue?"*.
      - If confirmed, clear existing `pedalboard_` keys and restore all backup keys to `SharedPreferences`.
      - Trigger `_syncAndLoadLayoutSettings()` to refresh the dashboard immediately.
      - Display a success banner.

- **Backup & Restore Dialog (`_showBackupRestoreDialog()`)**:
  - Present a beautiful modal dialog matching the app's modern dark theme and neon palette.
  - Display the current stats:
    - Number of pedalboard configurations saved.
    - Total database keys.
  - Present two premium interactive cards:
    - **EXPORT TO FILE / DRIVE**:
      - Border highlight: Neon turquoise (`Color(0xFF00FFCC)`).
      - Action: Triggers `_exportConfigurationsToFile()`.
    - **IMPORT FROM FILE / DRIVE**:
      - Border highlight: Neon pink (`Color(0xFFFF007F)`).
      - Action: Triggers `_importConfigurationsFromFile()`.

- **Drawer Wiring**:
  - Pass the `_showBackupRestoreDialog` callback to `SettingsDrawer` under the parameter `onBackupRestore`.

---

### Drawer UI

#### [MODIFY] [settings_drawer.dart](file:///c:/Users/damie/Dev/TamperMod/mod_controller/lib/widgets/drawers/settings_drawer.dart)

- **Constructor**:
  - Add `final VoidCallback onBackupRestore;` to `SettingsDrawer` and require it in the constructor.
- **Backup & Restore Action Button**:
  - In `_buildDrawerContent()`, below the `LAYOUT CONFIGURATION` container but above the `PUZZLE CANVAS (ACTIVE)` header, insert a dedicated row:
    - Outlined button with `Icons.settings_backup_restore_rounded`.
    - Border color matching the current theme's primary color with opacity (`0.5`).
    - Label: `BACKUP & RESTORE CONFIGURATIONS`.
    - Action: Triggers `widget.onBackupRestore`.

---

### Versioning Configuration

#### [MODIFY] [main.dart](file:///c:/Users/damie/Dev/TamperMod/mod_controller/lib/main.dart)
- Bump version `kAppVersion` to `'1.3.24'`.

#### [MODIFY] [pubspec.yaml](file:///c:/Users/damie/Dev/TamperMod/pubspec.yaml)
- Bump version to `1.3.24`.

---

## Verification Plan

### Automated Tests
- Run `flutter test` to ensure that compiling is successful and the test suite passes.

### Manual Verification
1. **Export flow**:
   - Open Settings Drawer -> tap **BACKUP & RESTORE CONFIGURATIONS**.
   - Tap **EXPORT TO FILE / DRIVE**.
   - Verify that the native Android share sheet opens, showing "Save to Drive".
   - Save the file to your Google Drive.
2. **Import flow**:
   - Change a few cards (colors, sizes, order).
   - Open dialog -> tap **IMPORT FROM FILE / DRIVE**.
   - Verify that the Android document browser opens.
   - Navigate to Google Drive, select the saved JSON file.
   - Confirm the restore warning.
   - Verify that the modified settings are restored to the exact state saved in the backup.
3. **Uninstall Verification**:
   - Export settings to Google Drive.
   - Uninstall the application from the tablet.
   - Re-run `flutter install --release` to reinstall.
   - Open the app, trigger **IMPORT FROM FILE / DRIVE**, select the file from Google Drive.
   - Verify that all configurations are fully restored.
