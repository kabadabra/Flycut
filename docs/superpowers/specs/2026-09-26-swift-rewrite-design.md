# Flycut Swift Rewrite Design

## Outcome and scope

Build Flycut 3.0 as a complete Swift macOS replacement for the Flycut 2.0 direct-download app. The product remains free, open source, named Flycut, maintained by Emerging Dynamics, and visibly credited as a fork of TermiT/Flycut and Jumpcut. A user should be able to install the new app, import existing settings and saved clippings without losing the source, use the menu bar and Shift-Command-V workflow on macOS 27, and receive a signed, notarized update.

The active macOS product moves to Swift 6 language mode with the Swift 6.4 compiler in Xcode 27.0 and a macOS 13.0 deployment target. Flycut 2.0 remains available for macOS 12 users. The dormant iOS source is outside this macOS rewrite and will not be built by the new project. CloudKit sync is not provisioned for this fork and is not presented as a working feature.

## Why this shape

Three approaches were considered:

1. Port the Objective-C classes line by line. This would preserve coupling between clipboard polling, UI, defaults, and CloudKit and make the old concurrency and focus problems harder to isolate.
2. Use only SwiftUI scenes, including `MenuBarExtra`. This would simplify ordinary views but gives less control over global shortcut presentation, app activation, and the status item behavior that needed a macOS 27 fix.
3. **Chosen:** build a new Swift core, keep a small AppKit shell for the status item, keyboard events, and panel placement, and render the palette and settings in SwiftUI. This keeps platform-sensitive interactions explicit while allowing a modern, testable UI.

The rewrite will live in a Swift Package that Xcode can open directly, with a small checked-in script that bundles its executable, Info.plist, and icon into a normal `.app`. This avoids adding a generated project or project-generation dependency. Flycut 2.0 continues to build during development. At the final cutover, release automation points to the new app and unused Objective-C macOS code and bundled libraries leave the active build. The Git history retains the original code and attribution.

## Identity and upgrade boundary

- Production bundle ID: `com.edynamics.flycut`; version: `3.0.0`; app display name: `Flycut` with version shown in About and release notes. Its Developer ID team remains `M2L9SL9WCS`.
- Development preview bundle ID: `com.edynamics.flycut.preview`. Preview data lives separately and cannot automatically alter the installed Flycut 2.0 history.
- Keep the MIT license, original author credit, upstream remote, and contributor PR links in the README and release notes.
- Do not publish or replace the installed 2.0 app until the migration, paste, menu, accessibility, and notarized installation gates pass.
- The upgrade guide tells users to quit Flycut 2.0, launch the new `Flycut.app` by path, complete migration, and only then remove the old `Flycut 2.0.app`. The two bundles share an identity, so both should not remain installed after migration.

## Components and data flow

`FlycutCore` is a Swift package with no UI dependency. It owns `Clip`, `HistoryStore`, `Settings`, `LegacyImporter`, capture policy, and selection behavior. `FlycutMac` is the app target. `ClipboardMonitor` observes `NSPasteboard.general.changeCount` and submits text snapshots to the core on the main actor. `HotkeyService` uses the system global-hotkey API from Swift; `PasteService` writes selected plain text, records its own change count, returns focus to the previous app, and sends the layout-correct Paste shortcut only when Accessibility is granted. `LoginItemService` wraps `SMAppService.mainAppService`.

The UI has one shared palette model. Clicking the status icon anchors it beneath the menu bar; Shift-Command-V presents it on the active screen without losing the prior paste target. The palette has search, recent and favorite lists, source app and timestamp metadata, keyboard navigation, pause capture, clear, merge, save to file, settings, About, and Quit. SwiftUI provides native materials, light/dark appearance, VoiceOver labels, and keyboard focus. An AppKit coordinator owns the status item, popover/panel, and focus transitions. Settings are grouped as General, Shortcuts, Privacy, Appearance, and About rather than mirroring the old nib tabs.

## History and settings

Store history and favorites in a versioned SQLite database under the app's Application Support directory. A clip has a stable UUID, exact text, pasteboard type, source app name and bundle URL when available, capture timestamp, collection, and order. Transactions preserve order and make insertion, move-to-top, deletion, capacity trimming, merge-all, and import atomic. The database and directory are user-only; no clipboard text appears in logs or analytics. Write-ahead logging and schema migrations are explicit. A repository protocol allows in-memory fakes for tests.

New settings use namespaced keys separate from the old `NSUserDefaults` keys. Defaults remain familiar: 40 recent and 40 favorite clips, 10 menu previews, 40 preview characters, Shift-Command-V, password-type skipping on, duplicate removal off, and Open at Login off. Support the old save modes (never, on quit, after each clip), favorites, search, skip rules, wraparound, sticky palette, paste-moves-to-top, icon style, metadata display, manual text export, and optional autosave of evicted clips. Hide the unprovisioned iCloud controls; never enable sync based on imported flags.

## Migration contract

The legacy source is a property list, not an NSCoding archive. `NSUserDefaults` key `store` contains a version `0.7` dictionary with newest-first `jcList` and `favoritesList`. Each clipping has `Contents`, `Type`, and `Position`, with optional `AppLocalizedName`, `AppBundleURL`, and Unix-seconds `Timestamp`. Top-level preferences include history/favorites limits, hotkey, save mode, privacy rules, menu behavior, appearance, and login preference. The importer uses top-level settings first and nested store values only as fallback. It never treats old CloudKit flags as permission to enable sync.

On first production launch, if the new database has no migration marker, detect the current `com.edynamics.flycut` preferences. Show a preview with source, counts, and destination behavior before importing. Also offer import from the earlier `com.kabadabra.flycut` domain, original sandboxed `com.generalarcade.flycut` preferences, or a user-selected `.plist`. A file picker handles containers macOS will not let the app read directly. If several sources exist, the user chooses one; no silent merge. If the destination already has data, require an explicit merge or replace choice and back up the destination first.

The import runs in one transaction, preserves exact text and newest-first order, both collections, metadata, duplicates, and settings as far as supported. Do not cap imported clips to old or new UI limits: raise the new capacity to fit imported data and show the resulting value. Report malformed entries and unsupported settings before confirmation; do not silently discard them. Copy the source plist to a private backup first, leave the source untouched, and record a migration marker containing source identity and time. Re-running the importer with the same source is idempotent. A legacy `savePreference=0` stays privacy-preserving: imported clips are shown in memory unless the user explicitly chooses a persistent save mode.

## Clipboard, privacy, and paste behavior

At launch, record the pasteboard's current change count without clearing or reading its contents. Poll at one-second intervals on the main actor. For a changed count, read plain text once; accept it only if the count is still current after reading. Ignore empty text, a top-of-list duplicate, and self-writes. Apply optional duplicate removal and sensitive-type/length rules before saving. Keep capture paused across relaunch only when the user chose that preference. If macOS denies clipboard access, explain it in the UI and avoid claiming to have saved the copy.

Selecting a clip always offers Copy. Paste requires Accessibility permission; when denied, leave the selected text on the clipboard and offer a direct path to System Settings. Preserve the prior foreground app and use a layout-aware Cmd-V key code so non-QWERTY users can paste. The default Shift-Command-V hotkey remains configurable. The palette supports arrows and `j/k`, Home/End, Page Up/Down, digits, Return to paste, Esc to dismiss, Delete, `f/F` favorites actions, and `s/S` text export; visible help lists the bindings. Clear All touches recents only and confirms; Merge All joins oldest to newest with newlines.

## Verification and release gate

- Unit tests: history ordering and capacity, duplicates, favorites, search, save modes, privacy filters, legacy plist parsing/settings mapping, invalid records, timestamps, Unicode, multiple sources, destination conflict, idempotency, and no source mutation.
- Integration tests: fake pasteboard change counts for launch preservation, delayed/stale reads, own writes, and access denial; hotkey and paste decisions without emitting system events in tests.
- macOS 27 manual UI pass: menu click, search focus, hotkey and keyboard navigation, paste into another app, favorites, light/dark appearance, full-screen Space, VoiceOver, privacy and Accessibility prompts, Login Items approval, and migration from synthetic files and a disposable 2.0 profile.
- CI: Swift package tests and Xcode 27 Debug/Release builds. A release dry run signs and notarizes the new app and DMG; downloaded artifacts pass `codesign`, stapler, Gatekeeper, bundle/team/version checks, and installation on this Mac.
- Preserve the public Flycut 2.0 release. Publish `v3.0.0` only after all gates pass, with a clear upgrade guide and contributor credits. The previous user history remains backed up and recoverable.
