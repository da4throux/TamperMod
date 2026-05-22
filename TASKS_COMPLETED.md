# Completed Tasks

## ALO Bugs and Improvements (v1.3.23)
* [x] Alo looper recorder logic: first rolls all 4 bars for count-in, then starts recording for 4 bars, then transitions to play mode. Different colors defined for empty (grey[800]) and paused/muted (blueGrey) states.
* [x] In Alo Looper, replaced non-functional on/off buttons with a single full-width and always-available "Click" button (sends 1.0, wait 50ms, sends 0.0).
* [x] Alo Looper regular card size representation in the organizational drawer is corrected.
* [x] In Alo, playing vertical beat bars on timelines are made brighter (0.65 opacity) for better beat visualization.
* [x] The Alo extended card has its row of 6 loop selector buttons replaced with a 3x2 timeline selector grid where tapping a track cell selects and outlines the corresponding loop.
* [x] In Alo regular card, the loop selector and action buttons are removed, and the 3x2 timeline container height is expanded to 150px with interactive direct-tap (and long-press clear) gestures.

## Advanced Configuration (v1.3.24)
* [x] Implement Layout Configuration Backup & Restore: added custom dialog accessible from the settings drawer with Google Drive backup/restore via native Android Share Sheet and Document Picker, bypassing runtime permission requirements.
* [x] Add fallback text-based JSON copy/paste clipboard mechanism in a collapsible advanced section.
* [x] Display current pedalboard configuration statistics (number of pedalboards, configurations, and total keys) in the backup dialog.

