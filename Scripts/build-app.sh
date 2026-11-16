#!/bin/zsh
set -euo pipefail
PROJECT_ROOT="${0:A:h:h}"
cd "$PROJECT_ROOT"
CONFIGURATION="${1:-release}"
if [[ "$CONFIGURATION" != "release" && "$CONFIGURATION" != "debug" ]]; then
    print -u2 "Uso: ./Scripts/build-app.sh [release|debug]"
    exit 2
fi
BUILD_PRIVACY_FLAGS=()
if [[ "$CONFIGURATION" == "release" ]]; then
    BUILD_PRIVACY_FLAGS=(
        -Xswiftc -debug-prefix-map -Xswiftc "$PROJECT_ROOT=/TapeteDesktop"
        -Xswiftc -file-prefix-map -Xswiftc "$PROJECT_ROOT=/TapeteDesktop"
        -Xswiftc -debug-prefix-map -Xswiftc "$HOME=/build"
        -Xswiftc -file-prefix-map -Xswiftc "$HOME=/build"
    )
fi
swift build -c "$CONFIGURATION" "${BUILD_PRIVACY_FLAGS[@]}"
BINARY_DIR="$(swift build -c "$CONFIGURATION" --show-bin-path)"
APP="$PROJECT_ROOT/build/TapeteDesktop.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BINARY_DIR/TapeteDesktop" "$APP/Contents/MacOS/TapeteDesktop"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Sources/TapeteDesktop/Resources/PersianRug.png "$APP/Contents/Resources/PersianRug.png"
swiftc -parse-as-library Sources/TapeteDesktop/RugArtwork.swift Sources/TapeteDesktop/RugTexture.swift Tools/MakeIcon.swift -o .build/MakeIcon
.build/MakeIcon .build/AppIcon.iconset
iconutil -c icns .build/AppIcon.iconset -o "$APP/Contents/Resources/AppIcon.icns"
if [[ "$CONFIGURATION" == "release" ]]; then
    /usr/bin/strip -S -x "$APP/Contents/MacOS/TapeteDesktop"
fi
codesign --force --sign - "$APP"
codesign --verify --strict "$APP"
print "Aplicativo criado: $APP"
