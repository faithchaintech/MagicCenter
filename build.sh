#!/bin/zsh
set -eu
cd "$(dirname "$0")"
app="build/MagicCenter.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
xcrun clang -fobjc-arc -O2 -Wall -Wextra -Wno-unused-parameter -mmacosx-version-min=13.0 main.m -framework Cocoa -framework ApplicationServices -framework IOKit -framework ServiceManagement -o "$app/Contents/MacOS/MagicCenter"
cp Info.plist "$app/Contents/Info.plist"
cp AppIcon.icns "$app/Contents/Resources/AppIcon.icns"
codesign --force --sign - "$app"
echo "Built $app"
