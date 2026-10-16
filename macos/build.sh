#!/bin/bash
set -Eeuo pipefail
cd "$(dirname "$0")/.."
[[ $(uname -s) == Darwin && $(uname -m) == x86_64 ]]
export MACOSX_DEPLOYMENT_TARGET=11.0
python3 -m venv .venv-mac
PY="$PWD/.venv-mac/bin/python"
"$PY" -m pip install --upgrade pip
# Binary wheels supply their own OpenSSL; do not link cryptography to Homebrew.
"$PY" -m pip install --only-binary=cryptography,cffi --no-cache-dir -r requirements.txt 'cryptography==46.0.3' 'pyinstaller==6.16.0'
"$PY" -m pip freeze > macos-build-requirements.txt
"$PY" -m PyInstaller --noconfirm --clean --onedir --name meshcore-bot-cli --paths . \
 --collect-submodules modules --collect-all meshcore --collect-all meshcore_cli \
 --collect-all bleak --collect-all cryptography --collect-all flask_socketio \
 --hidden-import engineio.async_drivers.threading \
 --add-data 'modules/web_viewer/templates:modules/web_viewer/templates' \
 --add-data 'modules/web_viewer/static:modules/web_viewer/static' \
 --add-data 'translations:translations' --add-data 'data:data' macos/entry.py
APP="$PWD/dist/MeshCore Bot.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources/bot"
cp -R dist/meshcore-bot-cli/. "$APP/Contents/Resources/bot/"
cp config.ini.example "$APP/Contents/Resources/"
swiftc -O -target x86_64-apple-macos11.0 -framework AppKit macos/MeshCoreDesktop.swift -o "$APP/Contents/MacOS/MeshCoreDesktop"
python3 - "$APP" <<'PY'
import plistlib,sys,pathlib
p=pathlib.Path(sys.argv[1])/'Contents/Info.plist'
p.write_bytes(plistlib.dumps(dict(CFBundleExecutable='MeshCoreDesktop',CFBundleIdentifier='com.bacondisk22.meshcorebot',CFBundleName='MeshCore Bot',CFBundlePackageType='APPL',CFBundleShortVersionString='0.2.0',CFBundleVersion='2',LSMinimumSystemVersion='11.0',NSBluetoothAlwaysUsageDescription='Connect to your MeshCore radio over Bluetooth.',NSBluetoothPeripheralUsageDescription='Connect to your MeshCore radio over Bluetooth.',NSHighResolutionCapable=True)))
PY
codesign --force --deep --sign - "$APP"
codesign --verify --deep --strict "$APP"
file "$APP/Contents/MacOS/MeshCoreDesktop" | tee dist/architecture.txt
grep -q x86_64 dist/architecture.txt
"$APP/Contents/Resources/bot/meshcore-bot-cli" --desktop-self-test | tee dist/self-test.txt
"$APP/Contents/Resources/bot/meshcore-bot-cli" --validate-config --config config.ini.quickstart
"$PY" macos/smoke.py "$APP/Contents/Resources/bot/meshcore-bot-cli" | tee dist/dashboard-test.txt
mkdir -p dist/dmg-stage
cp -R "$APP" dist/dmg-stage/
ln -s /Applications dist/dmg-stage/Applications
hdiutil create -volname 'MeshCore Bot' -srcfolder dist/dmg-stage -ov -format UDZO dist/MeshCore-Bot-Intel.dmg
hdiutil verify dist/MeshCore-Bot-Intel.dmg
shasum -a 256 dist/MeshCore-Bot-Intel.dmg > dist/SHA256SUMS.txt
