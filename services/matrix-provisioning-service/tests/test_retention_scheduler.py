"""Tests for the scheduled retention sweep.

The sweep deletes data on a timer and is on by default, so the rules about
*who* it touches and *which window* it applies are the point of these tests.
"""

from __future__ import annotations

import asyncio
from datetime import datetime, timezone

import pytest

from shared.matrix import SynapseAdminClient
from src.services.retention_scheduler import RetentionScheduler
from src.services.retention_service import RetentionService
from tests.conftest import seed_user

pytestmark = pytest.mark.anyio


def _scheduler(repository, credentials, transport, **kwargs) -> RetentionScheduler:
    service = RetentionService(
        repository, SynapseAdminClient(credentials, transport=transport)
    )
    return RetentionScheduler(service, startup_delay_seconds=0, **kwargs)


async def _redeemed(repository, **overrides):
    user = await seed_user(repository, **overrides)
    return await repository.mark_redeemed(user.bundle_id, datetime.now(timezone.utc))


async def test_sweep_reports_users_purged_and_bytes_reclaimed(
    repository, credentials, mock_transport
):
    await _redeemed(repository, username="one_user")
    await _redeemed(repository, username="two_user")

    summary = await _scheduler(repository, credentials, mock_transport).sweep_once()

    assert summary["purged"] == 2
    assert summary["bytes_freed"] > 0


async def test_sweep_skips_exempt_users(repository, credentials, tracking_transport):
    """An exempt user must never be touched by the automatic sweep."""
    transport, requests = tracking_transport
    kept = await _redeemed(repository, username="exempt_user")
    await repository.update(kept.bundle_id, retention_exempt=True)
    await _redeemed(repository, username="normal_user")

    summary = await _scheduler(repository, credentials, transport).sweep_once()

    assert summary["purged"] == 1
    purged_rooms = [r for r in requests if "/purge_history/" in str(r.url)]
    assert len(purged_rooms) == 1


async def test_sweep_skips_unredeemed_and_revoked(repository, credentials):
    await seed_user(repository, username="never_used")
    revoked = await _redeemed(repository, username="revoked_user")
    await repository.revoke(revoked.bundle_id, "under review")

    summary = await _scheduler(
        repository, credentials, (await _noop_transport())
    ).sweep_once()

    assert summary["purged"] == 0


async def _noop_transport():
    from tests.conftest import synapse_handler

    import httpx

    return httpx.MockTransport(synapse_handler)


async def test_per_user_window_overrides_the_service_default(
    repository, credentials, tracking_transport
):
    """A user pinned to a longer window keeps it when the default changes."""
    import json

    transport, requests = tracking_transport
    pinned = await _redeemed(repository, username="pinned_user")
    await repository.update(pinned.bundle_id, retention_days=365)

    await _scheduler(repository, credentials, transport).sweep_once()

    purge = next(r for r in requests if "/purge_history/" in str(r.url))
    cutoff = json.loads(purge.content)["purge_up_to_ts"]
    now_ms = datetime.now(timezone.utc).timestamp() * 1000
    days_back = (now_ms - cutoff) / 86_400_000
    assert 360 < days_back < 370


async def test_a_user_below_the_floor_is_skipped_not_purged(
    repository, credentials, tracking_transport
):
    """A bad override must not silently widen into a destructive purge."""
    transport, requests = tracking_transport
    bad = await _redeemed(repository, username="bad_user")
    # Written straight to the row: the API validates, but an operator editing
    # SQLite by hand can still leave a value below the floor.
    await repository.update(bad.bundle_id, retention_days=1)

    summary = await _scheduler(repository, credentials, transport).sweep_once()

    assert summary["purged"] == 0
    assert not [r for r in requests if "/purge_history/" in str(r.url)]


async def test_history_only_mode_deletes_no_media(
    repository, credentials, tracking_transport
):
    transport, requests = tracking_transport
    await _redeemed(repository)

    summary = await _scheduler(
        repository, credentials, transport, include_media=False
    ).sweep_once()

    assert summary["media_deleted"] == 0
    assert not [r for r in requests if r.method == "DELETE"]


async def test_the_loop_survives_a_failing_sweep(
    repository, credentials, mock_transport
):
    scheduler = _scheduler(repository, credentials, mock_transport)
    scheduler._interval_seconds = 0
    sweeps, second = [], asyncio.Event()

    async def exploding_sweep():
        sweeps.append(1)
        if len(sweeps) >= 2:
            second.set()
        raise RuntimeError("synapse exploded")

    scheduler.sweep_once = exploding_sweep

    scheduler.start()
    await asyncio.wait_for(second.wait(), timeout=2)
    await scheduler.stop()

    assert len(sweeps) >= 2


async def test_start_is_idempotent_and_stop_is_safe(
    repository, credentials, mock_transport
):
    scheduler = _scheduler(repository, credentials, mock_transport)

    scheduler.start()
    task = scheduler._task
    scheduler.start()

    assert scheduler._task is task
    await scheduler.stop()
    await scheduler.stop()
    assert scheduler._task is None


async def test_the_scheduled_loop_actually_runs_a_sweep(repository, credentials, mock_transport):
    """The loop body is what makes retention automatic; wiring it wrong is silent."""
    scheduler = _scheduler(repository, credentials, mock_transport)
    scheduler._interval_seconds = 0
    swept = asyncio.Event()
    summaries = []

    async def recording_sweep() -> dict:
        summary = {"purged": 1, "bytes_freed": 1500, "media_deleted": 1}
        summaries.append(summary)
        swept.set()
        return summary

    scheduler.sweep_once = recording_sweep

    scheduler.start()
    await asyncio.wait_for(swept.wait(), timeout=2)
    await scheduler.stop()

    assert summaries
