"""Radio-free regression checks for transport reconnect lifecycle gating.

A temporary disconnect must not stop the scheduler while a reconnect is
in progress. Once retries are exhausted, normal shutdown can proceed.
"""
import threading

import pytest

from modules.core import MeshCoreBot


@pytest.fixture
def bot_state():
    bot = object.__new__(MeshCoreBot)
    bot._shutdown_event = threading.Event()
    bot.connected = False
    bot._transport_reconnect_in_progress = False
    bot._radio_relinks_in_progress = 0
    return bot


def test_initial_disconnected_state_is_not_running(bot_state):
    assert not bot_state.keep_running


def test_connected_radio_keeps_bot_running(bot_state):
    bot_state.connected = True
    assert bot_state.keep_running


def test_transport_reconnect_keeps_scheduler_alive(bot_state):
    bot_state._transport_reconnect_in_progress = True
    assert bot_state.keep_running
    bot_state._transport_reconnect_in_progress = False
    assert not bot_state.keep_running


def test_web_viewer_relink_keeps_scheduler_alive(bot_state):
    bot_state._radio_relinks_in_progress = 1
    assert bot_state.keep_running
    bot_state._radio_relinks_in_progress = 0
    assert not bot_state.keep_running


@pytest.mark.parametrize("connected,reconnecting,relinks", [
    (True, False, 0),
    (False, True, 0),
    (False, False, 1),
])
def test_shutdown_overrides_all_reconnect_states(bot_state, connected, reconnecting, relinks):
    bot_state.connected = connected
    bot_state._transport_reconnect_in_progress = reconnecting
    bot_state._radio_relinks_in_progress = relinks
    bot_state._shutdown_event.set()
    assert not bot_state.keep_running
