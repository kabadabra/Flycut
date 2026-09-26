# Swift preview QA

## Task 7 — 2026-09-26

Environment: macOS 27 SDK, Swift 6 language mode, Debug preview bundle `com.edynamics.flycut.preview`. Only `build/Preview/Flycut Preview.app` was launched. Installed Flycut 2.0 was not replaced, launched, configured, or inspected.

### Automated evidence

- Selection/search/collection and keyboard-command tests were written first; initial compilation failed because the new selection/command API did not exist. After implementation, all three tests passed.
- History clear/delete/move-to-top tests were written first; initial compilation failed on missing service methods. Both tests now pass.
- Full `swift test`: 77 XCTest tests, zero failures (55 core, 22 platform), including monitor launch-count preservation, stale/self-written clipboard behavior, paste cancellation and permission rechecks.
- `scripts/build-app.sh debug`: successful build and strict ad-hoc signature verification.
- `graphify update . --no-cluster`: successful local graph refresh. Graph artifacts remain ignored.

### Actual manual observations

- Initial launch attempts crashed before showing UI: using `UserDefaults(suiteName:)` with the app's own bundle identifier returned nil. Crash stack identified the initializer. Changed bundled apps to `.standard`, whose domain is already isolated by bundle identity. Relaunched successfully; verified the preview process remained running.
- Native UI tooling timed out against the status-only app. Reopening the app by its preview path now presents its history panel, allowing direct inspection.
- Reopened palette: search field focused; empty recents; Copy/Paste/Favorite/Save disabled; Accessibility Settings action visible. No clipboard text was read or logged by the development tools.
- Clicked Pause; saw Resume Capture and Capture paused. Typed only `synthetic-search` into search; saw No matching clippings. Down/Return on this empty result did not create a clipping or trigger a paste.
- Opened keyboard help. Light appearance screenshot showed search, segmented collection picker, empty state, footer buttons and complete help text without clipping.
- Opened commands menu: merge, export collection, clear recents, keyboard help, Settings, About and Quit entries were present.
- Quit through the palette menu; process check confirmed no FlycutMac preview process remained. Preview was not left monitoring the user's clipboard.

### Remaining manual gates (Task 10)

- Status-item click/popover anchoring, real hotkey presentation from another app, Escape dismissal: keyboard actions were attempted, but AX state did not provide reliable visibility evidence, so these are **not marked passed**.
- Search with synthetic captured rows, selected-row arrows/Home/End/Page Up/Down/digits, favorite/delete/export/merge and clear confirmation interaction.
- Real paste into a disposable target, prior-app restoration, unavailable/denied permission flows, sticky-palette behavior, non-QWERTY input, full-screen Space and VoiceOver.
- Dark appearance was not changed or visually verified. Light appearance alone was inspected.
- Launch clipboard preservation is supported by automated fake-board tests and the launch code path, **not a comparison of the user's real clipboard**. No live clipboard contents were inspected.
- Normal on-quit persistence is wired through delayed application termination, but end-to-end saved synthetic history relaunch and failure recovery still need manual coverage.

### Task 8 integration

`AppCoordinator.showSettings` is the settings entry-point callback. Its current dialog explicitly says the grouped editor is forthcoming. Use `settings` and `configure(_:)` to connect the settings window. The coordinator owns one hotkey service and attempts to restore the previous shortcut after registration failure; if both fail it displays a disabled message. Save modes are checked at each persist operation; `.never` never opens, restores or saves disk history during a launch in that mode. The revision below protects unread destinations during mode transitions. Choosing `.never` does not erase an existing saved database.

Settings still must supply the grouped editor, explicit remember-pause preference, icon/appearance application, save-mode transition UX, and eviction autosave. Sticky behavior and its review fix are documented in the revision section below. Migration UI remains the later migration task; this shell does not automatically import legacy data.

## Task 7 review fixes — 2026-09-26

This section supersedes the earlier sticky-paste deferral and the previously unverified populated/dark/hotkey/Escape checks.

### Saved-history protection

A new `HistoryPersistence` gate permits replacement only after the destination snapshot has been fully read and restored into the working repository. A database handle alone is no longer permission to write. Restore failure leaves disk untouched, starts capture in memory and displays a persistent warning explaining that new clippings must be exported before quitting. Quit can finish without replacing unread data. A session that started with saving disabled also cannot silently overwrite an unread destination after a setting change; Task 8 must provide explicit transition/recovery UX.

Regression used a disposable SQLite database containing a synthetic clipping and deliberately malformed migration JSON. Restore threw; the subsequent empty quit-save returned false. After removing only the malformed metadata, the original clipping was recovered intact. A separate test proves unattempted restore cannot save, while successful restore can. Both tests first failed because the persistence gate did not exist.

### Sticky paste

Sticky Paste now converts an open popover into the shared panel (or keeps the existing panel), leaves it visible across app deactivation and orders it without making it key. PasteService activates the prior destination; successful paste does not reactivate Flycut. Non-sticky Paste still dismisses. The successful OS paste path cannot be manually checked without granting Accessibility permission; permission was not changed. This is an implementation fix, with real permitted-paste verification remaining a release gate.

### Additional UI observations

QA used a separate disposable bundle/domain, `com.edynamics.flycut.preview.task7qa`, and its own Application Support directory containing only Synthetic Alpha, Beta and Gamma. Neither the normal preview defaults/data nor production defaults/data were replaced or read. Capture was paused immediately after opening each test session. The only clipboard write was the explicitly selected synthetic Beta Return action; no clipboard contents were read by development tools.

| Check | Observation |
| --- | --- |
| Populated Down navigation | Pass: highlight visibly moved from Alpha to Beta while search retained focus. |
| Return action | Pass for denied-permission flow: selected Beta was copied and palette displayed “Copied. Allow Accessibility access to paste automatically.” |
| Favorite | Pass: Beta disappeared from Recents and appeared selected in Favorites. |
| Clear confirmation | Pass: Clear All Recents opened an alert explicitly retaining Favorites; Cancel returned without removing synthetic rows. |
| Export entry point | Pass: selected favorite opened NSSavePanel with Flycut filename; cancelled without writing a file. |
| Real global shortcut | Pass: Shift-Command-V sent from a separately built disposable synthetic text app presented the QA history panel with search focused. No reopen command was used for this check. |
| Light appearance | Pass: populated rows, metadata, selection, search and footer visually legible without clipping. |
| Dark appearance | Pass: an isolated copy of the package under `/tmp/flycut-task7-dark` changed only app startup appearance to Dark Aqua. The identical views were visually inspected with synthetic rows; text/metadata/selection and controls remained legible. No system or user appearance setting was changed. An earlier app-local AppleInterfaceStyle preference did not change the appearance and was not counted as a pass. |
| Escape | Pass with temporary QA-only diagnostic: real Escape produced keyCode 53 in the owned window; immediately afterward `panel.isVisible=false` and `popover.isShown=false`. Follow-up CUA inspection re-presented the window, explaining earlier misleading screenshots. Production also handles Escape/Return/keypad Enter by hardware code and SwiftUI exit command; an added test covers empty-character Escape/keypad Enter. |
| Status-item click/anchor | **Blocked by UI tool**, not marked passed: status-only QA/preview app selection timed out without a panel; app snapshots expose only the palette window. A SystemUIServer selection also timed out. The documented CUA `listWindows` method was unavailable. No menu-bar coordinate was guessed. |

The QA app was quit through its own Quit command. Process listing confirmed no FlycutMac remained. The synthetic target was terminated, and disposable QA defaults/database were removed. The original preview state needed no restoration because it was never replaced. The temporary appearance/visibility diagnostics were confined to the isolated QA harness and are absent from the production sources.

Final verification: all 80 XCTest tests pass (58 core, 22 platform); Debug bundle and strict signature check pass. Remaining manual release checks include the blocked status-item anchor, successful authorized paste/sticky focus, full-screen Space, VoiceOver, additional populated navigation keys, actual export contents and merge interactions. Unit tests cover selection boundaries, search identities, keyboard commands, merge order and history actions.
