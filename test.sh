#!/bin/zsh
set -eu
cd "$(dirname "$0")"
./build.sh
xcrun clang -Wall -Wextra tests.c -o build/gesture-tests
build/gesture-tests
build/MagicCenter.app/Contents/MacOS/MagicCenter --integration-test
codesign --verify --deep --strict build/MagicCenter.app
plutil -lint build/MagicCenter.app/Contents/Info.plist
