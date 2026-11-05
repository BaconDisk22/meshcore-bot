"""Additional radio-free regression tests for reconnect state handoffs."""
import threading

from modules.core import MeshCoreBot


def make_bot():
    bot = object.__new__(MeshCoreBot)
    bot._shutdown_event = threading.Event()
    bot.connected = False
    bot._transport_reconnect_in_progress = False
    bot._radio_relinks_in_progress = 0
    return bot


def test_multiple_relinks_keep_bot_alive_until_final_relink_finishes():
    bot = make_bot()
    bot._radio_relinks_in_progress = 2
    assert bot.keep_running
    bot._radio_relinks_in_progress = 1
    assert bot.keep_running
    bot._radio_relinks_in_progress = 0
    assert not bot.keep_running


def test_successful_transport_handoff_remains_running():
    bot = make_bot()
    bot._transport_reconnect_in_progress = True
    assert bot.keep_running
    bot.connected = True
    bot._transport_reconnect_in_progress = False
    assert bot.keep_running


def test_failed_transport_reconnect_stops_without_other_relinks():
    bot = make_bot()
    bot._transport_reconnect_in_progress = True
    bot._transport_reconnect_in_progress = False
    assert not bot.keep_running
