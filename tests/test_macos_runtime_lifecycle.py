"""Static guards for Intel Mac desktop runtime safety."""
from pathlib import Path

SOURCE = (Path(__file__).resolve().parents[1] / "macos/MeshCoreDesktop.swift").read_text()


def test_log_reader_detached_on_quit_and_launch_failure():
    assert "logPipe?.fileHandleForReading.readabilityHandler = nil" in SOURCE
    assert "pipe.fileHandleForReading.readabilityHandler = nil" in SOURCE


def test_no_synchronous_wait_on_quit():
    shutdown = SOURCE.split("func applicationShouldTerminate(", 1)[1].split("func applicationShouldTerminateAfterLastWindowClosed", 1)[0]
    assert "running.terminate()" in shutdown
    assert "waitUntilExit()" not in shutdown


def test_prevent_duplicate_bot_process():
    start = SOURCE.split("@objc private func startBot()", 1)[1].split("@objc private func stopBot()", 1)[0]
    assert "guard process == nil else" in start
    assert "p.terminationHandler" in start


def test_log_updates_run_on_main_queue():
    log = SOURCE.split("private func appendLog(", 1)[1].split("private func showError(", 1)[0]
    assert "DispatchQueue.main.async" in log
