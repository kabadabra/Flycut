# Changelog

## 2.0.0 (unreleased)

Fork of [TermiT/Flycut](https://github.com/TermiT/Flycut) for ongoing macOS compatibility. Original Flycut by General Arcade, Gennadiy Potapov, and contributors; based on Jumpcut by Steve Cook.

- Build with Xcode 27 using a macOS 12 minimum deployment target.
- Use ad hoc signing for local Debug builds so the embedded framework loads correctly.
- Keep the macOS 27 menu bar click fix from upstream.
- Preserve the existing clipboard at launch and discard stale background reads.
- Use modern macOS Login Items registration on macOS 13 and later.
- Use a separate fork app identity, `com.kabadabra.flycut`, and document migration from the original app.
- Add QMD and Graphify developer setup and require signing plus notarization for public DMGs.
- Name this fork Flycut 2.0 while retaining credit for the original project.
- Cache bezel backgrounds and release temporary Core Graphics colors (adapted from [upstream PR #327](https://github.com/TermiT/Flycut/pull/327) by Emanuel Stadler).

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
