#!/bin/zsh
set -euo pipefail

cd "$(dirname "$0")/.."

./scripts/build-app.sh

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
cp -R "dist/AULA Control.app" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

rm -f "dist/AULA Control.dmg"
hdiutil create \
  -volname "AULA Control" \
  -srcfolder "$STAGE" \
  -ov -format UDZO \
  "dist/AULA Control.dmg" >/dev/null

echo "→ dist/AULA Control.dmg"
du -sh "dist/AULA Control.dmg"
