#!/bin/zsh
set -euo pipefail

cd "$(dirname "$0")/.."

./scripts/build-app.sh

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
cp -R "dist/AULA Control.app" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "dist/AULA Control.app/Contents/Info.plist")"
DMG="dist/AULA-Control-${VERSION}.dmg"

rm -f "$DMG"
hdiutil create \
  -volname "AULA Control" \
  -srcfolder "$STAGE" \
  -ov -format UDZO \
  "$DMG" >/dev/null

echo "→ $DMG"
du -sh "$DMG"
shasum -a 256 "$DMG"
