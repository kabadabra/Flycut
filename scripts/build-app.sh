#!/bin/bash
set -euo pipefail

if [[ $# -ne 1 || ( $1 != debug && $1 != release ) ]]; then
    echo "Usage: $0 debug|release" >&2
    exit 2
fi

mode=$1
root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root"

if [[ $mode == debug ]]; then
    configuration=debug
    app_name='Flycut Preview'
    bundle_id='com.edynamics.flycut.preview'
    destination="$root/build/Preview/$app_name.app"
else
    configuration=release
    app_name='Flycut'
    bundle_id='com.edynamics.flycut'
    destination="$root/build/Export/$app_name.app"
fi

version=${VERSION:-$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' App/AppInfo.plist)}
if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Version must have the form X.Y.Z" >&2
    exit 2
fi

swift build -c "$configuration" --product FlycutMac
binary_dir=$(swift build -c "$configuration" --show-bin-path)

mkdir -p "$(dirname "$destination")"
staging=$(mktemp -d "$root/build/.flycut-app.XXXXXX")
trap 'rm -rf "$staging"' EXIT
app="$staging/$app_name.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
install -m 755 "$binary_dir/FlycutMac" "$app/Contents/MacOS/FlycutMac"
install -m 644 "$root/App/AppInfo.plist" "$app/Contents/Info.plist"
install -m 644 "$root/flycut.icns" "$app/Contents/Resources/flycut.icns"

plist=/usr/libexec/PlistBuddy
"$plist" -c "Set :CFBundleShortVersionString $version" "$app/Contents/Info.plist"
"$plist" -c "Set :CFBundleVersion $version" "$app/Contents/Info.plist"
"$plist" -c "Set :CFBundleIdentifier $bundle_id" "$app/Contents/Info.plist"
"$plist" -c "Set :CFBundleName $app_name" "$app/Contents/Info.plist"
"$plist" -c "Set :CFBundleDisplayName $app_name" "$app/Contents/Info.plist"

codesign --force --sign - --timestamp=none "$app"
codesign --verify --strict --verbose=2 "$app"
rm -rf "$destination"
mv "$app" "$destination"
echo "$destination"
