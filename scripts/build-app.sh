#!/bin/zsh
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="AULA Control"
BUNDLE="dist/${APP_NAME}.app"
BUILD_CONFIG="${CONFIG:-release}"
VERSION="${VERSION:-1.0.0}"

# Universal (Apple silicon + Intel) by default; ARCH=native builds only for this Mac, which is faster.
ARCH_FLAGS=(--arch arm64 --arch x86_64)
[[ "${ARCH:-universal}" == "native" ]] && ARCH_FLAGS=()

echo "→ Building ${BUILD_CONFIG} binaries (${ARCH:-universal})"
swift build -c "$BUILD_CONFIG" "${ARCH_FLAGS[@]}"
BIN_DIR="$(swift build -c "$BUILD_CONFIG" "${ARCH_FLAGS[@]}" --show-bin-path)"

echo "→ Rendering icon"
mkdir -p build/AppIcon.iconset
swift scripts/make-icon.swift "build/AppIcon-1024.png" >/dev/null
for size in 16 32 64 128 256 512 1024; do
  sips -z "$size" "$size" "build/AppIcon-1024.png" --out "build/AppIcon.iconset/icon_${size}x${size}.png" >/dev/null
done
cp "build/AppIcon.iconset/icon_32x32.png" "build/AppIcon.iconset/icon_16x16@2x.png"
cp "build/AppIcon.iconset/icon_64x64.png" "build/AppIcon.iconset/icon_32x32@2x.png"
cp "build/AppIcon.iconset/icon_256x256.png" "build/AppIcon.iconset/icon_128x128@2x.png"
cp "build/AppIcon.iconset/icon_512x512.png" "build/AppIcon.iconset/icon_256x256@2x.png"
cp "build/AppIcon.iconset/icon_1024x1024.png" "build/AppIcon.iconset/icon_512x512@2x.png"
iconutil -c icns "build/AppIcon.iconset" -o "build/AppIcon.icns"

echo "→ Assembling bundle"
rm -rf "$BUNDLE"
mkdir -p "$BUNDLE/Contents/MacOS" "$BUNDLE/Contents/Resources/bin"
cp "$BIN_DIR/AulaControl" "$BUNDLE/Contents/MacOS/AULA Control"
cp "$BIN_DIR/aula" "$BUNDLE/Contents/Resources/bin/aula"
cp "build/AppIcon.icns" "$BUNDLE/Contents/Resources/AppIcon.icns"

cat > "$BUNDLE/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>AULA Control</string>
    <key>CFBundleIdentifier</key>
    <string>com.aulacontrol.app</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>AULA Control</string>
    <key>CFBundleDisplayName</key>
    <string>AULA Control</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <false/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSInputMonitoringUsageDescription</key>
    <string>AULA Control reads HID reports to identify your F108 Pro and configure it. Key events are only read when you enable macOS remapping.</string>
    <key>NSBluetoothAlwaysUsageDescription</key>
    <string>AULA Control detects when your AULA keyboard is connected over Bluetooth so it can enable macOS-level remapping.</string>
    <key>NSHumanReadableCopyright</key>
    <string>Not affiliated with AULA. Built for the AULA F108 Pro.</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
</dict>
</plist>
PLIST

printf 'APPL????' > "$BUNDLE/Contents/PkgInfo"

echo "→ Signing (ad-hoc)"
codesign --force --sign - --options runtime "$BUNDLE/Contents/Resources/bin/aula" >/dev/null
codesign --force --sign - --options runtime "$BUNDLE" >/dev/null
codesign --verify --deep --strict --verbose=2 "$BUNDLE"

echo "→ Done: $BUNDLE"
du -sh "$BUNDLE"
