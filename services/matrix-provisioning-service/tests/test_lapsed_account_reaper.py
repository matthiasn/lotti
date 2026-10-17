"""Tests for erasing accounts that stayed lapsed past the grace window."""

from __future__ import annotations

from datetime import timedelta

import pytest
from src.core.models import BundleStatus
from src.services.account_erasure_repository import AccountErasureRepository
from src.services.lapsed_account_reaper import LapsedAccountReaper
from tests.conftest import ROOM_ID
from tests.erasure_fixtures import NOW, paid_account

pytestmark = pytest.mark.anyio


class FakeAdmin:
    def __init__(self):
        self.calls = []
        self.fail_on = None

    async def _record(self, name, *args):
        if self.fail_on == name:
            raise RuntimeError(f"{name} failed")
        self.calls.append((name, *args))

    async def delete_user_media(self, user_mxid, before_ts_ms):
        await self._record("delete_user_media", user_mxid, before_ts_ms)

    async def delete_room(self, room_id):
        await self._record("delete_room", room_id)

    async def erase_user(self, user_mxid):
        await self._record("erase_user", user_mxid)


@pytest.fixture
def repository(tmp_path):
    return AccountErasureRepository(str(tmp_path / "lapsed.db"))


@pytest.fixture
def admin():
    return FakeAdmin()


def reaper_for(repository, admin, **kwargs):
    return LapsedAccountReaper(repository, admin, now_provider=lambda: NOW, **kwargs)


async def test_an_account_suspended_past_the_window_is_erased_completely(repository, admin):
    user = await paid_account(repository, "lapsed", suspended_at=NOW - timedelta(days=31))

    assert await reaper_for(repository, admin).reap_once() == 1

    assert admin.calls == [
        ("delete_user_media", user.user_mxid, int(NOW.timestamp() * 1000)),
        ("delete_room", ROOM_ID),
        ("erase_user", user.user_mxid),
    ]
    assert (await repository.get(user.bundle_id)).status is BundleStatus.REVOKED
    assert await repository.list_open_erasures(limit=10) == []
    # Nothing is offered again.
    assert await reaper_for(repository, admin).reap_once() == 0
    assert len(admin.calls) == 3


async def test_accounts_inside_the_window_or_renewed_are_kept(repository, admin):
    await paid_account(repository, "recent", suspended_at=NOW - timedelta(days=29))
    await paid_account(
        repository,
        "renewed",
        suspended_at=NOW - timedelta(days=60),
        unsuspended_at=NOW - timedelta(days=50),
    )
    await paid_account(repository, "paying")

    assert await reaper_for(repository, admin).reap_once() == 0

    assert admin.calls == []


async def test_a_renewal_after_listing_but_before_claiming_wins(repository, admin):
    await paid_account(repository, "racer", suspended_at=NOW - timedelta(days=31))
    original = repository.list_lapsed_accounts

    async def list_then_renew(**kwargs):
        listed = await original(**kwargs)
        await repository.record_subscription_enforcement(
            "fp-racer", suspended=False, now=NOW - timedelta(seconds=1)
        )
        return listed

    repository.list_lapsed_accounts = list_then_renew

    assert await reaper_for(repository, admin).reap_once() == 0

    assert admin.calls == []


async def test_a_failure_part_way_resumes_at_the_failed_step(repository, admin):
    user = await paid_account(repository, "lapsed", suspended_at=NOW - timedelta(days=31))
    admin.fail_on = "erase_user"

    assert await reaper_for(repository, admin).reap_once() == 0

    [open_erasure] = await repository.list_open_erasures(limit=10)
    assert open_erasure.room_deleted_at is not None
    assert open_erasure.last_error == "erase_user failed"
    admin.calls.clear()
    admin.fail_on = None

    assert await reaper_for(repository, admin).reap_once() == 1

    # Media and room were not touched again: Synapse would refuse the room.
    assert admin.calls == [("erase_user", user.user_mxid)]


async def test_one_failing_account_does_not_stop_the_batch(repository, admin):
    await paid_account(repository, "first", suspended_at=NOW - timedelta(days=40))
    await paid_account(repository, "second", suspended_at=NOW - timedelta(days=35))
    admin.fail_on = "delete_room"

    assert await reaper_for(repository, admin).reap_once() == 0

    assert [call[0] for call in admin.calls] == ["delete_user_media", "delete_user_media"]


async def test_the_oldest_lapses_are_claimed_first_in_bounded_batches(repository, admin):
    older = await paid_account(repository, "older", suspended_at=NOW - timedelta(days=50))
    await paid_account(repository, "newer", suspended_at=NOW - timedelta(days=40))

    assert await reaper_for(repository, admin, batch_size=1).reap_once() == 1

    assert admin.calls[0][1] == older.user_mxid


def test_the_window_cannot_undercut_payment_retries(repository, admin):
    with pytest.raises(ValueError, match="at least 7 days"):
        LapsedAccountReaper(repository, admin, erase_after=timedelta(days=6))


async def test_run_once_reaps(repository, admin):
    await paid_account(repository, "lapsed", suspended_at=NOW - timedelta(days=31))

    await reaper_for(repository, admin).run_once()

    assert len(admin.calls) == 3
