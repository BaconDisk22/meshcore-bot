"""Ensure PR CI cannot silently become a release workflow."""
from pathlib import Path

WORKFLOW = (Path(__file__).resolve().parents[1] / ".github/workflows/build-intel-mac.yml").read_text()


def test_pr_build_has_read_only_contents_permission():
    assert "permissions:\n  contents: read" in WORKFLOW


def test_release_job_requires_version_tag():
    assert "if: startsWith(github.ref, 'refs/tags/mac-v')" in WORKFLOW


def test_mac_artifact_upload_is_required():
    assert "actions/upload-artifact@v4" in WORKFLOW
    assert "if-no-files-found: error" in WORKFLOW
