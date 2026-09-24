# Releasing the Flycut fork

The public macOS channel is a Developer ID signed, notarized DMG built by [the release workflow](.github/workflows/release.yml). A tag named `vX.Y.Z` triggers publication. `workflow_dispatch` builds an artifact for testing without publishing a GitHub Release.

## One-time Apple setup

Use the Developer ID Application certificate for **Christopher Jacoby (team `M2L9SL9WCS`)**. The app and helper use `com.edynamics.flycut` and `com.edynamics.flycut.helper`. Export the certificate and private key as a password-protected `.p12`. In App Store Connect, create a Team API key that can submit notarization requests; download its `.p8` file and record its Key ID and Issuer ID. The original project's team ID, iCloud container, and App Store listing do not belong to this fork.

In the fork's GitHub repository, add these Actions secrets:

| Secret | Value |
| --- | --- |
| `CERTIFICATES_P12` | Base64-encoded Developer ID Application `.p12` |
| `CERTIFICATES_PASSWORD` | Password used to export the `.p12` |
| `NOTARY_KEY` | Base64-encoded App Store Connect `.p8` key |
| `NOTARY_KEY_ID` | API key's Key ID |
| `NOTARY_ISSUER_ID` | API key's Issuer ID |

For example, after setting `REPO` to your fork's `owner/Flycut` name:

```sh
REPO=kabadabra/Flycut
base64 -i Certificates.p12 | gh secret set CERTIFICATES_P12 -R "$REPO"
base64 -i AuthKey_XXXXXXXXXX.p8 | gh secret set NOTARY_KEY -R "$REPO"
gh secret set CERTIFICATES_PASSWORD -R "$REPO"
gh secret set NOTARY_KEY_ID -R "$REPO" --body 'XXXXXXXXXX'
gh secret set NOTARY_ISSUER_ID -R "$REPO" --body 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'
```

Do not commit credentials. Tag builds stop before publication if signing or notarization credentials are missing. A manual run without them still produces an ad hoc signed test DMG that Gatekeeper will warn about.

## Cut a release

1. Verify the macOS build, the `com.edynamics.flycut` bundle identifier, and Developer ID team `M2L9SL9WCS`.
2. Update `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in the macOS Flycut target. Add a matching `## X.Y.Z` section to `CHANGELOG.md`.
3. Push a `vX.Y.Z` tag from the reviewed commit. The workflow signs nested code, notarizes and staples the DMG, and publishes it on the fork.
4. Download the public DMG and verify it on a separate Mac before telling users to upgrade.

The app can read and save local history without iCloud. CloudKit sync is not configured for the fork, and the original Mac App Store channel is not controlled here. The app's new identifier means existing users can keep the upstream app installed and import their saved preferences into this fork as described in the README.
