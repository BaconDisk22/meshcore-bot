#!/bin/bash
# Build a local Intel Mac desktop application from the public BaconDisk22 MeshCore bot fork.
set -Eeuo pipefail
trap 'echo; echo "Build stopped on line $LINENO. Scroll up for the error."; read -r -p "Press Return to close..." _ || true' ERR

ROOT="$(cd "$(dirname "$0")" && pwd)"
WORK="$HOME/Downloads/MeshCore-Mac-Build"
REPO_ZIP="$WORK/source.zip"
REPO_DIR="$WORK/source"
OUT="$HOME/Desktop/MeshCore Bot.app"
mkdir -p "$WORK"

if [[ "$(uname -s)" != "Darwin" || "$(uname -m)" != "x86_64" ]]; then
  echo 'This package builds on an Intel (x86_64) Mac only.'
  exit 1
fi
if ! xcrun --find swiftc >/dev/null 2>&1; then
  echo 'Apple Command Line Tools are required. Install them with: xcode-select --install'
  exit 1
fi
PYTHON=''
for candidate in python3.11 /usr/local/bin/python3.11 /opt/homebrew/bin/python3.11; do
  if command -v "$candidate" >/dev/null 2>&1; then PYTHON="$(command -v "$candidate")"; break; fi
done
if [[ -z "$PYTHON" ]]; then
  echo 'Python 3.11 is required. Install it from https://www.python.org/downloads/release/python-3119/ and rerun.'
  exit 1
fi

echo 'Downloading source code from BaconDisk22/meshcore-bot...'
curl --fail --location --retry 3 --connect-timeout 20 \
  'https://github.com/BaconDisk22/meshcore-bot/archive/refs/heads/main.zip' -o "$REPO_ZIP"
rm -rf "$REPO_DIR"
mkdir -p "$REPO_DIR"
unzip -q "$REPO_ZIP" -d "$REPO_DIR"
PROJECT="$(find "$REPO_DIR" -mindepth 1 -maxdepth 1 -type d -name 'meshcore-bot-*' | head -n 1)"
if [[ -z "$PROJECT" || ! -f "$PROJECT/meshcore_bot.py" ]]; then
  echo 'Could not find the expected source files in the downloaded archive.'
  exit 1
fi
cd "$PROJECT"
"$PYTHON" -m venv "$WORK/venv"
"$WORK/venv/bin/python" -m pip install --upgrade pip
"$WORK/venv/bin/python" -m pip install -r requirements.txt 'pyinstaller>=6,<7'

ARGS=(--noconfirm --clean --onedir --name meshcore-bot-cli \
  --collect-submodules modules --collect-all meshcore --collect-all meshcore_cli)
for spec in 'modules/web_viewer/templates:modules/web_viewer/templates' \
            'modules/web_viewer/static:modules/web_viewer/static' \
            'translations:translations' 'data:data'; do
  source="${spec%%:*}"
  if [[ -e "$source" ]]; then ARGS+=(--add-data "$spec"); fi
done
"$WORK/venv/bin/pyinstaller" "${ARGS[@]}" meshcore_bot.py

if [[ -e "$OUT" ]]; then
  BACKUP="$HOME/Desktop/MeshCore Bot backup $(date +%Y%m%d-%H%M%S).app"
  mv "$OUT" "$BACKUP"
  echo "Existing app moved to: $BACKUP"
fi
mkdir -p "$OUT/Contents/MacOS" "$OUT/Contents/Resources/bot"
cp -R dist/meshcore-bot-cli/. "$OUT/Contents/Resources/bot/"
cp config.ini.example "$OUT/Contents/Resources/config.ini.example"
swiftc -O -target x86_64-apple-macos11.0 -framework AppKit \
  "$ROOT/macos/MeshCoreDesktop.swift" -o "$OUT/Contents/MacOS/MeshCoreDesktop"
cat > "$OUT/Contents/Info.plist" <<'PLIST'
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
chmod +x "$OUT/Contents/MacOS/MeshCoreDesktop" "$OUT/Contents/Resources/bot/meshcore-bot-cli"
codesign --force --deep --sign - "$OUT"
echo
echo "App created: $OUT"
echo 'This is an unsigned/not-notarized local prototype. Radio operation is not yet tested.'
open -R "$OUT"
read -r -p 'Press Return to close...' _ || true
