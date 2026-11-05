"""Static checks for the Intel Mac UI fixes found during hardware smoke testing."""
from pathlib import Path

SOURCE = (Path(__file__).resolve().parents[1] / "macos/MeshCoreDesktop.swift").read_text()


def test_config_editor_is_native_and_has_save_cancel():
    section = SOURCE.split("@objc private func editConfig()", 1)[1].split("@objc private func openFolder()", 1)[0]
    assert "NSTextView" in section
    assert 'alert.addButton(withTitle: "Save Changes")' in section
    assert 'alert.addButton(withTitle: "Cancel")' in section
    assert "atomically: true" in section
    assert "NSWorkspace.shared.open(config)" not in section


def test_app_quit_does_not_wait_synchronously_for_bot():
    section = SOURCE.split("func applicationShouldTerminate(", 1)[1].split("func applicationShouldTerminateAfterLastWindowClosed", 1)[0]
    assert "readabilityHandler = nil" in section
    assert "running.terminate()" in section
    assert "waitUntilExit()" not in section


def test_ui_preserves_controls_and_status():
    for name in ("Start Bot", "Stop Bot", "Edit Config", "Dashboard", "Bot Folder"):
        assert name in SOURCE
    assert "LIVE ACTIVITY" in SOURCE
