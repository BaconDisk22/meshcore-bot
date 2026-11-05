# MeshCore Bot v0.1.0-rc.1 — release candidate gate

Status: **preparation only**. Do not publish or tag until all required gates pass.

## Automated checks
- [ ] Latest `main` commit passes the full Tests workflow.
- [ ] Latest `main` commit passes Intel Mac Desktop App build.
- [ ] Download CI artifact; verify ZIP and DMG SHA256 checksums.
- [ ] Verify app bundle signature and x86_64 executable architecture.
- [ ] Confirm no unexpected release is created from a PR or branch push.

## Intel Mac manual smoke test
- [ ] Download CI ZIP or DMG to an Intel Mac and open the app.
- [ ] Confirm initial configuration is created without overwriting custom settings.
- [ ] Start bot with a valid MeshCore configuration.
- [ ] Confirm dashboard opens on loopback only.
- [ ] Confirm log output remains readable across long sessions.
- [ ] Stop and restart bot; close app; verify no orphan bot process.

## Real MeshCore radio tests (required before stable release)
- [ ] Connect to a supported MeshCore companion radio using a configured transport.
- [ ] Confirm receive/send behavior only after explicit operator configuration.
- [ ] Disconnect and reconnect radio; verify state and logs.
- [ ] Stop the bot during reconnect and confirm shutdown wins.
- [ ] Verify failures are surfaced without repeated uncontrolled retries.

## Candidate distribution
- [ ] Document that the Mac app is ad-hoc signed and **not notarized**.
- [ ] Include installation notes, known limitations, and checksums.
- [ ] If candidate is approved, create a **draft prerelease** for `v0.1.0-rc.1`; do not mark as stable.
- [ ] Obtain explicit approval before publishing a release.

Hardware verification remains pending until performed by a tester.