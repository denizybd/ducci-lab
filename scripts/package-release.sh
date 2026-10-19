#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
APP="$PWD/dist/Ducci Lab.app"
VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")
ARCH=$(lipo -archs "$APP/Contents/MacOS/DucciLab")
if [[ "$ARCH" != "arm64" ]]; then
  print -u2 "The prebuilt release package requires an arm64 binary; found $ARCH."
  exit 1
fi
codesign --verify --deep --strict "$APP"
RELEASE_DIR="$PWD/dist/release-$VERSION"
mkdir -p "$RELEASE_DIR"
ARCHIVE="$RELEASE_DIR/Ducci-Lab-$VERSION-macOS-AppleSilicon.zip"
STAGING=$(mktemp -d "$PWD/dist/.release-XXXXXXXX")
trap 'rm -rf "$STAGING"' EXIT
(cd dist && /usr/bin/zip -q -r -y "$STAGING/app.zip" "Ducci Lab.app")
mv "$STAGING/app.zip" "$ARCHIVE"
(cd "$RELEASE_DIR" && shasum -a 256 "${ARCHIVE:t}" > SHA256SUMS.txt)
print "$ARCHIVE"
