# TamperMod — Current Focus

## ✅ Completed (v1.3.81)
- **Ctrl+S Backup Shortcut & Puzzle Board Real-time Placement / Foldable Pool**:
  1. **Global `Ctrl+S` / `Cmd+S` Shortcut**: Pressing Ctrl+S instantly copies the complete configurations backup JSON to the clipboard and shows a confirmation toast.
  2. **Live Drag Placement from Inactive Pool**: Dragging an inactive tile over the active canvas immediately opens up space and previews the tile's placement in real time.
  3. **Foldable & Flexible Inactive Pool**: Tapping the "AVAILABLE POOL (INACTIVE)" header collapses/expands the section, and the pool naturally yields space to the main active puzzle canvas.

## ✅ Completed (v1.3.80)
- **Inline Single-Screen Clipboard JSON Backup & Restore**:
  1. **Zero-Expansion Direct Visibility**: Raw JSON text field, `COPY JSON`, and `PASTE & RESTORE` action buttons are now directly embedded on the Backup & Restore screen without requiring an ExpansionTile.
  2. **1-Tap Paste & Restore**: `PASTE & RESTORE` automatically checks and extracts system clipboard JSON if the text field is empty, enabling instant one-tap restoration.

## ✅ Completed (v1.3.79)
- **Timestamped Backup Export & Lenient Layout Matching**:
  1. **Timestamped Filenames**: Exporting configurations now produces uniquely timestamped files (e.g. `tampermod_backup_YYYY-MM-DD_HHMMSS.json`) and bundles custom curve presets.
  2. **Lenient Layout Matching**: When loading a pedalboard whose exact hash is new (e.g. 1 pedal was added/removed), TamperMod automatically discovers the closest matching saved layout, preserves all card positions, colors, sizes, titles, and fade curves, gracefully removing only the missing items.

## ✅ Completed (v1.3.78)
- **Zero-Distortion Collinear Tangent & Seamless $C^1$ Continuity at Midpoint $M$**:
  1. **Eliminated False Vertical Rise on Horizontal Drag**: Removed artificial vertical $s_2$ scaling factor that distorted horizontal control points into steep upward angles.
  2. **Collinear Control Points ($C_{02} = H_1$, $C_{11} = H_2$)**: The Bézier spline now adheres exactly and continuously to the tangent handle angle with zero kink/angle at midpoint $M$.
  3. **Full Box-Edge Reach**: Extended drag range so handles can reach the outer boundary of the normalized box frame along their exact collinear angle.

## ✅ Completed (v1.3.77)
- **Static Audio Transport Controls & Compact Full-Height Fade Buttons**:
  1. **Persistent Transport Controls**: PAUSE/RESUME and STOP buttons are always present in the layout to prevent UI shifts. When no fade is active, they are cleanly disabled and greyed out.
  2. **Compact Tile Two-Row Layout**:
     - Top sub-row: `[PAUSE / RESUME]` and `[STOP]` transport buttons side by side at fixed compact height.
     - Bottom row: `[FADE IN]` and `[FADE OUT]` buttons side by side filling the remaining vertical card height.
  3. **Regular & Expanded Modes**: Static 4-capsule row `[FADE IN]` + `[PAUSE/RESUME]` + `[STOP]` + `[FADE OUT]`.

## ✅ Completed (v1.3.76)
- **Vectorized Bézier Horizontal Tangent Length Scaling**:
  1. **Fixed Horizontal Tangent Stalling**: Corrected the incoming/outgoing endpoint control point calculations ($C_{01x}$ and $C_{12x}$) to scale relative to the actual tangent handle coordinate ($c02x$ and $c11x$) rather than midpoint $vmx$.
  2. **Intuitive Tangent Expansion**: When extending a tangent handle horizontally along the x-axis, the curve now stays flat and adheres along the tangent handle for its full length on the x-axis, rather than premature upward bending.

## ✅ Completed (v1.3.75)
- **Mono/Stereo Gain Card Buttons Redesign & Responsive Transport Controls**:
  1. **Clean Horizontal Fade & Transport Bar**: Replaced the awkward vertical stacked buttons with a sleek, balanced horizontal row (`[FADE IN]` and `[FADE OUT]`).
  2. **Play / Pause / Stop Audio Controls**: Whenever a fade is running or paused (`isFading || isFadePaused`), responsive `PAUSE`/`RESUME` (amber play/pause capsule) and `STOP` (red stop capsule) transport buttons cleanly expand in the center between Fade In and Fade Out.
  3. **Zero Overflow in Regular & Compact Modes**: Adjusted vertical padding (`vertical: 8.0`) and item spacings in `GainCard`, completely resolving the 23px bottom overflow.
  4. **Sleek Button Aesthetics**: Redesigned `FadeButton` to use glowing tinted capsules with border highlights and pulsating glow effects during active fades.

## ✅ Completed (v1.3.74)
- **Standardized Tile Header Row Across All Modules & Puzzle Board**:
  1. **Tile / Card First Line Standardization**: Implemented a uniform header row across all 5 card widgets (`PlaceholderCard`, `SwitchCard`, `GainCard`, `LooperCard`, `LooperRegularCard`) in all size modes:
     `[Size Toggle Button]` ➔ `[Name]` ➔ `[Info Button]` ➔ `[Edit Button]` ➔ `[Focus Button]` ➔ `[Power Button]`.
  2. **Puzzle Board Tile Size Placement**: Moved the size cycle badge `[C]` / `[R]` / `[E]` to the top-left before the module name and type icon on all tiles in the Tile Board.
  3. **SwitchCard Size Toggle & Full Action Support**: Added missing `SizeToggleButton`, `onSizeToggled`, and Info button to `SwitchCard`.
  4. **Looper Card Bypass & Action Support**: Added `onBypassToggle` and power control button to `LooperCard` and `LooperRegularCard`.

## ✅ Completed (v1.3.73)
- **Unlimited Line Breaks & Inactive Pool Hydration in Puzzle Board**:
  1. Confirmed and clarified unlimited Line Breaks support in the Puzzle Board: each tap of "+ LINE BREAK" creates and inserts a new full-width line separator tile.
  2. Fixed inactive pool hydration in `SettingsDrawer` so disabled line breaks and spacers stay visible in the inactive list rather than disappearing.
  3. Added prominent `+` icon to the LINE BREAK action button for clear affordance.

## 📋 Remaining Tasks
- **A2. WebView Controls**: WebView full-screen toggle, separation layout adjustment.
- **E2. Default Fadeout Values**: Mapping default values for fader/automation objects.

## 🔧 Quick Context
- **App Version:** v1.3.74
- **Last commit:** Gemini3.7Flash(v1.3.74) - Standardized tile header layout (size, name, info, edit, focus, power) across all tiles
- **Architecture:** Flutter app in `mod_controller/` with modular card-based UI
