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
"$WORK/venv/bin/python" -m pip install --prefer-binary -r requirements.txt 'pyinstaller>=6,<7'

# Use the same packaging and verification path as GitHub Actions.
PYTHON="$WORK/venv/bin/python" bash macos/build-app.sh
if [[ -e "$OUT" ]]; then
  BACKUP="$HOME/Desktop/MeshCore Bot backup $(date +%Y%m%d-%H%M%S).app"
  mv "$OUT" "$BACKUP"
  echo "Existing app moved to: $BACKUP"
fi
cp -R 'output/MeshCore Bot.app' "$OUT"
echo "App created: $OUT"
echo 'Ad-hoc signed; not Apple notarized. Radio operation needs device testing.'
open -R "$OUT"
read -r -p 'Press Return to close...' _ || true
