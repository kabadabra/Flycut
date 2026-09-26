# Flycut 3.0

Flycut is a free, open source clipboard manager for macOS, maintained by Emerging Dynamics. This repository is a [fork of TermiT/Flycut](https://github.com/TermiT/Flycut), based on [Jumpcut](http://jumpcut.sourceforge.net/). It retains the [MIT license](license.txt) and [original acknowledgements](acknowledgements.txt).

Flycut 3.0 is the Swift rewrite under release review. Its public release is gated on migration, UI, paste, and signed installation checks. The [published Flycut 2.0 release](https://github.com/kabadabra/Flycut/releases/tag/v2.0.0) remains available, including for macOS 12 users.

## Using Flycut

Copy text normally, then open the searchable palette from the menu bar or **Shift-Command-V**. Switch between recent clips and favorites, pause capture, copy or paste a selection, export text, or adjust the grouped settings. Keyboard help is available in the palette: arrows and j/k, Home/End, Page Up/Down, digits, Return to paste, Escape to dismiss, Delete, f/F favorites actions, and s/S export. Letter shortcuts do not interfere with typing in search.

Flycut 3.0 requires **macOS 13 or later**, on Apple Silicon or Intel. Release bundles contain both architectures. It stores local history; **iCloud/CloudKit sync is not configured or available**. Allow clipboard access when macOS asks. Pasting into another app requires Accessibility permission in System Settings > Privacy & Security > Accessibility. Without that permission, you can still copy a clip and paste it yourself.

## Build locally

Use Xcode 27.0 (Swift 6.4, Swift 6 language mode). Open `Package.swift` in Xcode or run:

```sh
swift test
scripts/build-app.sh debug
open 'build/Preview/Flycut Preview.app'
scripts/build-app.sh release
scripts/verify-app.sh build/Export/Flycut.app
```

The preview has a separate `com.edynamics.flycut.preview` identity and data. Local bundles are ad hoc signed. The production bundle is `build/Export/Flycut.app`, identity `com.edynamics.flycut`, version `3.0.0`. Opening it can start production migration; use the preview for routine development. See [developer notes](docs/DEVELOPING.md) and [release setup](RELEASE_SETUP.md).

## Moving to Flycut 3.0

1. Quit every Flycut instance. Keep the old app and saved preferences until you have checked the import. If history was never saved, export any clippings you need before quitting the old version.
2. Install the reviewed, signed `Flycut.app` from its DMG. Launch **/Applications/Flycut.app** explicitly by path so macOS does not choose the old `Flycut 2.0.app`.
3. Review the migration preview: choose the current fork, an earlier `com.kabadabra.flycut` source, original sandboxed Flycut, or a selected `.plist`. If container access is denied, use the file picker. Choose one source; imports are not silently combined.
4. Check counts, unsupported settings, malformed entries, and the proposed destination. Existing destination data requires a merge or replace choice and a destination backup. The importer copies the source to a private backup and leaves the source untouched. Reimporting the same source is idempotent. Imported history can raise capacity so records are not trimmed. A legacy “never save” setting keeps imported clips in memory unless you explicitly change the save mode.
5. Verify recent clips, favorites, settings, and paste behavior. Keep the backup for recovery. **Only then remove the old Flycut 2.0.app**: both versions use `com.edynamics.flycut` and should not remain installed together. Disable any old login registration and set Open at Login in the new app as needed. Recheck Accessibility permission for the new app.

The original upstream app uses a different identity, but running multiple clipboard managers during migration can confuse capture and paste behavior. Imported cloud flags never enable sync.

## Moving to Flycut 2.0

Quit all Flycut versions before moving preferences. If you used the sandboxed original Flycut, import its preferences file into Flycut 2.0:

```sh
defaults import com.edynamics.flycut "$HOME/Library/Containers/com.generalarcade.flycut/Data/Library/Preferences/com.generalarcade.flycut.plist"
defaults delete com.edynamics.flycut syncSettingsViaICloud 2>/dev/null || true
defaults delete com.edynamics.flycut syncClippingsViaICloud 2>/dev/null || true
```

If macOS denies your terminal access to the original app's container, copy that `.plist` in Finder to a private local folder and import the copy. If you used an earlier build of this fork with the `com.kabadabra.flycut` identity, import its preferences file instead:

```sh
defaults import com.edynamics.flycut "$HOME/Library/Preferences/com.kabadabra.flycut.plist"
defaults delete com.edynamics.flycut syncSettingsViaICloud 2>/dev/null || true
defaults delete com.edynamics.flycut syncClippingsViaICloud 2>/dev/null || true
```

Choose the source with the history you want to keep; a second import replaces the first. Importing the `.plist` directly preserves the saved clipping store, which `defaults export` may omit. Each source domain remains untouched. Launch Flycut 2.0 afterward and grant its own clipboard and Accessibility permissions, because macOS treats the new identity as a separate app.

## Development tools

QMD and Graphify are optional local navigation tools. See [developer notes](docs/DEVELOPING.md). Generated indexes and graphs are not release assets. Legacy Objective-C and dormant iOS sources remain for history and review, outside the active Swift package.

## Credits and license

Original Flycut by General Arcade, Gennadiy Potapov, and contributors. Jumpcut by Steve Cook and contributors. This fork keeps the **Flycut** name and the original MIT license. See [acknowledgements](acknowledgements.txt) for included libraries and their authors. To support the original maintainers, see [their project](https://github.com/TermiT/Flycut).

Flycut 2.0 includes work from recent upstream contributors. Thank you to [Emanuel Stadler (@emanuelst)](https://github.com/emanuelst) for the [macOS 27 menu bar fix](https://github.com/TermiT/Flycut/pull/328) and [bezel improvements](https://github.com/TermiT/Flycut/pull/327) adapted in [our PR #3](https://github.com/kabadabra/Flycut/pull/3); [Ilya Bersenev (@voidless)](https://github.com/voidless) for the [keyboard layout paste fix](https://github.com/TermiT/Flycut/pull/314); [Tyler Martin (@tymrtn)](https://github.com/tymrtn) for the [CloudKit startup fix](https://github.com/TermiT/Flycut/pull/322); and [@agentheath](https://github.com/agentheath) for the [macOS 26 menu bar crash fix](https://github.com/TermiT/Flycut/pull/323).
