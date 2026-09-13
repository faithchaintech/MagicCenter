#!/bin/zsh
set -eu
cd "$(dirname "$0")"
./build.sh
if [[ ! -x .venv/bin/dmgbuild ]]; then
    python3 -m venv .venv
    .venv/bin/python -m pip install -r requirements-dmg.txt
fi
mkdir -p dist
app_version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Info.plist)
image_path="dist/MagicCenter-${app_version}.dmg"
.venv/bin/dmgbuild -s DMGSettings.py -D "source=$PWD" MagicCenter "$image_path"
hdiutil verify "$image_path"
echo "Installer ready: $PWD/$image_path"
