"""Catch accidental literal newline escapes in generated Swift source."""
from pathlib import Path

SOURCE = (Path(__file__).resolve().parents[1] / "macos/MeshCoreDesktop.swift").read_text()


def test_log_retention_block_has_real_newlines():
    assert "if let storage = self.output.textStorage" in SOURCE
    assert "storage.deleteCharacters(in:" in SOURCE
    assert "250_000" in SOURCE
    assert r"\n            if let storage" not in SOURCE
    assert r"\n                storage.deleteCharacters" not in SOURCE


def test_log_retention_runs_on_main_thread():
    section = SOURCE.split("private func appendLog(", 1)[1].split("private func showError(", 1)[0]
    assert "DispatchQueue.main.async" in section
    assert "self.output.scrollToEndOfDocument(nil)" in section
