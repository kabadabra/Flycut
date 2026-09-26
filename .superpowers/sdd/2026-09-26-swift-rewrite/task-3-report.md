# Task 3 report — typed settings and legacy mapping

Code commit: `590a58d3f64c5cbad2045fce6f7ae157b3503fc0`

## Delivered

- Added `FlycutSettings` with typed save mode, hotkey, privacy controls, limits, appearance, export URLs, and validated defaults.
- Added `SettingsStore` that writes only `v3.*` preferences and removes a previously saved export URL when cleared.
- Added `LegacySettingsMapper.map(_:)` with top-level preference precedence, nested `store` fallback, and warnings for unsupported values. Legacy iCloud flags remain off even when true in the source.

## Red/green and verification

- Initial `swift test --filter SettingsTests`: compile failed because the settings interfaces were absent.
- `swift test --filter SettingsTests`: 9 tests, 0 failures after initial implementation.
- New URL persistence test failed because a saved optional URL did not load. After the fix, 10 focused tests passed.
- New export URL validation test failed because an overlong file URL was accepted. After the fix, `swift test --filter SettingsTests`: 11 tests, 0 failures.
- Final `swift test`: 29 tests, 0 failures.
- `scripts/build-app.sh debug`: exit 0; preview app bundle built and its ad hoc signature verified.
- `graphify update . --no-cluster`: exit 0; graph refreshed to 1740 nodes and 2133 edges.
- `git diff --cached --check`: exit 0 before code commit.

## Decisions and limits

- Invalid positive counts fall back to legacy defaults; alpha and palette dimensions clamp to bounded ranges with warnings. The direct-download build's `saveForgottenFavorites` default is true.
- Export locations accept local file URLs up to 4096 UTF-8 bytes. Malformed or remote values are ignored with warnings.
- `savePreference=0` maps to `.never` and remains `.never` when persisted. No migration source preferences are changed.
- Task 4 migration integration has not been implemented here.
