# Flycut Evolution implementation plan

Spec: [Flycut Evolution interaction and presentation](../specs/2026-09-26-flycut-evolution-interaction-design.md)

Work in the existing isolated `feat/swift-rewrite` worktree. Do not launch or replace the installed production app while writing code. Preserve the 2.0 source backup and the current signed candidate until the replacement is verified.

## File map

- `Sources/FlycutCore/PaletteSelection.swift`: rename Return's action to activate.
- `Sources/FlycutMac/Palette/PaletteModel.swift`: activation independent of the obsolete preference.
- `Sources/FlycutMac/Palette/PaletteView.swift`, `PaletteRow.swift`: row gesture, compact layout, controls/help copy.
- `Sources/FlycutPlatform/Paste/FocusedEditableTarget.swift`: content-free focused-field check.
- `Sources/FlycutPlatform/Paste/PasteService.swift`: inject check and fail closed before key event.
- `Sources/FlycutMac/AppCoordinator.swift`: activation result/messages and UI wiring.
- `Sources/FlycutCore/Settings/{Settings,SettingsStore,LegacySettingsMapper}.swift`, `Sources/FlycutMac/MenuBarController.swift`, `SettingsView.swift`, `MigrationView.swift`: new dimensions and one-time existing-settings migration.
- `App/AppInfo.plist`, `scripts/{build-app,verify-app}.sh`, `.github/workflows/release.yml`, `Sources/FlycutMac/Settings/AboutView.swift`, active docs: visible brand/artifact names while retaining bundle ID and version.
- Existing focused test files under `Tests/FlycutCoreTests`, `Tests/FlycutPlatformTests`, `Tests/FlycutMacTests`.

## Task 1: Activation command and model

- [ ] Update `Tests/FlycutCoreTests/PaletteModelTests.swift` so Return/keypad Return resolve to `.activate` and editing search still allows Return; run `swift test --filter PaletteModelTests` and observe the expected compile failure.
- [ ] Rename `PaletteCommand.paste` to `.activate` and the Return resolver in `Sources/FlycutCore/PaletteSelection.swift`; update coordinator dispatch.
- [ ] Replace the old `testRowActivationHonorsCopyPreference...` in `Tests/FlycutMacTests/PalettePreferencesTests.swift` with a test that activation emits `.activate` regardless of `menuSelectionPastes`. Run the focused test to observe failure before implementing.
- [ ] Implement `PaletteModel.activateSelection()` as the shared double-click/Return/accessible action; remove the unused model Copy callback. Run focused tests green and commit.

## Task 2: Paste only into editable focus

- [ ] Add focused `InteractionTests` for trusted editable focus (one paste event), trusted no focus or noneditable focus (one clipboard write, zero paste events, distinct Copy result), changed focus during the wait (Copy only), Accessibility denial, clipboard replacement, and cancellation. Add the `PasteClient` injection and verify the focused tests fail before production changes.
- [ ] Add `FocusedEditableTarget.isEditable(processID:) -> Bool` using `AXUIElementCreateApplication`, `kAXFocusedUIElementAttribute`, role whitelist (text field, text area, combo box), `kAXEnabledAttribute`, and `AXUIElementIsAttributeSettable` for `kAXValueAttribute`. It reads no value/text. Unknown roles, missing/disabled focus and AX errors return false.
- [x] Check the frozen target's focused editable state after activation, wait, frontmost/permission and clipboard checks, immediately before sending layout-aware Cmd-V. Add `.copiedNoEditableTarget`; route it to a concise Copy fallback message. Update all test fixture clients. Run focused and full Swift tests; commit.

## Task 3: Taller, narrower palette and existing settings

- [ ] Add `PalettePreferencesTests` for 460 × 700 default on a large screen and small-screen fitting. Add `SettingsTests` for one-time migration of a stored 500 × 320 layout, preservation of custom dimensions and persistence of later user edits. Watch focused tests fail first.
- [x] Set new defaults in `FlycutSettings`, legacy missing-dimension mapping, and panel/popover initial size; add a one-time dimension migration in `SettingsStore` using a dedicated marker. Do not replace explicit custom values. Compact palette/row spacing and padding while retaining two-line text and source-app metadata.
- [ ] Keep single-click selection; make double-click and accessible Activate run the same automatic action; remove the double-click preference UI and separate Copy/Paste controls from footer/context menu. Remove relative time, keep the source app, and tighten row spacing. Keep favorite, export, delete, help, pause, and settings. Update help, privacy and migration explanations. Run full Swift suite and Debug build; commit.

## Task 4: Product name and packaging

- [ ] Add a failing bundle-verification check and product smoke assertions for `Flycut Evolution` display name, `com.edynamics.flycut`, and 3.0.0. Exercise the release-note extraction locally to catch stale `Flycut 3.0` copy.
- [ ] Set visible title in `PaletteView` and About; update `AppInfo.plist`, build/verify scripts, Release workflow/app and DMG filenames, README, CHANGELOG, release setup and current developer notes. Keep historical 2.0 notes and credits. The GitHub release name is `Flycut Evolution`; the tag stays `v3.0.0`.
- [ ] Run `swift test`, Debug build, universal Release build, `scripts/verify-app.sh` and release-note extraction. Refresh Graphify; commit and push.

## Task 5: Acceptance and cutover

- [ ] Run an isolated synthetic macOS 27 UI pass for single-click selection, double-click/Return activation, taller layout without relative time, no-field Copy fallback, and (only after user-approved Accessibility access) real paste into a disposable editable target. Check no double paste and no clipboard/history loss. Do not print real clipboard text.
- [ ] Review status-item anchoring, VoiceOver and non-QWERTY limits honestly; request user action only for checks the desktop tool cannot perform. Update `docs/QA-swift.md` with observed evidence.
- [ ] Push final branch, require green Swift/legacy CI and a manual nonpublishing signed/notarized release; verify downloaded DMG. Safely quit the current installed candidate, back up v3 data, install the new signed `Flycut Evolution.app` beside it, verify 50 restored records and settings, then remove the superseded app copies only after success.
- [ ] Mark PR #7 ready, merge to master, update local master, publish `v3.0.0`, verify public artifact and release notes, refresh QMD and Graphify on master, and delete the merged feature branch/worktree. Preserve the public v2.0.0 release and original project attribution.

## Review focus

- No editable field or AX failure: clipboard changes once and no synthetic key is sent.
- Focus changes during activation: no paste into the wrong app or control.
- A double click: one activation and one Paste event maximum; a single click only selects.
- An old 500 × 320 saved layout: upgrades once; a custom size never changes.
- Current `com.edynamics.flycut` database: retains 50 records and a migration marker after the named-app replacement.
