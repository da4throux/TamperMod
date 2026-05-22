# ALO Compact Card Height Compression & Interactivity (v1.3.22)

This plan details the visual and behavioral enhancements to the ALO looper regular (compact) card (`LooperRegularCard`) to resolve button layout overflow within the fixed `240.0` height constraint, and align title long-press and timeline interactivity.

## User Review Required

> [!IMPORTANT]
> **Layout Height Constraints**:
> - We will compress vertical spacing and element sizes inside [looper_regular_card.dart](file:///c:/Users/damie/Dev/TamperMod/mod_controller/lib/widgets/cards/looper_regular_card.dart) so the entire card stays within the strict `240.0` container height, ensuring that bottom action buttons (Record, Mute, Clear) are completely within hit-test bounds and thus clickable.
> - We will replace `ElevatedButton.icon` with custom `ElevatedButton` child rows to avoid default padding/clip issues in tight columns.

## Proposed Changes

---

### ALO Looper Regular Card

#### [MODIFY] [looper_regular_card.dart](file:///c:/Users/damie/Dev/TamperMod/mod_controller/lib/widgets/cards/looper_regular_card.dart)
- **Vertical Spacing**:
  - Reduce `SizedBox(height: 6)` spacers to `SizedBox(height: 4)`.
- **All-Tracks Playing Bar**:
  - Reduce the container height in `_buildAllTracksPlayingBar` from `48.0` to `38.0`.
  - In `_buildTrackRow`, center the track text (`L1`-`L6`) and status icon vertically by wrapping the label row in `Align(alignment: Alignment.centerLeft)`.
- **Loop Selector Row**:
  - Update `ElevatedButton` styles to use `minimumSize: const Size(0, 24)` and `padding: EdgeInsets.zero`.
- **Action Buttons Row**:
  - Replace `ElevatedButton.icon` with standard `ElevatedButton` using `padding: EdgeInsets.zero`, `minimumSize: const Size(0, 28)`.
  - Pass a custom `Row` (with `mainAxisAlignment: MainAxisAlignment.center`, `mainAxisSize: MainAxisSize.min`, small icon size `12` and text font size `9.5`) to `child` to avoid label/icon clipping.
  - Implement dynamic `PLAY`/`MUTE` text and icon rendering based on the selected loop's active `LooperState.paused` state. Disable the Mute/Play button (passing `null` to `onPressed`) if the loop state is not playing or paused.
- **Title and Size Toggle**:
  - Ensure title and size toggle long-press triggers `widget.onRenamePressed` to match `LooperCard` (no edit icon, long press on title/resize opens dialog).
- **Timeline Interactivity**:
  - Keep/verify the interactive gesture on `_buildTrackRow` where clicking a track row selects it if unselected, and triggers record/cancel if selected.

---

### Versioning Configuration

#### [MODIFY] [main.dart](file:///c:/Users/damie/Dev/TamperMod/mod_controller/lib/main.dart)
- Verify/bump version to `'1.3.22'`.

#### [MODIFY] [pubspec.yaml](file:///c:/Users/damie/Dev/TamperMod/mod_controller/pubspec.yaml)
- Verify/bump version to `1.3.22`.

---

## Verification Plan

### Automated Tests
- Run `flutter test` to ensure that there are no compilation errors or logical regression in looper widget tests.

### Manual Verification
1. Toggle the ALO card to regular (compact) mode.
2. Confirm there are no bottom button overflows.
3. Tap on the loop selector buttons and verify they work.
4. Tap on the bottom row buttons (Record, Mute, Clear) and verify that they are now fully responsive (clickable).
5. Verify the Record button dynamically toggles to "CANCEL" during count-in/recording and can cancel it.
6. Verify the Mute button dynamically changes label/icon to "PLAY" when muted, and toggles play/mute state.
7. Click the small timeline track rows. Verify that tapping an unselected loop selects it, and tapping it again triggers recording/cancel.
8. Long-press on the card name or the size toggle button to confirm that the rename/color customization dialog opens.
