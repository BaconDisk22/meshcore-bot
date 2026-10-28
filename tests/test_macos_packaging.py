"""Check that desktop packaging retains dynamically discovered bot commands."""
import importlib.util
from pathlib import Path


def test_desktop_runtime_smoke():
    entry = Path(__file__).resolve().parents[1] / 'macos' / 'frozen_entry.py'
    spec = importlib.util.spec_from_file_location('desktop_entry', entry)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    module.packaging_smoke()
