#!/bin/zsh
set -euo pipefail

cd "$(dirname "$0")/.."

swift build --product aula >/dev/null
AULA=".build/debug/aula"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

"$AULA" light static --color FF3020 --brightness 4 --speed 2 --dry-run > "$tmp/light.txt"
grep -q "01 FF 30 20" "$tmp/light.txt"
grep -q "04 F0" "$tmp/light.txt"

"$AULA" perkey --all 101418 --key esc=FF3020 --dry-run > "$tmp/perkey.txt"
grep -q "04 23" "$tmp/perkey.txt"

"$AULA" remap --preset mac --dry-run > "$tmp/remap.txt"
grep -q "04 11" "$tmp/remap.txt"

"$AULA" options --sleep 5 --response 3 --lock-win --dry-run > "$tmp/options.txt"
grep -q "04 17" "$tmp/options.txt"

"$AULA" macro --text "Hi" --dry-run > "$tmp/macro.txt"
grep -q "04 19" "$tmp/macro.txt"
grep -q "04 15" "$tmp/macro.txt"

"$AULA" clock --dry-run > "$tmp/clock.txt"
grep -q "04 28" "$tmp/clock.txt"

"$AULA" verify --dry-run > "$tmp/verify.txt"
grep -q "04 18" "$tmp/verify.txt"

"$AULA" status > "$tmp/status.txt"
grep -q "Connection" "$tmp/status.txt"

echo "CLI smoke tests passed."
