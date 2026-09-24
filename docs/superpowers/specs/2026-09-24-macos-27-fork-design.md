# Flycut macOS 27 fork design

## Goal

Keep Flycut's familiar menu bar, Shift-Command-V, and text clipping workflow working on macOS 27, then make this a clearly credited, maintainable public fork. Preserve the original MIT license and project name. The macOS app is the priority; iOS behavior is outside this compatibility pass.

## Findings

- Upstream already merged a macOS 27 menu reopening fix (`8a24014`).
- Xcode 27 rejects the macOS 10.13 deployment target in Flycut, its helper, and its embedded CloudKit framework. Its supported minimum is 12.0.
- Launch calls `declareTypes:` on the general pasteboard, which clears the user's existing clipboard before polling starts.
- Capture reads clipboard content asynchronously after recording the change count. An older read can finish after a newer copy and be attributed to the wrong change.
- Login at startup uses older APIs. macOS 13 and later provide `SMAppService` with readable status and explicit registration errors.
- Current release instructions and signing settings contain upstream identity and team values. A fork needs its own app identity and signing credentials.
- Apple documents that programmatic general pasteboard reads can require user approval; a clipboard manager must explain that permission honestly.

## Approach

Keep the Objective-C/AppKit UI for this release. Adjust the macOS deployment target to 12.0, fix capture at its source, adopt `SMAppService.mainAppService` on macOS 13+, and retain the older login path for macOS 12. Use a distinct fork bundle identifier, `com.edynamics.flycut`, so the fork can coexist with upstream. The earlier preview used `com.kabadabra.flycut`. Ship direct downloads first; do not promise working CloudKit sync or Mac App Store distribution under upstream's entitlements. Document an opt-in local preferences migration for existing users.

Set up QMD to index project Markdown and Graphify to map the code. Keep generated indexes and graph output out of Git; commit only reproducible setup instructions. Preserve upstream as a fetchable remote and give original authors credit in the README, license, and release notes.

## Verification

Build a macOS Debug app and Release archive with Xcode 27. Exercise launch, copy capture, clip selection/paste, menu search, and login status on macOS 27 where UI permission allows. Verify the bundle ID and signing output. Do not claim notarization or public binary installation until a personal Developer ID certificate and notary credentials are available.

## Swift decision

Do not rewrite the application in this pass. The existing AppKit flow and storage format are the compatibility contract. Future Swift work should replace bounded modules such as login management or capture after tests pin their behavior; a whole-app rewrite adds regression risk without solving the identified build and API faults.
