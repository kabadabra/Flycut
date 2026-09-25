# Flycut 2.0

Flycut 2.0 is a free, open source clipboard manager for macOS, maintained by Emerging Dynamics. This repository is a [fork of the original Flycut project](https://github.com/TermiT/Flycut), created for ongoing macOS compatibility work. Flycut itself is based on [Jumpcut](http://jumpcut.sourceforge.net/). The original authors and contributors retain credit in [the MIT license](license.txt) and [acknowledgements](acknowledgements.txt).

Download the [latest signed and notarized Flycut 2.0 DMG](https://github.com/kabadabra/Flycut/releases/latest).

Copy text as usual. Flycut keeps a history of clippings, which you can open with **Shift-Command-V** or from its menu bar icon. The original iOS source remains in this repository, but the current fork focuses on macOS.

## macOS support

The macOS app builds with Xcode 27 and targets macOS 12 or newer. The macOS 27 menu bar click fix from upstream is included. The fork has its own bundle ID, `com.edynamics.flycut`, so it can coexist with the original app. Its display name is Flycut 2.0, while the executable and repository remain Flycut. Clipboard history and settings use the new ID; see [migration](#moving-to-flycut-20).

Apple may ask whether Flycut can read the clipboard. Choose **Always Allow** for automatic history capture. Pasting a selected clipping also needs **Accessibility** access in System Settings > Privacy & Security > Accessibility. See the [Mac help](help.md) for troubleshooting.

## Build locally

Open `Flycut.xcodeproj` in Xcode 27 and select the **Flycut** macOS scheme, or run:

```sh
xcodebuild -project Flycut.xcodeproj -scheme Flycut -configuration Debug \
  -destination 'platform=macOS' -derivedDataPath build/DerivedData build
```

The local build is ad hoc signed for development. A downloadable DMG should be signed and notarized with your own Apple Developer credentials; see [release setup](RELEASE_SETUP.md). iCloud sync is not provisioned for this fork, so use local history persistence. The original Flycut App Store listing is maintained by the original project, not this fork.

Run the local build with `open build/DerivedData/Build/Products/Debug/Flycut.app`. Install a tagged, notarized DMG for regular use when release credentials are configured.

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

QMD indexes this project's Markdown as the `flycut` collection. Graphify generates a local code graph. Both tools are optional for building Flycut; [developer notes](docs/DEVELOPING.md) show setup and refresh commands. The graph and search index are local artifacts, not part of the release.

## Credits and license

Original Flycut by General Arcade, Gennadiy Potapov, and contributors. Jumpcut by Steve Cook and contributors. This fork keeps the **Flycut** name and the original MIT license. See [acknowledgements](acknowledgements.txt) for included libraries and their authors. To support the original maintainers, see [their project](https://github.com/TermiT/Flycut).
