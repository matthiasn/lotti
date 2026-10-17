"""Tests for erasing accounts that stayed lapsed past the grace window."""

# ruff: noqa: S105,S106 - explicit non-production credential fixtures

from __future__ import annotations

from datetime import datetime, timedelta, timezone

import pytest
from src.core.models import BundleStatus
from src.core.subscriptions import (
    AcknowledgementState,
    EntitlementState,
    GoogleSubscriptionState,
    SubscriptionProvider,
    VerifiedSubscription,
)
from src.services.lapsed_account_reaper import LapsedAccountReaper
from src.services.subscription_repository import SubscriptionRepository
from tests.conftest import ROOM_ID, seed_user

pytestmark = pytest.mark.anyio

NOW = datetime(2026, 10, 17, 12, tzinfo=timezone.utc)


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
    return SubscriptionRepository(str(tmp_path / "lapsed.db"))


@pytest.fixture
def admin():
    return FakeAdmin()


def reaper_for(repository, admin, *, now=NOW):
    return LapsedAccountReaper(repository, admin, now_provider=lambda: now)


async def paid_account(repository, name, *, suspended_at=None, unsuspended_at=None):
    """A paid account whose Matrix suspension was observed at ``suspended_at``."""
    user = await seed_user(repository, name)
    await repository.create_entitlement(
        entitlement_id=f"entitlement-{name}",
        obfuscated_account_id=f"obfuscated-{name}",
        auth_secret_hash="auth-hash",
        now=NOW - timedelta(days=90),
    )
    stored = await repository.store_verified_subscription(
        VerifiedSubscription(
            entitlement_id=f"entitlement-{name}",
            token_fingerprint=f"fp-{name}",
            encrypted_purchase_token=b"sealed",
            encryption_key_id="key-v1",
            package_name="paddle",
            product_id="pro_lotti_sync",
            base_plan_id="pri_monthly",
            latest_order_id=None,
            google_state=GoogleSubscriptionState.EXPIRED,
            entitlement_state=EntitlementState.EXPIRED,
            start_time=NOW - timedelta(days=90),
            current_period_end=None,
            grace_deadline=None,
            acknowledgement_state=AcknowledgementState.ACKNOWLEDGED,
            binding_verified=True,
            last_verified_at=NOW - timedelta(days=90),
            next_reconciliation_at=NOW,
            bundle_id=user.bundle_id,
            provider=SubscriptionProvider.PADDLE,
        ),
        now=NOW - timedelta(days=90),
    )
    if suspended_at is not None:
        await repository.record_subscription_enforcement(
            stored.token_fingerprint, suspended=True, now=suspended_at
        )
    if unsuspended_at is not None:
        await repository.record_subscription_enforcement(
            stored.token_fingerprint, suspended=False, now=unsuspended_at
        )
    return user


async def test_an_account_suspended_past_the_window_is_erased_completely(repository, admin):
    user = await paid_account(repository, "lapsed", suspended_at=NOW - timedelta(days=31))

    assert await reaper_for(repository, admin).reap_once() == 1

    assert admin.calls == [
        ("delete_user_media", user.user_mxid, int(NOW.timestamp() * 1000)),
        ("delete_room", ROOM_ID),
        ("erase_user", user.user_mxid),
    ]
    assert (await repository.get(user.bundle_id)).status is BundleStatus.REVOKED
    # Revoked records are not offered again.
    assert await reaper_for(repository, admin).reap_once() == 0


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


async def test_a_failure_part_way_keeps_the_record_for_the_next_run(repository, admin):
    first = await paid_account(repository, "first", suspended_at=NOW - timedelta(days=40))
    second = await paid_account(repository, "second", suspended_at=NOW - timedelta(days=35))
    admin.fail_on = "delete_room"

    assert await reaper_for(repository, admin).reap_once() == 0

    assert (await repository.get(first.bundle_id)).status is not BundleStatus.REVOKED
    assert (await repository.get(second.bundle_id)).status is not BundleStatus.REVOKED
    # Both were attempted: one account's failure does not stop the batch.
    assert [call[1] for call in admin.calls] == [first.user_mxid, second.user_mxid]

    admin.fail_on = None
    assert await reaper_for(repository, admin).reap_once() == 2


async def test_the_oldest_lapses_are_erased_first_in_bounded_batches(repository, admin):
    older = await paid_account(repository, "older", suspended_at=NOW - timedelta(days=50))
    await paid_account(repository, "newer", suspended_at=NOW - timedelta(days=40))
    reaper = LapsedAccountReaper(repository, admin, batch_size=1, now_provider=lambda: NOW)

    assert await reaper.reap_once() == 1

    assert admin.calls[0][1] == older.user_mxid


def test_the_window_cannot_undercut_payment_retries(repository, admin):
    with pytest.raises(ValueError, match="at least 7 days"):
        LapsedAccountReaper(repository, admin, erase_after=timedelta(days=6))


async def test_run_once_reaps(repository, admin):
    await paid_account(repository, "lapsed", suspended_at=NOW - timedelta(days=31))

    await reaper_for(repository, admin).run_once()

    assert len(admin.calls) == 3
