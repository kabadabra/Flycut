# Developing Flycut

## Local checks

Run the macOS build in the README. A Release archive uses:

```sh
xcodebuild -project Flycut.xcodeproj -scheme Flycut -configuration Release \
  -archivePath build/Flycut.xcarchive CODE_SIGNING_ALLOWED=NO archive
```

Check the resulting app ID with `/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' build/Flycut.xcarchive/Products/Applications/Flycut.app/Contents/Info.plist`.

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

## Modernization roadmap

Keep the AppKit UI and data format stable through the macOS 27 release. After that, isolate and test clipboard capture, hotkeys, and login registration one at a time. Swift can replace each module behind a small Objective-C interface; a whole-app rewrite should wait until equivalent behavior and saved-history migration have automated coverage.

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
