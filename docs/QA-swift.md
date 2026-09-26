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

`AppCoordinator.showSettings` is the settings entry-point callback. Its current dialog explicitly says the grouped editor is forthcoming. Use `settings` and `configure(_:)` to connect the settings window. The coordinator owns one hotkey service and attempts to restore the previous shortcut after registration failure; if both fail it displays a disabled message. Dynamic save modes are checked at each persist operation; `.never` never opens, restores or saves disk history during a launch in that mode. Choosing `.never` does not erase an existing saved database.

Settings still must supply the grouped editor, explicit remember-pause preference, icon/appearance application, save-mode transition UX, and eviction autosave. The current sticky option keeps Copy open; automatic Paste dismisses to restore destination focus. Define and verify persistent sticky-paste behavior in Task 8/10. Migration UI remains the later migration task; this shell does not automatically import legacy data.
