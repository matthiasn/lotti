"""Tests for sync-room history retention.

The purge is destructive and irreversible, so the guards around *what* gets
purged and *with which flags* are the point of these tests.
"""

from __future__ import annotations

import json
from datetime import datetime, timedelta, timezone

import httpx
import pytest

from shared.matrix import SynapseAdminClient
from src.core.exceptions import BundleNotFoundException, SynapseUnavailableException
from src.services.retention_service import RetentionService
from tests.conftest import ROOM_ID, seed_user, synapse_handler

pytestmark = pytest.mark.anyio


def _service(repository, credentials, transport, **kwargs) -> RetentionService:
    return RetentionService(
        repository, SynapseAdminClient(credentials, transport=transport), **kwargs
    )


async def _redeemed_user(repository, **overrides):
    user = await seed_user(repository, **overrides)
    return await repository.mark_redeemed(user.bundle_id, datetime.now(timezone.utc))


async def test_purge_always_sets_delete_local_events(
    repository, credentials, tracking_transport
):
    """Sync rooms are non-federated, so every event is local.

    Without this flag Synapse reports success and frees nothing.
    """
    transport, requests = tracking_transport
    user = await _redeemed_user(repository)
    service = _service(repository, credentials, transport)

    await service.purge_room(user.bundle_id)

    purge = next(r for r in requests if "/purge_history/" in str(r.url))
    assert json.loads(purge.content)["delete_local_events"] is True


async def test_purge_cutoff_matches_the_retention_window(
    repository, credentials, tracking_transport
):
    transport, requests = tracking_transport
    user = await _redeemed_user(repository)
    service = _service(repository, credentials, transport)

    result = await service.purge_room(user.bundle_id, retention_days=30)

    purge = next(r for r in requests if "/purge_history/" in str(r.url))
    sent_ts = json.loads(purge.content)["purge_up_to_ts"]
    expected = (datetime.now(timezone.utc) - timedelta(days=30)).timestamp() * 1000
    assert abs(sent_ts - expected) < 5000
    assert result["retention_days"] == 30


async def test_default_retention_is_thirty_days(
    repository, credentials, tracking_transport
):
    transport, _ = tracking_transport
    user = await _redeemed_user(repository)
    service = _service(repository, credentials, transport)

    result = await service.purge_room(user.bundle_id)

    assert result["retention_days"] == 30


async def test_purge_records_the_run_for_later_status_polling(
    repository, credentials, mock_transport
):
    user = await _redeemed_user(repository)
    service = _service(repository, credentials, mock_transport)

    result = await service.purge_room(user.bundle_id)

    purges = await repository.list_purges(user.bundle_id)
    assert result["purge_id"] == "purge_abc"
    assert purges[0]["room_id"] == ROOM_ID
    assert purges[0]["status"] == "active"


async def test_refresh_purge_status_persists_completion(
    repository, credentials, mock_transport
):
    user = await _redeemed_user(repository)
    service = _service(repository, credentials, mock_transport)
    await service.purge_room(user.bundle_id)

    status = await service.refresh_purge_status("purge_abc")

    assert status == "complete"
    assert (await repository.list_purges())[0]["completed_at"] is not None


@pytest.mark.parametrize("days", [0, 1, 6, -30])
async def test_retention_below_the_floor_is_rejected(
    repository, credentials, mock_transport, days
):
    """Too short a window would outrun the backfill amnesty."""
    user = await _redeemed_user(repository)
    service = _service(repository, credentials, mock_transport)

    with pytest.raises(ValueError, match="at least"):
        await service.purge_room(user.bundle_id, retention_days=days)


async def test_rejected_retention_starts_no_purge(
    repository, credentials, tracking_transport
):
    transport, requests = tracking_transport
    user = await _redeemed_user(repository)
    service = _service(repository, credentials, transport)

    with pytest.raises(ValueError):
        await service.purge_room(user.bundle_id, retention_days=1)

    assert not [r for r in requests if "/purge_history/" in str(r.url)]


async def test_purging_an_unknown_bundle_raises_not_found(
    repository, credentials, mock_transport
):
    service = _service(repository, credentials, mock_transport)

    with pytest.raises(BundleNotFoundException):
        await service.purge_room("no-such-bundle")


async def test_synapse_failure_surfaces_and_records_nothing(repository, credentials):
    user = await _redeemed_user(repository)

    def handler(request: httpx.Request) -> httpx.Response:
        if "/purge_history/" in str(request.url):
            return httpx.Response(500, json={"errcode": "M_UNKNOWN"})
        return synapse_handler(request)

    service = _service(repository, credentials, httpx.MockTransport(handler))

    with pytest.raises(SynapseUnavailableException):
        await service.purge_room(user.bundle_id)

    assert await repository.list_purges() == []


async def test_missing_purge_id_is_treated_as_a_failure(repository, credentials):
    user = await _redeemed_user(repository)

    def handler(request: httpx.Request) -> httpx.Response:
        if "/purge_history/" in str(request.url):
            return httpx.Response(200, json={})
        return synapse_handler(request)

    service = _service(repository, credentials, httpx.MockTransport(handler))

    with pytest.raises(SynapseUnavailableException):
        await service.purge_room(user.bundle_id)


async def test_purge_all_skips_unredeemed_and_revoked_rooms(
    repository, credentials, tracking_transport
):
    """An unredeemed room holds nothing; a revoked one may be under investigation."""
    transport, requests = tracking_transport
    active = await _redeemed_user(repository, username="active_user")
    await seed_user(repository, username="never_used")
    revoked = await _redeemed_user(repository, username="revoked_user")
    await repository.revoke(revoked.bundle_id, "under review")
    service = _service(repository, credentials, transport)

    started = await service.purge_all()

    assert [p["bundle_id"] for p in started] == [active.bundle_id]
    assert len([r for r in requests if "/purge_history/" in str(r.url)]) == 1


async def test_purge_all_continues_past_a_failing_room(repository, credentials):
    await _redeemed_user(repository, username="broken_user")
    await _redeemed_user(repository, username="healthy_user")

    def handler(request: httpx.Request) -> httpx.Response:
        if "/purge_history/" in str(request.url) and "broken" in str(request.content):
            return httpx.Response(500, json={})
        return synapse_handler(request)

    # The room ID is shared by the fixtures, so fail by call order instead.
    calls = {"n": 0}

    def ordered_handler(request: httpx.Request) -> httpx.Response:
        if "/purge_history/" in str(request.url):
            calls["n"] += 1
            if calls["n"] == 1:
                return httpx.Response(500, json={})
        return synapse_handler(request)

    service = _service(repository, credentials, httpx.MockTransport(ordered_handler))

    started = await service.purge_all()

    assert len(started) == 1


async def test_purge_all_validates_retention_before_any_work(
    repository, credentials, tracking_transport
):
    transport, requests = tracking_transport
    await _redeemed_user(repository)
    service = _service(repository, credentials, transport)

    with pytest.raises(ValueError, match="at least"):
        await service.purge_all(retention_days=2)

    assert requests == []
