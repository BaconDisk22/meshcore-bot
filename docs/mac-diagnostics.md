# Intel Mac diagnostics checklist

Use this checklist when reporting a problem with the MeshCore Bot desktop app.

## Capture build information

- GitHub Actions build run URL and artifact download date
- macOS version and Intel Mac model
- Whether the bot was running, stopped, or connecting
- Exact action that triggered the issue and expected versus actual behavior

## Configuration editor

Open **Edit Config** and verify that the native plain-text editor appears. Test Cancel and Save separately. Back up `~/Library/Application Support/MeshCore Bot/config.ini` before editing. Do not attach configuration files containing credentials, private keys, location, or personal mesh details.

## App fails to quit

Test quitting once with the bot stopped and again with it running. If Force Quit is needed, capture a sample of the hung process using Activity Monitor → select MeshCore Bot → More → Sample Process. Redact usernames, paths, identifiers and private data before sharing. Record whether a bot subprocess remains after closing the app.

## Radio connection and dashboard

Record the configured connection type (serial/BLE/TCP), whether the companion radio is powered and reachable, and the relevant **Live Activity** messages. The local dashboard is opened through the app's Dashboard button and requires the bot and web viewer to be running. Do not expose private credentials or remote dashboard addresses.

A passing CI build does not establish that a real Intel Mac quit hang or radio connectivity issue is resolved.
