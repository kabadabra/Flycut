# Flycut Evolution interaction and presentation

## Outcome

Flycut Evolution keeps the current `com.edynamics.flycut` identity and 3.0.0 technical version so the installed Swift candidate, migrated history, Apple signing, and login registration continue to work. The visible app, About screen, release title, DMG, and active documentation use **Flycut Evolution**. The GitHub repository remains Flycut and retains upstream credit.

Selecting a clipping with one click is the primary action. Flycut copies its text to the clipboard, then pastes into the app the user came from only when that app has an enabled, editable text control focused. If no text field is focused, Accessibility is unavailable, focus changes, the app disappears, or the keyboard layout cannot provide Paste, Flycut leaves the clipping on the clipboard and does not synthesize a Paste event. Return performs the same action on the keyboard-selected row. Arrow keys still move selection without activating it.

## Palette

Use a taller, slightly narrower default palette: 460 × 700 points, bounded by the visible screen. Keep the existing two-line clipping preview and source/time metadata, but tighten row spacing and padding so more rows are visible. Search and collection controls remain. Single-click and the accessible Activate action activate a row; a rapid second click on the same row must not paste twice. Remove the separate Copy and Paste controls from the footer and row menu. Favorite, export, delete, help, pause, and settings remain available. The footer or help text explains “Click or press Return to copy; Flycut pastes when a text field is focused.”

The legacy `menuSelectionPastes` value can stay in stored data for compatibility, but it no longer controls row activation or appears as a setting. Migration explains this changed behavior rather than silently claiming old double-click semantics. Existing imported dimensions 500 × 320 are upgraded once to the new layout; custom dimensions remain untouched. Users can still edit width and height in Appearance. New legacy imports with no explicit dimensions use the new layout; explicit legacy dimensions remain respected.

## Paste safety

`PasteService` keeps its current clipboard write, self-write record, target freeze, activation, focus wait, permission recheck, and layout-aware key event. Immediately before sending the key event, a small platform service examines the previously active app's focused Accessibility element. It reads only role, enabled state, and whether its value is editable; it never reads the field contents. Supported text roles include text fields, text areas, and combo boxes. Unknown or inaccessible controls fail closed to Copy only. The target process must still be frontmost, the clipboard change count unchanged, and Accessibility trusted before the key event.

No field focused and other paste-unavailable states produce a clear Copy fallback message. An Accessibility denial retains the existing permission link and optional one-time reminder. The app never requests new permission on a row click.

## Brand and release

Package the production app as `Flycut Evolution.app`, preview as `Flycut Evolution Preview.app`, and release image as `Flycut-Evolution.dmg`. Keep `FlycutMac` executable, `com.edynamics.flycut` bundle ID, data locations, Apple team, macOS 13 deployment floor, version 3.0.0, and `v3.0.0` tag. Release notes use Flycut Evolution as the product title and mention version 3.0.0 as technical version. Update scripts, verification, workflow, README, About, migration language, and release setup consistently. Historical Flycut 2.0 documents and release remain intact.

## Verification

- Tests first: automatic row activation independent of the obsolete preference; Return activation; no duplicate activation; editable and noneditable focus outcomes; permission, cancellation, clipboard-change and app-focus guards; layout defaults and one-time dimension migration; bundle/display name and release artifact checks.
- Full Swift suite, Debug and universal Release builds, strict bundle verification, Graphify refresh, CI, and a nonpublishing signed/notarized dry run.
- Synthetic UI pass on macOS 27: row click, Return, compact taller palette, editable-target automatic paste after user-approved Accessibility permission, no-field Copy fallback, and content-free confirmation that the real migrated 50 clips persist. Preserve the previous 2.0 backup.

## Current limits

The desktop tool cannot reliably click the macOS status item or conduct a full VoiceOver/non-QWERTY hardware check. These remain explicit manual release checks. Accessibility permission requires the user's separate at-action approval before a live automatic-paste test.
