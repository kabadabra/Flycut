# Flycut 2.0 — legacy fork

> **This repository is no longer maintained.** Flycut 2.0 was a temporary update to keep the original Flycut usable on macOS 27. We have since rebuilt Flycut in Swift and moved active development to **[Flycut Evolution](https://github.com/kabadabra/Flycut-Evolution)**.

**For the current app:** [Download Flycut Evolution](https://github.com/kabadabra/Flycut-Evolution/releases/latest) · [Read its features and requirements](https://github.com/kabadabra/Flycut-Evolution#readme) · [Report an issue](https://github.com/kabadabra/Flycut-Evolution/issues)

Flycut Evolution 1.0.0 is the maintained version. It has a new Swift codebase, a redesigned clipping list, one-click paste, optional iCloud sync between Macs, rich-text previews, and a reviewed importer for older Flycut history. It requires macOS 14 or later on Apple Silicon or Intel.

## Flycut 2.0

[Flycut 2.0.0](https://github.com/kabadabra/Flycut/releases/tag/v2.0.0) remains available as a historical download for people who need it, including Macs on macOS 12 or 13. It is not receiving new features or fixes. Version 2.0 brought in the upstream macOS 27 menu bar fix and modernized Open at Login while we worked on the Swift rewrite.

If you move from Flycut 2.0 to Evolution, quit the old app first and follow the [Evolution upgrade guide](https://github.com/kabadabra/Flycut-Evolution#moving-to-flycut-evolution). Check that your history and settings imported before removing Flycut 2.0. The apps share a bundle identity, so they should not run together.

This repository also contains an unreleased Swift prototype from the transition. It is historical work; the supported Swift app, documentation, and releases are in the Flycut Evolution repository.

## Origin and thanks

This is a fork of [TermiT/Flycut](https://github.com/TermiT/Flycut), which is based on [Jumpcut](http://jumpcut.sourceforge.net/). The Flycut name and [MIT license](license.txt) are retained. See the [original acknowledgements](acknowledgements.txt).

Thanks to the upstream contributors whose work helped Flycut 2.0: [Emanuel Stadler](https://github.com/emanuelst) for the [macOS 27 menu bar fix](https://github.com/TermiT/Flycut/pull/328) and [bezel improvements](https://github.com/TermiT/Flycut/pull/327), [Ilya Bersenev](https://github.com/voidless) for the [keyboard layout paste fix](https://github.com/TermiT/Flycut/pull/314), [Tyler Martin](https://github.com/tymrtn) for the [CloudKit startup fix](https://github.com/TermiT/Flycut/pull/322), and [@agentheath](https://github.com/agentheath) for the [macOS 26 menu bar crash fix](https://github.com/TermiT/Flycut/pull/323).
