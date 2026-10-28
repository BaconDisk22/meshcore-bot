# MeshCore Bot — Halloween edition for Intel Mac

The native Mac window uses black, pumpkin orange and purple. The web dashboard defaults to a matching dark palette with lime connection indicators. Existing saved light-mode preferences and the theme toggle still work.

## Download and open

Open **Actions → Build Intel Mac Desktop App**, select a successful run for the PR or `main`, and download **MeshCore-Bot-Intel-Mac** (GitHub sign-in required). Unzip the artifact, then open the DMG and drag **MeshCore Bot.app** to Applications. Alternatively unzip the inner app ZIP. Double-click the app; Python is bundled and no Terminal setup is needed.

The workflow uses `macos-26-intel` (Tahoe), Python 3.11 x64, and verifies the launcher and bundled CLI are x86_64. The build includes command source files needed for dynamic plugin discovery, templates, static assets, translations and data. A frozen-runtime smoke check imports the core, web viewer and command modules without connecting to a radio.

The app is **ad-hoc signed, not Apple Developer ID signed or notarized**. macOS may require **System Settings → Privacy & Security → Open Anyway** after the first launch attempt. Only approve a build you trust. A notarized release requires the maintainer's Apple signing credentials.

## Configure and run

1. Open the app and click **Edit Config**. Settings remain at `~/Library/Application Support/MeshCore Bot/config.ini`. Updating the app never replaces this file. Back up this whole folder before migrating an existing installation; copy your config and databases there while the bot is stopped.
2. In `[Connection]`, configure your radio. For serial, use its actual `/dev/cu.usbserial-…` or `/dev/cu.usbmodem…` device path. BLE and TCP use the existing upstream settings.
3. For the dashboard, set `[Web_Viewer]` to `enabled = true`, `host = 127.0.0.1`, `port = 8080`. The **Open Dashboard** button opens that fixed local address; if you configure a different port, open it manually in your browser.
4. Click **Start Bot**, inspect the logs, and open the dashboard. **Stop Bot**, quitting, or closing the last window requests bot shutdown. Do not run another service against the same radio simultaneously.

First launch copies the example configuration with a loopback-only viewer address. It does not start the bot automatically. Existing configuration, credentials, plugins and bot behavior are preserved; optional Python plugin dependencies must be included when building a custom app.

## Build this checkout

On an Intel Mac with Apple Command Line Tools and Intel Python 3.11:

```sh
python3.11 -m venv .venv
.venv/bin/python -m pip install --prefer-binary -r requirements.txt 'pyinstaller>=6,<7'
PYTHON="$PWD/.venv/bin/python" bash macos/build-app.sh
```

Outputs are `output/MeshCore Bot.app`, a DMG, an app ZIP and SHA-256 checksums. Move old `output/` aside before rebuilding. `macos/local-builder/build-on-intel-mac.command` is an alternative double-click builder that downloads **main**, not an unmerged PR. To test a PR use its Actions artifact or build its checkout.

## Automation and verification

PRs, pushes to main and the desktop feature branches, and manual dispatch build downloadable artifacts. Pushing a `mac-v*` tag creates a **draft** release with the DMG, ZIP and checksums; it does not publish or merge automatically.

Before merging or publishing, verify on the target Intel Tahoe Mac: first launch, existing config retained after replacing the app, resize and log readability, Start/Stop/Start, quit/close shutdown, actual serial/BLE/TCP operation, and dashboard login and commands. Radio hardware checks cannot be established by the packaging smoke test. The dashboard retains upstream CDN dependencies for Bootstrap, icons and other libraries.
