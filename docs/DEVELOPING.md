# Developing Flycut

## Active Swift build

Use Xcode 27.0 with Swift 6.4; the package uses Swift 6 language mode and targets macOS 13. Open `Package.swift` directly in Xcode. `FlycutCore` owns history, settings and migration; `FlycutPlatform` adapts macOS services; `FlycutMac` contains the AppKit/SwiftUI shell.

```sh
swift test
scripts/build-app.sh debug
scripts/build-app.sh release
scripts/verify-app.sh build/Export/Flycut.app
```

Debug produces `build/Preview/Flycut Preview.app`, using a separate preview identity. Release produces `build/Export/Flycut.app` with the production identity. Neither script launches or installs the app. `VERSION=X.Y.Z` overrides both bundle version fields; otherwise they use `App/AppInfo.plist`. Local builds are ad hoc signed. CI runs tests and both builds on Xcode 27, plus bundle verification.

Legacy Objective-C, bundled libraries and iOS sources remain historical source outside Package.swift. A separate `legacy-2` CI job continues to check the old Xcode project until Swift QA passes; remove that job only after migration, UI and installation review. Release automation already packages the Swift app.

## Manual release gates

Exercise migration with synthetic plists and a disposable 2.0 profile, then menu click, search focus, hotkey navigation, copy/paste into another app, favorites, light/dark appearance, full-screen Spaces, VoiceOver, clipboard/Accessibility prompts and Login Items approval on macOS 27. Test a downloaded signed DMG and its contained app. Record results before publication. Do not replace a daily-use installation for automated tests. See [release setup](../RELEASE_SETUP.md).

## QMD

Install QMD, then from the repository root:

```sh
qmd collection add "$PWD" --name flycut --mask '**/*.md'
qmd context add qmd://flycut/ 'Flycut macOS clipboard manager fork: build, compatibility, release, developer documentation.'
qmd update
qmd embed
qmd search 'pasteboard' -c flycut
```

If the `flycut` collection already exists, skip the `collection add` step. The repo includes QMD's optional agent skill under `.agents/skills/qmd`.

## Graphify

Install Graphify, then from the repository root:

```sh
graphify update . --no-cluster
graphify query 'clipboard capture' --graph graphify-out/graph.json
graphify hook install
```

`graphify-out/` is ignored by Git. The hook only affects your local checkout. `AGENTS.md` describes how to consult and refresh the graph during code work. Graphify's Codex hook configuration is local because it includes an install-specific executable path.

## Updating from upstream

The local `origin` remote is `kabadabra/Flycut`; `upstream` is `TermiT/Flycut`. Bring in upstream fixes through a review branch so fork-specific identity and release settings remain visible in the diff:

```sh
git fetch upstream
git switch master
git pull --ff-only origin master
git switch -c update/upstream-YYYYMMDD
git merge upstream/master
```

Resolve any conflicts, run the macOS build and local smoke check, then open a pull request into the fork's `master`. GitHub also displays the upstream relationship and offers a **Sync fork** control, but review the resulting changes before relying on a new build.
