#!/bin/bash
# Local bundles may be ad hoc signed. Release checks opt into Developer ID/notary.
set -euo pipefail
[[ $# == 1 ]] || { echo "Usage: $0 path/to/Flycut.app" >&2; exit 2; }
app=$1
plist="$app/Contents/Info.plist"
read_plist() { /usr/libexec/PlistBuddy -c "Print :$1" "$plist"; }
expect() { [[ $1 == "$2" ]] || { echo "Unexpected $3: $1 (expected $2)" >&2; exit 1; }; }
root=$(cd "$(dirname "$0")/.." && pwd)
expected_version=${VERSION:-$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$root/App/AppInfo.plist")}
expect "$(read_plist CFBundleIdentifier)" com.edynamics.flycut 'bundle ID'
expect "$(read_plist CFBundleShortVersionString)" "$expected_version" version
expect "$(read_plist CFBundleVersion)" "$expected_version" 'build version'
expect "$(read_plist CFBundleExecutable)" FlycutMac executable
expect "$(read_plist LSMinimumSystemVersion)" 13.0 'minimum macOS'
expect "$(read_plist CFBundleName)" Flycut 'app name'
[[ -x "$app/Contents/MacOS/FlycutMac" && -f "$app/Contents/Resources/flycut.icns" ]]
codesign --verify --deep --strict --verbose=2 "$app"
if [[ ${REQUIRE_DEVELOPER_ID:-0} == 1 || ${REQUIRE_NOTARIZATION:-0} == 1 ]]; then
    signature=$(codesign -d --verbose=4 "$app" 2>&1)
    expect "$(sed -n 's/^TeamIdentifier=//p' <<< "$signature")" M2L9SL9WCS 'signing team'
    grep -q '^Authority=Developer ID Application:' <<< "$signature"
    grep -q 'flags=.*runtime' <<< "$signature"
    grep -q '^Timestamp=' <<< "$signature"
fi
if [[ ${REQUIRE_NOTARIZATION:-0} == 1 ]]; then
    xcrun stapler validate "$app"
    spctl --assess --type execute --verbose=2 "$app"
fi
echo "Verified Flycut $expected_version: $app"
