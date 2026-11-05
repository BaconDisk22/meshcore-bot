"""Radio-free reconnect lifecycle regression matrix."""
import itertools
import threading

import pytest

from modules.core import MeshCoreBot


@pytest.mark.parametrize("connected,reconnecting,relinks,shutting_down", [
    (connected, reconnecting, relinks, shutting_down)
    for connected, reconnecting, relinks, shutting_down
    in itertools.product([False, True], [False, True], [0, 1, 2], [False, True])
])
def test_keep_running_matches_lifecycle_state(connected, reconnecting, relinks, shutting_down):
    bot = object.__new__(MeshCoreBot)
    bot._shutdown_event = threading.Event()
    bot.connected = connected
    bot._transport_reconnect_in_progress = reconnecting
    bot._radio_relinks_in_progress = relinks
    if shutting_down:
        bot._shutdown_event.set()
    assert bot.keep_running is (not shutting_down and (connected or reconnecting or relinks > 0))
