# Intel Mac Desktop Build (prototype)

This adds a GUI for locally running the existing MeshCore bot on an Intel Mac. It does **not** run the bot on another server. The normal command/services are handled by the original Python code bundled in the app.

## Add to your GitHub fork

Copy `macos/MeshCoreDesktop.swift` and `.github/workflows/build-intel-mac.yml` into the same paths in your fork (ideally on a branch named `feature/intel-mac-desktop`). Then go to **Actions → Build Intel Mac Desktop App → Run workflow**. Once the build succeeds, download the artifact, unzip it, and open the `.dmg`.

The app is ad-hoc signed, not Apple Developer ID signed/notarized. macOS Gatekeeper may prevent normal opening until you explicitly approve it in System Settings → Privacy & Security. Do not bypass security prompts for packages from untrusted sources.

## Run the local bot

1. Drag `MeshCore Bot.app` into Applications and open it.
2. Click **Edit Config**. The configuration lives in `~/Library/Application Support/MeshCore Bot/config.ini`, never inside the signed app bundle.
3. In `[Connection]`, set `connection_type = serial` and the actual macOS device path, typically `/dev/cu.usbserial-*` or `/dev/cu.usbmodem*`. Use an actual port name rather than a wildcard. Alternatively set BLE or TCP according to the upstream config docs.
4. To use the bundled web viewer, set `[Web_Viewer]`: `enabled = true`, `host = 127.0.0.1`, `port = 8080`.
5. Click **Start Bot** and inspect logs. Then click **Open Dashboard**. The Mac is running the bot itself; the page is only its user interface.
6. Click **Stop Bot** to stop it. Closing the application also stops the bot. Background/menu-bar operation and automatic start on login are not part of this first prototype.

**Security:** Keep the viewer bound to `127.0.0.1`. Enable authentication before exposing the viewer to any external network. Ensure no other MeshCore bot is operating on the same channel unnecessarily.

**Testing limitations:** This is a first-pass build workflow, not a verified `.dmg`. It still needs a successful GitHub Actions macOS build and real serial/BLE/TCP and dashboard testing. PyInstaller dynamic imports or data paths may require additional packaging changes. Bluetooth access by a child process inside an ad-hoc-signed app also needs real-device verification.
