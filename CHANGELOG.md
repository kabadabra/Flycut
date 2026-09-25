# Changelog

## 2.0.0 (2026-09-24)

Flycut 2.0 is the first Emerging Dynamics release of Flycut, the free, open-source clipboard manager for macOS.

### Highlights

- Restored reliable menu bar interaction on macOS 27 with a fix from the original Flycut project.
- Updated **Open at Login** to use modern macOS Login Items on macOS 13 and later.
- Documented how to move clipping history and settings from the original Flycut or earlier builds of this fork. Flycut 2.0 has its own app identity, so it can coexist with the original.

### Reliability and polish

- Made clipboard capture more dependable: Flycut preserves the clipboard when it starts and ignores stale background reads.
- Improved clipping panel drawing by caching bezel backgrounds and releasing temporary graphics colors.

### For developers

- Build with Xcode 27 while supporting macOS 12 and later.
- Use ad hoc signing for local Debug builds and Developer ID signing plus notarization for public DMGs.
- Added QMD and Graphify setup for navigating the documentation and codebase.
- The app and helper use `com.edynamics.flycut` and `com.edynamics.flycut.helper`.

### Credits

Flycut 2.0 is a fork of [TermiT/Flycut](https://github.com/TermiT/Flycut). Original Flycut was created by General Arcade, Gennadiy Potapov, and contributors, and is based on Jumpcut by Steve Cook. The clipping panel improvement adapts [upstream PR #327](https://github.com/TermiT/Flycut/pull/327) by Emanuel Stadler.

## 1.9.7 (2026-08-04)

First release since 1.9.6 (2020). Focused on crash fixes and modern-macOS
compatibility.

- Fixed a crash on macOS 26 when copying large content from Microsoft Remote
  Desktop Connection (the menu-bar icon update ran off the main thread). (#262, #279)
- Fixed an intermittent crash when a copy was quickly followed by a paste — the
  clipboard store was being modified from a background thread while the UI read
  it. Clipboard capture is now serialized on the main thread.
- Fixed pasting on non-QWERTY keyboard layouts (Russian, Dvorak, and others),
  where the synthesized ⌘V could fail or trigger the wrong action. (#264)
- Fixed a guaranteed crash when lowering the "Save" preference below "After each
  clip" while iCloud Clippings Sync was enabled.
- Fixed the menu search field returning wrong or stale results. (#290)
- Fixed a crash when enabling iCloud sync in unsigned/local builds that lack
  iCloud entitlements; sync now degrades gracefully instead. (#321)
- The project again builds cleanly on current Xcode.

Credits: menu-search fix by @chzhc; several fixes adapted from the
actively-maintained community fork (haad/Flycut) and from contributor pull
requests (#314, #322, #323).
