"""Protect critical Intel Mac configuration editor safety guarantees."""
from pathlib import Path

SWIFT = (Path(__file__).resolve().parents[1] / "macos/MeshCoreDesktop.swift").read_text()
EDITOR = SWIFT.split("@objc private func editConfig()", 1)[1].split("@objc private func openFolder()", 1)[0]


def test_config_is_not_overwritten_without_changes():
    assert "guard updated != contents else { return }" in EDITOR


def test_empty_and_missing_required_sections_rejected():
    assert "trimmingCharacters(in: .whitespacesAndNewlines).isEmpty" in EDITOR
    assert 'updated.contains("[Connection]")' in EDITOR
    assert 'updated.contains("[Bot]")' in EDITOR


def test_backup_created_before_atomic_write():
    assert "config.ini.bak" in EDITOR
    assert EDITOR.index("copyItem(at: config") < EDITOR.index("updated.write(to: config")
    assert "atomically: true" in EDITOR


def test_config_editor_does_not_invoke_external_textedit():
    assert "TextEdit.app" not in EDITOR
    assert "NSWorkspace.shared.open" not in EDITOR
