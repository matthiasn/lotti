"""Tests for sync-room history retention.

The purge is destructive and irreversible, so the guards around *what* gets
purged and *with which flags* are the point of these tests.
"""

from __future__ import annotations

import json
from datetime import datetime, timedelta, timezone
from urllib.parse import unquote

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


# -- media reclamation ------------------------------------------------------


async def test_purge_deletes_media_and_reports_bytes_freed(
    repository, credentials, mock_transport
):
    """Purging history alone frees almost nothing; media is the disk."""
    user = await _redeemed_user(repository)
    service = _service(repository, credentials, mock_transport)

    result = await service.purge_room(user.bundle_id)

    assert result["media_deleted"] == 1
    # Mock reports 3500 bytes before and 1000 after the delete.
    assert result["bytes_freed"] == 2500


async def test_media_delete_uses_the_same_cutoff_as_the_history_purge(
    repository, credentials, tracking_transport
):
    transport, requests = tracking_transport
    user = await _redeemed_user(repository)
    service = _service(repository, credentials, transport)

    result = await service.purge_room(user.bundle_id, retention_days=30)

    delete = next(
        r for r in requests if r.method == "DELETE" and "/media" in str(r.url)
    )
    assert int(delete.url.params["before_ts"]) == result["purge_up_to_ts"]


async def test_include_media_false_leaves_files_alone(
    repository, credentials, tracking_transport
):
    """History-only mode must not touch the media store."""
    transport, requests = tracking_transport
    user = await _redeemed_user(repository)
    service = _service(repository, credentials, transport)

    result = await service.purge_room(user.bundle_id, include_media=False)

    assert result["media_deleted"] == 0
    assert result["bytes_freed"] == 0
    assert not [r for r in requests if r.method == "DELETE"]


async def test_media_failure_after_history_purge_reports_partial_success(
    repository, credentials
):
    """The operator must learn history went but media did not."""
    user = await _redeemed_user(repository)

    def handler(request: httpx.Request) -> httpx.Response:
        if request.method == "DELETE" and "/media" in str(request.url):
            return httpx.Response(500, json={"errcode": "M_UNKNOWN"})
        return synapse_handler(request)

    service = _service(repository, credentials, httpx.MockTransport(handler))

    with pytest.raises(SynapseUnavailableException, match="History purged"):
        await service.purge_room(user.bundle_id)

    # The history purge really did happen, so it stays on the record.
    assert await repository.list_purges(user.bundle_id) != []


async def test_purge_all_reclaims_media_for_every_eligible_room(
    repository, credentials, tracking_transport
):
    transport, requests = tracking_transport
    await _redeemed_user(repository, username="one_user")
    await _redeemed_user(repository, username="two_user")
    service = _service(repository, credentials, transport)

    started = await service.purge_all()

    # Which accounts were reclaimed, not how many calls it took: media deletion
    # pages until a batch comes back empty, so the call count is an artefact of
    # the page size while the set of users covered is the actual contract.
    deleted_for = {
        unquote(str(r.url).split("/users/")[1].split("/media")[0])
        for r in requests
        if r.method == "DELETE" and "/media" in str(r.url)
    }
    assert len(started) == 2
    assert deleted_for == {"@one_user:example.com", "@two_user:example.com"}


async def test_a_stored_zero_window_is_refused_rather_than_silently_defaulted(
    repository, credentials, tracking_transport
):
    """0 means "purge everything", which must hit the floor, not the default.

    Read as falsy it would fall back to 30 days — the sweep would quietly do
    something other than what the record says.
    """
    transport, requests = tracking_transport
    await _redeemed_user(repository, username="zero_user")
    user = await repository.find_by_username("zero_user")
    await repository.update(user.bundle_id, retention_days=0)
    service = _service(repository, credentials, transport)

    started = await service.purge_all()

    assert started == []
    assert [r for r in requests if "purge_history" in str(r.url)] == []


async def test_a_pinned_window_still_wins_over_the_sweep_default(
    repository, credentials, mock_transport
):
    await _redeemed_user(repository, username="pinned_user")
    user = await repository.find_by_username("pinned_user")
    await repository.update(user.bundle_id, retention_days=365)
    service = _service(repository, credentials, mock_transport)

    started = await service.purge_all(retention_days=30)

    assert [r["retention_days"] for r in started] == [365]


async def test_a_manual_purge_applies_the_users_own_window(
    repository, credentials, mock_transport
):
    """Manual and scheduled purges must agree, or "purge now" over-deletes.

    Falling back to the service default here would take 335 days more history
    than a user pinned to 365 days is meant to keep.
    """
    user = await _redeemed_user(repository, username="pinned_manual")
    await repository.update(user.bundle_id, retention_days=365)
    service = _service(repository, credentials, mock_transport)

    result = await service.purge_room(user.bundle_id)

    assert result["retention_days"] == 365


async def test_an_explicit_window_still_overrides_the_users_own(
    repository, credentials, mock_transport
):
    user = await _redeemed_user(repository, username="explicit_user")
    await repository.update(user.bundle_id, retention_days=365)
    service = _service(repository, credentials, mock_transport)

    result = await service.purge_room(user.bundle_id, retention_days=30)

    assert result["retention_days"] == 30


async def test_a_user_without_an_override_gets_the_service_default(
    repository, credentials, mock_transport
):
    user = await _redeemed_user(repository, username="unpinned_user")
    service = _service(repository, credentials, mock_transport, default_retention_days=45)

    result = await service.purge_room(user.bundle_id)

    assert result["retention_days"] == 45


# -- lifetime volume --------------------------------------------------------


async def test_a_purge_records_what_it_reclaimed(
    repository, credentials, mock_transport
):
    """Once the files are gone this row is the only evidence they existed."""
    user = await _redeemed_user(repository, username="volume_user")
    service = _service(repository, credentials, mock_transport)

    result = await service.purge_room(user.bundle_id)

    run = (await repository.list_purges(user.bundle_id))[0]
    assert run["bytes_freed"] == result["bytes_freed"] > 0
    assert run["media_deleted"] == result["media_deleted"] > 0


async def test_reclaimed_volume_accumulates_across_purges(
    repository, credentials, mock_transport
):
    """Lifetime is a sum over runs, so a second sweep must add to the first."""
    user = await _redeemed_user(repository, username="repeat_user")
    service = _service(repository, credentials, mock_transport)

    first = await service.purge_room(user.bundle_id)
    second = await service.purge_room(user.bundle_id)

    total_bytes, total_files = await repository.purged_totals(user.bundle_id)
    assert total_bytes == first["bytes_freed"] + second["bytes_freed"]
    assert total_files == first["media_deleted"] + second["media_deleted"]


async def test_a_history_only_purge_records_no_reclaimed_volume(
    repository, credentials, mock_transport
):
    """Nothing was freed, so nothing may be added to the lifetime total."""
    user = await _redeemed_user(repository, username="history_only_user")
    service = _service(repository, credentials, mock_transport)

    await service.purge_room(user.bundle_id, include_media=False)

    assert await repository.purged_totals(user.bundle_id) == (0, 0)


async def test_a_user_who_was_never_purged_has_a_zero_total(repository):
    user = await seed_user(repository, username="untouched_user")

    assert await repository.purged_totals(user.bundle_id) == (0, 0)


async def test_a_failed_media_deletion_records_no_volume(repository, credentials):
    """A partial failure must not book bytes that were never actually freed."""
    user = await _redeemed_user(repository, username="failed_media_user")

    def handler(request: httpx.Request) -> httpx.Response:
        if request.method == "DELETE" and "/media" in str(request.url):
            return httpx.Response(500, json={"errcode": "M_UNKNOWN"})
        return synapse_handler(request)

    service = _service(repository, credentials, httpx.MockTransport(handler))

    with pytest.raises(SynapseUnavailableException):
        await service.purge_room(user.bundle_id)

    assert await repository.purged_totals(user.bundle_id) == (0, 0)
