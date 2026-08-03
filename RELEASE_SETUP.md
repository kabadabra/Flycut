# Cutting a Flycut release

Releases are produced by `.github/workflows/release.yml`, which runs when a
`v*` tag is pushed. It builds the macOS app, packages it in a DMG, optionally
signs + notarizes it, and publishes a GitHub Release with the DMG attached.

## One-time setup: GitHub secrets

Add these under **Settings → Secrets and variables → Actions**. The workflow
adapts to whichever are present, so you can start with none (test build) and
add them as you go.

| Secret | Purpose |
| --- | --- |
| `CERTIFICATES_P12` | base64 of your **Developer ID Application** certificate exported as `.p12` |
| `CERTIFICATES_PASSWORD` | the password you set when exporting the `.p12` |
| `NOTARY_APPLE_ID` | Apple ID email used for notarization |
| `NOTARY_APP_PASSWORD` | an [app-specific password](https://support.apple.com/en-us/102654) for that Apple ID |
| `NOTARY_TEAM_ID` | your Apple Developer Team ID (`S8JLSG5ES7`) |

Export the `.p12` and base64-encode it:

```
# In Keychain Access: export your "Developer ID Application" identity as Certificates.p12
base64 -i Certificates.p12 | pbcopy   # paste into the CERTIFICATES_P12 secret
```

Behaviour by secrets configured:

- **none** → ad-hoc signed app in the DMG. Gatekeeper will warn; use only for testing.
- **signing only** → Developer ID signed with hardened runtime (still warned until notarized).
- **signing + notary** → signed, notarized, and stapled — installs cleanly with no warning.

## Cutting a release

```
# 1. Make sure master is green and the version is bumped (MARKETING_VERSION).
# 2. Tag and push:
git tag v1.9.7
git push origin v1.9.7
```

The workflow stamps `MARKETING_VERSION` from the tag, builds, packages, (signs +
notarizes if secrets are set), and creates the GitHub Release. Release notes are
taken from the matching `## 1.9.7` section of `CHANGELOG.md`, falling back to the
commit log if that section is absent.

## IMPORTANT: distribution channel decides entitlements

This project's committed entitlements (`Flycut.entitlements`) target the **Mac App
Store**: App Sandbox on, an iCloud (CloudKit) container, and `aps-environment`.
Those are correct for a MAS submission but are **not** what a Developer-ID,
direct-download DMG wants:

- **Mac App Store update** — don't use this workflow. Archive in Xcode and upload
  to App Store Connect (Organizer → Distribute App). Keep the entitlements as-is.
- **Developer ID direct-download DMG (this workflow)** — for a clean notarized
  build you'll typically want to drop the sandbox + MAS-only iCloud/`aps`
  entitlements (the way the community fork does). Thanks to the CloudKit guard
  merged in 1.9.7, the app already **runs safely without the iCloud entitlement**
  (sync just no-ops), so an un-entitled Developer ID build won't crash — but iCloud
  sync will be unavailable unless you register a Developer-ID iCloud container.

  To do this without disturbing the MAS build, add a separate entitlements file
  (e.g. `FlycutDeveloperID.entitlements`) and pass
  `CODE_SIGN_ENTITLEMENTS=FlycutDeveloperID.entitlements` in the archive step.

**Decide the channel before the first real release** — it's the one thing this
workflow can't decide for you.
