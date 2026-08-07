"""Tests for the redemption poller.

The poller is the only way the server learns that a bundle was used by a client
too old to call the rotation endpoint, so its inference rules matter.
"""

from __future__ import annotations

import asyncio
from datetime import datetime, timezone

import httpx
import pytest
from src.core.models import BundleEventType, BundleStatus
from src.services.redemption_poller import RedemptionPoller
from tests.conftest import seed_user, synapse_handler

from shared.matrix import SynapseAdminClient

pytestmark = pytest.mark.anyio


def _poller(repository, credentials, transport) -> RedemptionPoller:
    return RedemptionPoller(repository, SynapseAdminClient(credentials, transport=transport))


def _handler_with_devices(devices: list[dict]):
    def handler(request: httpx.Request) -> httpx.Response:
        if request.url.path.endswith("/devices"):
            return httpx.Response(200, json={"devices": devices})
        return synapse_handler(request)

    return httpx.MockTransport(handler)


async def test_last_seen_activity_marks_a_bundle_redeemed(repository, credentials, mock_transport):
    user = await seed_user(repository)
    poller = _poller(repository, credentials, mock_transport)

    advanced = await poller.poll_once()

    updated = await repository.get(user.bundle_id)
    assert advanced == 1
    assert updated.status is BundleStatus.REDEEMED
    assert updated.first_login_at == datetime.fromtimestamp(1700000000, tz=timezone.utc)


async def test_a_device_without_last_seen_is_not_a_redemption(repository, credentials):
    """A fresh account already has the provisioner's own session device."""
    user = await seed_user(repository)
    transport = _handler_with_devices([{"device_id": "PROVISIONER"}])
    poller = _poller(repository, credentials, transport)

    advanced = await poller.poll_once()

    updated = await repository.get(user.bundle_id)
    assert advanced == 0
    assert updated.status is BundleStatus.UNUSED
    assert updated.last_polled_at is not None


async def test_no_devices_at_all_is_not_a_redemption(repository, credentials):
    user = await seed_user(repository)
    poller = _poller(repository, credentials, _handler_with_devices([]))

    assert await poller.poll_once() == 0
    assert (await repository.get(user.bundle_id)).status is BundleStatus.UNUSED


async def test_the_newest_device_timestamp_wins(repository, credentials):
    user = await seed_user(repository)
    transport = _handler_with_devices(
        [
            {"device_id": "OLD", "last_seen_ts": 1600000000000},
            {"device_id": "NEW", "last_seen_ts": 1700000000000},
        ]
    )
    poller = _poller(repository, credentials, transport)

    await poller.poll_once()

    updated = await repository.get(user.bundle_id)
    assert updated.last_seen_at == datetime.fromtimestamp(1700000000, tz=timezone.utc)


async def test_polling_is_idempotent_across_sweeps(repository, credentials, mock_transport):
    """Only the first sweep counts as an advance; the record must not churn."""
    await seed_user(repository)
    poller = _poller(repository, credentials, mock_transport)

    first = await poller.poll_once()
    second = await poller.poll_once()

    assert (first, second) == (1, 0)


async def test_a_failing_user_does_not_abort_the_sweep(repository, credentials):
    """One broken account must not block redemption detection for everyone else."""
    broken = await seed_user(repository, username="broken_user")
    healthy = await seed_user(repository, username="healthy_user")

    def handler(request: httpx.Request) -> httpx.Response:
        if "broken_user" in str(request.url) and request.url.path.endswith("/devices"):
            return httpx.Response(500, json={"errcode": "M_UNKNOWN"})
        return synapse_handler(request)

    poller = _poller(repository, credentials, httpx.MockTransport(handler))

    advanced = await poller.poll_once()

    assert advanced == 1
    assert (await repository.get(healthy.bundle_id)).status is BundleStatus.REDEEMED
    assert (await repository.get(broken.bundle_id)).status is BundleStatus.UNUSED


async def test_a_poll_failure_is_recorded_on_the_record(repository, credentials):
    user = await seed_user(repository, username="broken_user")

    def handler(request: httpx.Request) -> httpx.Response:
        if request.url.path.endswith("/devices"):
            return httpx.Response(500, json={"errcode": "M_UNKNOWN"})
        return synapse_handler(request)

    poller = _poller(repository, credentials, httpx.MockTransport(handler))

    await poller.poll_once()

    events = await repository.get_events(user.bundle_id)
    assert events[-1].event_type is BundleEventType.POLL_FAILED
    assert (await repository.get(user.bundle_id)).last_polled_at is not None


async def test_rotated_bundles_are_never_polled_again(repository, credentials, tracking_transport):
    """Terminal records must not cost a Synapse round trip on every sweep."""
    transport, requests = tracking_transport
    user = await seed_user(repository)
    await repository.mark_rotated(user.bundle_id)
    poller = _poller(repository, credentials, transport)

    advanced = await poller.poll_once()

    assert advanced == 0
    assert requests == []


async def test_empty_database_short_circuits(repository, credentials, tracking_transport):
    transport, requests = tracking_transport
    poller = _poller(repository, credentials, transport)

    assert await poller.poll_once() == 0
    assert requests == []


# -- background loop --------------------------------------------------------


async def test_the_loop_keeps_sweeping_until_stopped(repository, credentials, mock_transport):
    poller = _poller(repository, credentials, mock_transport)
    poller._interval_seconds = 0
    sweeps, second_sweep = [], asyncio.Event()

    async def counting_sweep() -> int:
        sweeps.append(1)
        if len(sweeps) >= 2:
            second_sweep.set()
        return 0

    poller.poll_once = counting_sweep

    poller.start()
    await asyncio.wait_for(second_sweep.wait(), timeout=2)
    await poller.stop()

    assert len(sweeps) >= 2


async def test_a_failing_sweep_does_not_kill_the_loop(repository, credentials, mock_transport):
    """One bad sweep must not silently stop redemption detection forever."""
    poller = _poller(repository, credentials, mock_transport)
    poller._interval_seconds = 0
    sweeps, second_sweep = [], asyncio.Event()

    async def exploding_sweep() -> int:
        sweeps.append(1)
        if len(sweeps) >= 2:
            second_sweep.set()
        raise RuntimeError("synapse exploded")

    poller.poll_once = exploding_sweep

    poller.start()
    await asyncio.wait_for(second_sweep.wait(), timeout=2)
    await poller.stop()

    assert len(sweeps) >= 2


async def test_start_is_idempotent(repository, credentials, mock_transport):
    poller = _poller(repository, credentials, mock_transport)

    poller.start()
    task = poller._task
    poller.start()

    assert poller._task is task
    await poller.stop()


async def test_stop_without_start_is_safe(repository, credentials, mock_transport):
    await _poller(repository, credentials, mock_transport).stop()


async def test_stop_is_idempotent(repository, credentials, mock_transport):
    poller = _poller(repository, credentials, mock_transport)
    poller.start()

    await poller.stop()
    await poller.stop()

    assert poller._task is None
