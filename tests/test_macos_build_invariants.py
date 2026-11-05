"""Static regression checks for Intel Mac build safety."""
from pathlib import Path

BUILD = (Path(__file__).resolve().parents[1] / "macos/build-app.sh").read_text()


def test_build_requires_intel_macos():
    assert "uname -s" in BUILD
    assert "uname -m" in BUILD
    assert "x86_64" in BUILD


def test_app_signature_is_verified():
    assert "codesign --verify --deep --strict" in BUILD


def test_packaged_bot_runs_smoke_check():
    assert "--packaging-smoke" in BUILD


def test_archive_checksum_manifest_is_generated_and_checked():
    assert "SHA256SUMS.txt" in BUILD
    assert "shasum -a 256 -c SHA256SUMS.txt" in BUILD
