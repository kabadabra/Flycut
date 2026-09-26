# Flycut Swift Rewrite Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a fully working, signed and notarized Swift Flycut 3.0 for macOS 27 with safe import from Flycut 2.0 and original Flycut settings.

**Architecture:** A Swift Package separates Foundation/SQLite history and migration (`FlycutCore`), AppKit/Carbon/ServiceManagement adapters (`FlycutPlatform`), and a SwiftUI macOS executable (`FlycutMac`). A packaging script produces the `.app`; the existing Objective-C release remains available until cutover.

**Tech Stack:** Xcode 27.0, Swift 6 language mode / Swift 6.4 compiler, macOS 13+, SwiftUI, AppKit, Carbon global hotkey, SQLite3, XCTest, Developer ID/notarytool.

**Spec:** `docs/superpowers/specs/2026-09-26-swift-rewrite-design.md`

## Global Constraints

- Production ID `com.edynamics.flycut`, preview ID `com.edynamics.flycut.preview`, production version `3.0.0`, Apple team `M2L9SL9WCS`.
- Preserve exact clipping text, both collections, order, duplicates, metadata, and source settings on import. Never change or delete source preferences.
- The released 2.0 app and tag remain usable until 3.0 passes migration, menu, hotkey, paste, signing, notarization, and install checks.
- No third-party runtime dependency, CloudKit promise, clipboard-content logging, or telemetry.
- Keep original Flycut and Jumpcut attribution, MIT license, and contributor credits.

## Review Focus

1. A delayed pasteboard provider changes while being read: the monitor must discard the stale result. Pin in Task 5.
2. Existing favorites and duplicates from a legacy plist: migration must retain every clipping and ordering even when duplicate removal is enabled. Pin in Task 4.
3. A legacy `savePreference=0`: importing must not persist history without an explicit new save choice. Pin in Task 4.
4. A non-QWERTY keyboard layout and denied Accessibility: Copy still works; Paste is gated and uses the layout-correct shortcut when allowed. Pin in Task 6.
5. A 2.0 app left installed with the same bundle ID: the upgrade path must select the new executable by path and retain a recoverable source. Pin in Task 10.

---

### Task 1: Swift package, app bundle, and clean baseline

**Files:** Create `Package.swift`, `Sources/FlycutCore/Clip.swift`, `Sources/FlycutPlatform/PlatformMarker.swift`, `Sources/FlycutMac/FlycutApp.swift`, `App/AppInfo.plist`, `scripts/build-app.sh`, `Tests/FlycutCoreTests/PackageSmokeTests.swift`; modify `.gitignore`.

**Interfaces:** `Clip` begins as a typed value used by later tasks. `scripts/build-app.sh debug|release` builds with SwiftPM and creates `build/Export/Flycut.app` for release or `build/Preview/Flycut Preview.app` for debug, with matching IDs and version keys.

- [ ] Add a Swift 6 package with `FlycutCore`, `FlycutPlatform`, `FlycutMac`, and test targets, macOS 13 deployment floor, and system framework/SQLite3 links.
- [ ] Write a package smoke test asserting the `Clip` module imports and the version constant is `3.0.0`; run `swift test` to establish red, then implement the minimum model and rerun green.
- [ ] Package the executable with Info.plist, the existing icon, owner-correct app structure, and preview/production identities; verify both builds with `PlistBuddy`, `file`, and `codesign --verify` after ad hoc signing.
- [ ] Keep the old Xcode build unchanged; commit the new runnable skeleton.

### Task 2: History model and transactional repository

**Files:** Create `Sources/FlycutCore/History/Clip.swift`, `HistoryRepository.swift`, `SQLiteHistoryRepository.swift`, `HistoryService.swift`; test `Tests/FlycutCoreTests/HistoryRepositoryTests.swift`. Move the Task 1 clip stub into the final path.

**Interfaces:** `Clip(id: UUID, text: String, pasteboardType: String, sourceAppName: String?, sourceBundleURL: String?, capturedAt: Date?)` is `Codable`, `Equatable`, and `Sendable`; `CollectionKind.recent|favorite`; `HistorySnapshot(recent:favorites:migration:)`. `HistoryRepository: Sendable` exposes `snapshot() async throws -> HistorySnapshot`, `apply(_ change: HistoryChange) async throws -> HistorySnapshot`, and `replaceAll(_ snapshot: HistorySnapshot) async throws`. `SQLiteHistoryRepository` is an actor, and each `apply` or `replaceAll` is one transaction. `HistoryService` adds capacity, duplicate, search, merge, and favorites decisions.

- [ ] Write failing tests for newest-first order, separate favorites, same-text duplicates, optional dedupe, bounded eviction, search mapping, merge oldest-to-newest, and atomic rollback on error.
- [ ] Implement the versioned SQLite schema and service. Keep `Position` as order only; do not make text unique. Set owner-only file/directory permissions and `PRAGMA user_version=1`.
- [ ] Run `swift test --filter HistoryRepositoryTests`, then the full suite, and commit.

### Task 3: Typed settings and legacy key mapping

**Files:** Create `Sources/FlycutCore/Settings/Settings.swift`, `SettingsStore.swift`, `LegacySettingsMapper.swift`; test `Tests/FlycutCoreTests/SettingsTests.swift`.

**Interfaces:** `FlycutSettings` contains the old user-facing controls with validated defaults; `SettingsStore` persists `v3.*` keys; `LegacySettingsMapper.map(_:)` returns settings plus warnings for unsupported values. CloudKit flags always map to off.

- [ ] Write failing tests for all defaults, invalid capacities and alpha/size clamps, hotkey dictionary conversion, save modes 0/1/2, privacy skip lists, URL preferences, icon/source settings, and true legacy CloudKit flags.
- [ ] Implement the typed model and mapper using top-level preference keys first and nested `store` settings only as fallback.
- [ ] Run filtered and full tests, commit.

### Task 4: Lossless, repeatable migration

**Files:** Create `Sources/FlycutCore/Migration/LegacyStoreParser.swift`, `MigrationCoordinator.swift`, `MigrationReport.swift`; test `Tests/FlycutCoreTests/LegacyMigrationTests.swift` with synthetic plist fixtures under `Tests/FlycutCoreTests/Fixtures/`.

**Interfaces:** `LegacyStoreParser.parse(data: Data) throws -> LegacySnapshot`; `MigrationCoordinator.preview(source:destination:) async throws -> MigrationReport`; `MigrationCoordinator.import(source:choice:) async throws -> MigrationReport` backs up source/destination, writes clips and marker in one transaction, and returns counts and warnings. Choices are import, merge, and replace; merge/replace require explicit confirmation when destination is nonempty. Save-never uses an in-memory SQLite repository until the user explicitly selects a persistent save mode.

- [ ] Write failing fixture tests for 0.7 plist shape, newest-first recents/favorites, exact Unicode and multiline text, duplicates with differing types, optional metadata, timestamp 0/large values, stale Position, oversized lists, malformed records, absent store, multiple domains, rerun idempotency, and save mode 0 in-memory behavior.
- [ ] Implement source discovery for `com.edynamics.flycut`, `com.kabadabra.flycut`, sandboxed `com.generalarcade.flycut`, and user-selected files. Treat denied container access as a file-picker case.
- [ ] Implement private backup and transaction rules; never mutate source. Document every skipped malformed clipping in the preview and abort if nothing valid is importable.
- [ ] Run migration tests and the full suite, commit.

### Task 5: Clipboard capture and privacy policy

**Files:** Create `Sources/FlycutCore/Capture/CapturePolicy.swift`, `Sources/FlycutPlatform/Clipboard/PasteboardClient.swift`, `ClipboardMonitor.swift`; test `Tests/FlycutCoreTests/CapturePolicyTests.swift` and `Tests/FlycutPlatformTests/ClipboardMonitorTests.swift`.

**Interfaces:** `PasteboardClient` exposes change count, advertised types, and plain-text read; `ClipboardMonitor` emits accepted `Clip` events to the core. It starts from the current count, polls each second, and records a self-write count supplied by PasteService.

- [ ] Write failing tests for no launch clearing/read, one event per change count, delayed provider mismatch, own write suppression, empty/same-top text, transient/concealed/password types, optional length rules, and denied read.
- [ ] Implement the main-actor monitor and pure capture policy; source app metadata and Unix timestamp are attached only to accepted text.
- [ ] Run filtered and full tests, commit.

### Task 6: Hotkey, paste, Accessibility, and login adapters

**Files:** Create `Sources/FlycutPlatform/Hotkey/HotkeyService.swift`, `KeyboardLayout.swift`, `Paste/PasteService.swift`, `AccessibilityService.swift`, `LoginItemService.swift`; test `Tests/FlycutPlatformTests/InteractionTests.swift`.

**Interfaces:** `HotkeyService.register(_:)` reports conflicts/errors; `PasteService.copyOrPaste(_:mode:previousApp:)` returns copy/paste/permission result; `KeyboardLayout.keyCode(for:)` maps the current layout's paste key; `LoginItemService` exposes registered/requiresApproval/error status via `SMAppService.mainAppService`.

- [ ] Write failing tests with injected hotkey/event/layout clients for default Shift-Command-V, register/unregister, non-QWERTY mapping, denied Accessibility copy fallback, own pasteboard count, and focus restoration order.
- [ ] Implement thin Swift wrappers for Carbon hotkey registration, AppKit/CGEvent paste, AX trust and System Settings link, and ServiceManagement login registration.
- [ ] Run filtered and full tests, commit.

### Task 7: Menu bar shell and modern history palette

**Files:** Create `Sources/FlycutMac/AppCoordinator.swift`, `MenuBarController.swift`, `Palette/PaletteModel.swift`, `PaletteView.swift`, `PaletteRow.swift`, `PalettePanel.swift`; update `FlycutApp.swift`; add `Tests/FlycutCoreTests/PaletteModelTests.swift` if pure selection logic lives in core.

**Interfaces:** The coordinator wires repository, settings, monitor, hotkey, and paste service. One palette model backs a status-item popover and shortcut panel; selection actions call HistoryService.

- [ ] Test pure selection/search/favorite and keyboard-action state before UI wiring.
- [ ] Build the status item, SwiftUI searchable palette, recents/favorites switch, source/time display, pause control, clear confirmation, merge, export, settings/About/Quit commands, and keyboard/mouse actions from the spec.
- [ ] Build the preview app and manually check menu click, search focus, arrow/Return/Escape, hotkey panel, dark/light appearance, and no clipboard mutation on launch; record observations in `docs/QA-swift.md`.
- [ ] Commit the working preview shell.

### Task 8: Settings, onboarding, and import UI

**Files:** Create `Sources/FlycutMac/Settings/SettingsView.swift`, `Migration/MigrationView.swift`, `PermissionView.swift`, `AboutView.swift`; update coordinator and `AppInfo.plist`; test migration view-model decisions in `Tests/FlycutCoreTests/MigrationViewModelTests.swift`.

**Interfaces:** First production launch checks for legacy sources and shows a source/count preview. Settings groups General, Shortcuts, Privacy, Appearance, About; all controls read/write typed settings. Import UI displays backups, invalid entries, and explicit merge/replace choices.

- [ ] Test multi-source choice, nonempty destination confirmation, save-never choice, cancel without mutation, and retry after failed import.
- [ ] Implement migration/onboarding and permissions copy; wire the file picker and System Settings links.
- [ ] Exercise synthetic and disposable 2.0 profile imports, inspect recents/favorites/settings without reading private user clipboard content into logs, commit.

### Task 9: CI, release packaging, and active-build cutover

**Files:** Modify `.github/workflows/build.yml`, `.github/workflows/release.yml`, `RELEASE_SETUP.md`, `readme.md`, `CHANGELOG.md`, `docs/DEVELOPING.md`; create `scripts/verify-app.sh`; keep the old Objective-C files as historical source outside the active Swift build until release review.

**Interfaces:** `swift test`, `scripts/build-app.sh release`, and `scripts/verify-app.sh build/Export/Flycut.app` are the local/CI gates. Tagged release signs the Swift app and DMG, notarizes/staples, then publishes only on a valid `vX.Y.Z` tag.

- [ ] Make CI build/test the Swift package on Xcode 27. Keep a separate legacy 2.0 build job until Swift QA passes, then remove it from the active gate.
- [ ] Update release script to package the Swift executable, verify ID/version/team, sign and notarize the app and DMG, and keep manual dry runs nonpublishing.
- [ ] Document macOS 13 floor, honest no-sync status, safe migration and duplicate-app removal, source credits, and new keyboard/UI behavior.
- [ ] Run local tests/build, CI, and a signed/notarized manual dry run; commit and review.

### Task 10: Real-machine acceptance and 3.0 release

**Files:** Update `docs/QA-swift.md`, `CHANGELOG.md`, release notes, and any fixes exposed by QA.

**Interfaces:** A public `v3.0.0` GitHub Release with `Flycut.dmg`; the original `v2.0.0` release and its asset remain unchanged.

- [ ] Exercise every macOS 27 interaction in the spec, including a full-screen app, multiple keyboard layouts where available, clipboard permission denied/allowed, Accessibility denied/allowed, login approval, and migration from synthetic and disposable legacy profiles.
- [ ] Review code and migration behavior, fix failures, run `swift test`, app build, `codesign --verify --deep --strict`, and `git diff --check`; regenerate Graphify with `graphify update . --no-cluster` after code changes.
- [ ] Merge the reviewed branch into `master`, delete temporary feature branches, tag `v3.0.0`, verify the public CI run and downloaded DMG with stapler/Gatekeeper, and install the published build only after preserving the user's 2.0 data.
- [ ] Confirm the new app launches, imports history/settings, captures a new clip, and can copy/paste with granted permissions; document any user action needed for macOS privacy approval.
