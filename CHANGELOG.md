# Changelog

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
