#!/bin/bash
# Run from any directory using an Intel Python environment with requirements installed.
set -euo pipefail
cd "$(dirname "$0")/.."
PYTHON="${PYTHON:-python3}"
[[ "$(uname -s)" == Darwin && "$(uname -m)" == x86_64 ]] || { echo 'An Intel Mac is required.'; exit 1; }
"$PYTHON" -c 'import platform; assert platform.machine() == "x86_64", "Use an Intel Python"'
"$PYTHON" -m PyInstaller --noconfirm --clean --onedir --name meshcore-bot-cli \
  --target-architecture x86_64 \
  --collect-submodules modules --collect-all meshcore --collect-all meshcore_cli \
  --hidden-import engineio.async_drivers.threading \
  --add-data 'modules:modules' \
  --add-data 'translations:translations' --add-data 'data:data' \
  --add-data 'config.ini.example:.' --paths . macos/frozen_entry.py
# Include module source because PluginLoader discovers commands with glob("*.py").
APP='output/MeshCore Bot.app'
if [[ -e "$APP" ]]; then echo 'Remove output/MeshCore Bot.app before rebuilding.'; exit 1; fi
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources/bot"
cp -R dist/meshcore-bot-cli/. "$APP/Contents/Resources/bot/"
cp config.ini.example "$APP/Contents/Resources/config.ini.example"
swiftc -module-cache-path build/swift-cache -O -target x86_64-apple-macos11.0 -framework AppKit \
  macos/MeshCoreDesktop.swift -o "$APP/Contents/MacOS/MeshCoreDesktop"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleExecutable</key><string>MeshCoreDesktop</string>
  <key>CFBundleIdentifier</key><string>com.bacondisk22.meshcorebot</string>
  <key>CFBundleName</key><string>MeshCore Bot</string>
  <key>CFBundleDisplayName</key><string>MeshCore Bot</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>11.0</string>
  <key>NSBluetoothAlwaysUsageDescription</key><string>Connect to your MeshCore radio over Bluetooth.</string>
  <key>NSBluetoothPeripheralUsageDescription</key><string>Connect to your MeshCore radio over Bluetooth.</string>
</dict></plist>
PLIST
chmod +x "$APP/Contents/MacOS/MeshCoreDesktop" "$APP/Contents/Resources/bot/meshcore-bot-cli"
codesign --force --deep --sign - "$APP"
codesign --verify --deep --strict "$APP"
lipo -verify_arch x86_64 "$APP/Contents/MacOS/MeshCoreDesktop"
lipo -verify_arch x86_64 "$APP/Contents/Resources/bot/meshcore-bot-cli"
"$APP/Contents/Resources/bot/meshcore-bot-cli" --help
"$APP/Contents/Resources/bot/meshcore-bot-cli" --packaging-smoke
# ditto preserves executable permissions and bundle symlinks in the downloadable ZIP.
ditto -c -k --sequesterRsrc --keepParent "$APP" output/MeshCore-Bot-Intel-Mac.zip
mkdir -p output/dmg
cp -R "$APP" output/dmg/
ln -s /Applications output/dmg/Applications
hdiutil create -volname 'MeshCore Bot' -srcfolder output/dmg -ov -format UDZO output/MeshCore-Bot-Intel-Mac.dmg
(cd output && shasum -a 256 MeshCore-Bot-Intel-Mac.zip MeshCore-Bot-Intel-Mac.dmg > SHA256SUMS.txt)
