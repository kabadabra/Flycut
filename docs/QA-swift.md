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

## Sticky target tracking revision — 2026-09-26

The coordinator now listens for workspace app-activation notifications throughout its lifetime and records the latest external process, ignoring Flycut itself. This covers clicking an already-visible sticky panel after switching from app A to app B, without relying on the presentation callback. The action samples the foreground app once more, freezes the recorded target before starting its paste task, and leaves PasteService's cancellation/focus guards intact.

A deterministic synthetic regression models A → Flycut → B → mouse reactivation of Flycut, then activates C during the paste focus wait. It verifies that the request activates/checks B, never redirects to A or C, and emits no paste after B loses focus. Another test verifies that own-app and unknown-foreground events do not erase the last external target. Tests initially failed for the missing target-tracking API, then passed with the implementation.

Final verification: 82 tests pass (58 core, 24 platform); Debug bundle/strict signature pass; Graphify refreshed. No UI or clipboard interaction was needed for this revision, and process check confirms no preview or synthetic target remains running. Authorized real paste with app switching remains a Task 10 release check; the controller retains status-item click/anchoring as the explicitly tracked tooling-blocked gate.

## Task 8 — Settings, onboarding and import — 2026-09-26

This section supersedes the Task 7 placeholder-settings integration notes. Settings now has General, Shortcuts, Privacy, Appearance and About tabs, a working shortcut recorder, login/permission adapter actions, typed settings editing, pause restoration, app appearance/icon selection, save-mode recovery and automatic exports before capacity eviction. Automatic exports require a chosen folder and are disabled in save-never mode. An export failure aborts capacity eviction; a filesystem failure after an earlier export can leave an extra recoverable export file.

Production-only onboarding is gated by the exact production bundle identity and absence of a migration marker. Preview builds do not discover production profiles. Manual imports use the file picker, require source selection and explicit review, require merge/replace for a populated destination, and require memory/persistent choice for save-never sources. Source and destination fingerprints reject stale previews. Import does not enable login or adopt an old automatic export folder; those require separate Settings choices. The import window displays unsupported-setting warnings, skipped records and backup locations. The working repository is shared with memory imports, so importing into a populated memory session cannot bypass destination confirmation.

Saving can be enabled only after a full disk snapshot is readable. Existing saved data is staged separately; a modal shows saved/session counts and requires explicit Load Saved History before replacing session memory. Cancel and read failure revoke saving permission, leave disk untouched, and retain session memory. The UI instructs the user to export session clippings before accepting replacement or quitting. Retry Saved History permits recovery after the underlying database is repaired; no automatic repair or replacement of unread data is attempted.

### Automated evidence

- Import-decision tests were written before the decision API existed and initially failed to compile for the missing API; all six now pass. They cover multiple sources, explicit populated-destination choice, save-never choice, cancel without mutation, failed import/retry, production identity gating and a disposable legacy profile with synthetic recents/favorites/settings.
- Failed-preview-refresh regression initially failed for the missing invalidation API, then passed: an unsuccessful refresh cannot reuse an earlier confirmation.
- Stale-preview regression initially failed for missing fingerprint API, then passed: changing either source bytes or destination history requires new confirmation before backups or import.
- Pause/appearance settings round-trip initially failed for missing typed fields, then passed.
- Eviction tests cover recents and favorites, exact synthetic export bytes, private 0600 permissions, deletion not exporting, and failed export retaining the old clipping. The first test initially failed for the missing archive API.
- Final `swift test`: **92 XCTest tests, zero failures** (68 core, 24 platform). No compiler warnings or errors. Existing unread-destination, persistence, import backup/idempotency and hotkey/login/permission adapter regressions remain green.
- `scripts/build-app.sh debug`: successful, strict ad-hoc signature verification passes.
- `graphify update . --no-cluster`: successful; graph artifacts remain ignored.

### Actual manual observations

QA used `/tmp/Flycut Task8 QA.app`, bundle/domain `com.edynamics.flycut.preview.task8qa`. It had its own disposable preferences and Application Support directory. Capture was paused before its first launch and stayed paused across all sessions. No installed Flycut 2.0 application, production profile, private clipboard contents, permissions or login registration were changed or inspected.

- Opened all settings sections used by the flow. General and import views were inspected in light appearance; applying app-only Dark visibly updated Settings. Privacy buttons were changed to a vertical layout after the initial inspection exposed truncated labels; the corrected view was inspected successfully.
- Imported a synthetic save-never plist with two recents, one favorite, one malformed record and an unsupported iCloud flag. Preview showed counts, warnings and disabled Import until storage and confirmation were selected. Chose memory only and imported three clips. The QA history directory did **not** exist afterward.
- Imported a second synthetic, disposable 2.0-shaped profile at `Library/Preferences/com.edynamics.flycut.plist` with on-quit saving. Preview showed the existing 2+1 destination and required an explicit Merge choice. Resulting recent capacity rose to four. Completion showed source/destination backup paths. Both files had 0600 permissions. This exercised legacy profile structure; the old 2.0 executable itself was not launched.
- Synthetic palette visibly contained four recent rows and two favorites after merge. Quitting saved only the QA database. Relaunch restored those counts and Capture paused. A count-only database query independently confirmed 4 recents/2 favorites.
- Retry Saved History showed saved/session counts and explicit Cancel/Load choices. Cancel returned without replacing the session; a second attempt with Load succeeded. Unread/corrupted destination handling is covered by automated regressions, not a new manual corruption run.
- Edited comma-separated privacy lengths to `12, 24, 48` and applied successfully. Lists now retain editable raw text until Apply and reject invalid length entries.
- Initial accessible button activation did not start shortcut recording because the custom button only handled mouse-down. Changed it to target/action, rebuilt and verified accessibility activation focuses the recorder. Control–Option–X recorded and applied; reset to Shift–Command–V also applied.
- Preview quit through its own Quit command after QA. Process inspection found no FlycutMac process left running. Disposable app/domain/data were cleaned up after evidence collection.

### Task 10 implementation and release checklist

The product is **not feature-complete**. Import explicitly warns before confirmation that the following mapped legacy preferences have no current preview effect. Each needs implementation and tests, or an explicit spec-consistent removal/migration rationale:

- [ ] `menuPreviewCount` / legacy `displayNum`: apply the configured visible menu preview count to the palette/menu presentation without discarding stored clips or hiding searchable history.
- [ ] `bezelWidth`, `bezelHeight`: apply user dimensions to the palette/popover while preserving usable minimum sizes and screen bounds; expose working controls.
- [ ] `bezelAlpha`: apply transparency to the palette background without fading text or reducing readability; expose a working control.
- [ ] `popUpAnimation`: honor the optional presentation animation and Reduce Motion behavior; expose a working control.
- [ ] `menuSelectionPastes`: specify and implement copy-versus-paste activation semantics for the new palette (including mouse and keyboard) and test prior-app restoration.
- [ ] `revealPasteboardTypes`: reveal type metadata only through explicit UI, without logging clipboard contents; expose a working control.
- [ ] `suppressAccessibilityAlert`: define whether this suppresses an automatic prompt while retaining the visible Copy fallback and permission links; the preview currently never issues an automatic Accessibility prompt.
- [ ] Real Open at Login registration/approval and permission-grant paths on a disposable signed install. QA used adapter tests and inspected buttons, without changing system permissions or login items.
- [ ] Native production onboarding with multiple discoverable profiles in a disposable user account, unread-container picker recovery, UI replace flow, actual repaired-database recovery, and an older Flycut-generated profile. Automated fixtures cover these decisions/data shapes but do not replace that release gate.
- [ ] Repeat complete palette/manual release gates from Task 7: status-item anchoring, authorized paste/sticky focus, VoiceOver, full-screen Space, non-QWERTY input, export/eviction folder interaction, and signing/notarization/downloaded-install checks.

## Task 8 review fixes — 2026-09-26

The production settings source collision is fixed: application settings use the independent `<bundle identifier>.settings.v3` preferences suite (`com.edynamics.flycut.settings.v3` for production, `com.edynamics.flycut.preview.settings.v3` for preview). There is no fallback to `.standard`, and SettingsStore requires an explicit backing store. Previous preview settings in the old app domain are not automatically adopted. New production startup/configuration/import settings writes cannot target the legacy `com.edynamics.flycut` source plist.

A new FlycutMacTests target tests the actual AppCoordinator with injected synthetic preferences, repositories, storage paths and recovery confirmation. The production-shaped test asserts the exact new domain requested, runs the startup configure and import-adoption settings writes, synchronizes the synthetic defaults and verifies the legacy source bytes are unchanged. It never opens the real production suite or source file and does not launch the AppKit shell or clipboard monitor.

Recovery now returns the restored snapshot to the settings application path. Its counts raise the pending editor proposal before configure, preventing a stale capacity of 40 from replacing the recovered capacities. The coordinator regression restores 100 recents/60 favorites from disk, changes only Never → On Quit, then captures through the coordinator's configured history service: 100 recents/60 favorites remain. A later, separate explicit capacity reduction is still accepted.

Save-never onboarding now inspects the saved database's migration metadata through a read-only SQLite connection and a metadata-only query. It does not call snapshot or restore clipping rows. Missing databases are not created; metadata read/decoding errors propagate and display an explicit warning instead of being treated as no migration. Tests verify a durable marker suppresses production onboarding while the working repository stays empty, marker inspection succeeds even when the clips table is absent, corrupted metadata throws, and an absent database creates no files.

Verification: initial coordinator test run failed for the missing injectable/application APIs. All seven focused coordinator/persistence tests pass after the fixes. Full `swift test` passes **97 XCTest tests** (70 core, 24 platform, 3 coordinator), with zero failures/warnings; Debug build/strict signature and Graphify refresh pass. No GUI app or clipboard monitoring was started for this revision. Existing Task 10 implementation/manual release gates remain open.
