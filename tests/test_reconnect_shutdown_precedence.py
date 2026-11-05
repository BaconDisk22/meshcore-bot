"""Radio-free regression tests for shutdown during overlapping reconnect work."""
import threading

import pytest

from modules.core import MeshCoreBot


@pytest.mark.parametrize("connected,transport,relinks", [
    (False, True, 2),
    (True, True, 1),
    (True, False, 2),
    (False, True, 0),
])
def test_shutdown_always_wins_over_concurrent_reconnect_flags(connected, transport, relinks):
    bot = object.__new__(MeshCoreBot)
    bot._shutdown_event = threading.Event()
    bot.connected = connected
    bot._transport_reconnect_in_progress = transport
    bot._radio_relinks_in_progress = relinks
    assert bot.keep_running
    bot._shutdown_event.set()
    assert not bot.keep_running
