"""Tests for the lapsed-account erasure ledger."""

from __future__ import annotations

from datetime import timedelta

import pytest
from src.core.models import BundleStatus
from src.services.account_erasure_repository import AccountErasureRepository
from tests.erasure_fixtures import NOW, paid_account

pytestmark = pytest.mark.anyio

CUTOFF = NOW - timedelta(days=30)


@pytest.fixture
def repository(tmp_path):
    return AccountErasureRepository(str(tmp_path / "erasure.db"))


async def test_claiming_revokes_detaches_and_opens_a_ledger_entry(repository):
    user = await paid_account(repository, "lapsed", suspended_at=NOW - timedelta(days=31))

    assert await repository.claim_erasure(user.bundle_id, suspended_before=CUTOFF, now=NOW)

    assert (await repository.get(user.bundle_id)).status is BundleStatus.REVOKED
    current = await repository.get_current_subscription("entitlement-lapsed")
    # Nothing left for enforcement to unsuspend.
    assert current.bundle_id is None
    [erasure] = await repository.list_open_erasures(limit=10)
    assert (erasure.bundle_id, erasure.user_mxid, erasure.started_at) == (
        user.bundle_id,
        user.user_mxid,
        NOW,
    )
    assert erasure.media_deleted_at is None


@pytest.mark.parametrize(
    "state",
    [
        {"suspended_at": NOW - timedelta(days=29)},
        {"suspended_at": NOW - timedelta(days=60), "unsuspended_at": NOW - timedelta(days=1)},
        {},
    ],
)
async def test_an_account_that_renewed_or_is_too_recent_is_not_claimed(repository, state):
    user = await paid_account(repository, "kept", **state)

    assert not await repository.claim_erasure(user.bundle_id, suspended_before=CUTOFF, now=NOW)
    assert (await repository.get(user.bundle_id)).status is not BundleStatus.REVOKED
    assert await repository.list_open_erasures(limit=10) == []


async def test_an_account_is_claimed_once(repository):
    user = await paid_account(repository, "lapsed", suspended_at=NOW - timedelta(days=31))

    assert await repository.claim_erasure(user.bundle_id, suspended_before=CUTOFF, now=NOW)
    assert not await repository.claim_erasure(user.bundle_id, suspended_before=CUTOFF, now=NOW)


async def test_repeated_enforcement_keeps_the_first_suspension_time(repository):
    user = await paid_account(repository, "lapsed", suspended_at=NOW - timedelta(days=31))
    # The reconciler re-enforces suspension every few minutes.
    await repository.record_subscription_enforcement(
        "fp-lapsed", suspended=True, now=NOW - timedelta(minutes=5)
    )

    current = await repository.get_current_subscription("entitlement-lapsed")
    assert current.suspended_at == NOW - timedelta(days=31)
    assert [
        u.bundle_id
        for u in await repository.list_lapsed_accounts(suspended_before=CUTOFF, limit=10)
    ] == [user.bundle_id]


async def test_steps_and_errors_are_recorded(repository):
    user = await paid_account(repository, "lapsed", suspended_at=NOW - timedelta(days=31))
    await repository.claim_erasure(user.bundle_id, suspended_before=CUTOFF, now=NOW)

    await repository.record_erasure_error(user.bundle_id, "synapse down")
    [failed] = await repository.list_open_erasures(limit=10)
    assert failed.last_error == "synapse down"

    await repository.record_erasure_step(user.bundle_id, "media_deleted_at", now=NOW)
    [stepped] = await repository.list_open_erasures(limit=10)
    assert stepped.media_deleted_at == NOW
    assert stepped.last_error is None

    with pytest.raises(ValueError, match="Unknown erasure step"):
        await repository.record_erasure_step(user.bundle_id, "status; DROP TABLE x", now=NOW)


async def test_completion_frees_the_entitlement_for_a_fresh_account(repository):
    user = await paid_account(repository, "lapsed", suspended_at=NOW - timedelta(days=31))
    await repository.claim_erasure(user.bundle_id, suspended_before=CUTOFF, now=NOW)
    assert await repository.get_bundle_claim_for_entitlement("entitlement-lapsed") is not None

    await repository.complete_erasure(user.bundle_id, now=NOW)

    assert await repository.list_open_erasures(limit=10) == []
    # A later payment on this entitlement provisions a new account rather
    # than meeting a terminal claim.
    assert await repository.get_bundle_claim_for_entitlement("entitlement-lapsed") is None


async def test_a_failed_claim_leaves_the_account_untouched(repository, monkeypatch):
    user = await paid_account(repository, "lapsed", suspended_at=NOW - timedelta(days=31))

    def explode(*args, **kwargs):
        raise RuntimeError("disk full")

    monkeypatch.setattr(repository, "_record_event_sync", explode)

    with pytest.raises(RuntimeError, match="disk full"):
        await repository.claim_erasure(user.bundle_id, suspended_before=CUTOFF, now=NOW)

    assert (await repository.get(user.bundle_id)).status is not BundleStatus.REVOKED
    current = await repository.get_current_subscription("entitlement-lapsed")
    assert current.bundle_id == user.bundle_id
    assert await repository.list_open_erasures(limit=10) == []


async def test_a_failed_completion_keeps_the_erasure_open(repository):
    user = await paid_account(repository, "lapsed", suspended_at=NOW - timedelta(days=31))
    await repository.claim_erasure(user.bundle_id, suspended_before=CUTOFF, now=NOW)
    conn = repository._connect()
    try:
        conn.execute(
            "CREATE TRIGGER refuse_claim_delete BEFORE DELETE ON bundle_claims "
            "BEGIN SELECT RAISE(ABORT, 'locked'); END"
        )
        conn.commit()
    finally:
        conn.close()

    with pytest.raises(Exception, match="locked"):
        await repository.complete_erasure(user.bundle_id, now=NOW)

    # Not completed, so the next run tries again.
    assert [e.bundle_id for e in await repository.list_open_erasures(limit=10)] == [user.bundle_id]
