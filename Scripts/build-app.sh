#!/bin/bash
#
# Builds the Swift package and assembles a ready-to-run .app bundle in build/.
#
# Usage:
#   Scripts/build-app.sh            # release build
#   Scripts/build-app.sh debug      # debug build
#   REBUILD_ICON=1 Scripts/build-app.sh
#   ARCHS=arm64 Scripts/build-app.sh   # thin binary (default: arm64 + x86_64)
#
set -euo pipefail

CONFIGURATION="${1:-release}"
ARCHS="${ARCHS:-arm64 x86_64}"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

BUNDLE_NAME="DEVONthink 窗口列表"
APP_PATH="$ROOT/build/$BUNDLE_NAME.app"
EXECUTABLE_NAME="DEVONthinkWindowsList"
BUNDLE_ID="com.jkhnfk.DEVONthinkWindowsList"
ICON_PATH="$ROOT/Resources/AppIcon.icns"

echo "==> Building ($CONFIGURATION: $ARCHS)"
BINARIES=()
for ARCH in $ARCHS; do
    echo "    - $ARCH"
    swift build -c "$CONFIGURATION" --arch "$ARCH" --scratch-path "$ROOT/.build/$ARCH"
    ARCH_BIN_PATH="$(swift build -c "$CONFIGURATION" --arch "$ARCH" --scratch-path "$ROOT/.build/$ARCH" --show-bin-path)"
    BINARIES+=("$ARCH_BIN_PATH/$EXECUTABLE_NAME")
done

echo "==> Assembling $APP_PATH"
rm -rf "$APP_PATH"
mkdir -p "$APP_PATH/Contents/MacOS" "$APP_PATH/Contents/Resources"
if [ "${#BINARIES[@]}" -eq 1 ]; then
    cp "${BINARIES[0]}" "$APP_PATH/Contents/MacOS/$EXECUTABLE_NAME"
else
    lipo -create "${BINARIES[@]}" -output "$APP_PATH/Contents/MacOS/$EXECUTABLE_NAME"
fi
cp "$ROOT/Resources/Info.plist" "$APP_PATH/Contents/Info.plist"

if [ ! -f "$ICON_PATH" ] || [ "${REBUILD_ICON:-0}" = "1" ]; then
    echo "==> Generating app icon"
    ICONSET_DIR="$(mktemp -d)/AppIcon.iconset"
    swift "$ROOT/Scripts/make-icon.swift" "$ICONSET_DIR" >/dev/null
    iconutil -c icns "$ICONSET_DIR" -o "$ICON_PATH"
fi
cp "$ICON_PATH" "$APP_PATH/Contents/Resources/AppIcon.icns"

printf 'APPL????' > "$APP_PATH/Contents/PkgInfo"

echo "==> Signing (ad-hoc)"
codesign --force --sign - --identifier "$BUNDLE_ID" "$APP_PATH"

echo
echo "==> Done"
lipo -info "$APP_PATH/Contents/MacOS/$EXECUTABLE_NAME"
echo "    open \"$APP_PATH\""
