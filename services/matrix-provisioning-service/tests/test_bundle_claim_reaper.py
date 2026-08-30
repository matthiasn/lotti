"""Tests for cleanup of abandoned paid provisioning credentials."""

# ruff: noqa: S106 - explicit non-production credential fixtures

from __future__ import annotations

from datetime import datetime, timedelta, timezone

import pytest
from src.core.subscriptions import (
    AcknowledgementState,
    EntitlementState,
    GoogleSubscriptionState,
    VerifiedSubscription,
)
from src.services.bundle_claim_reaper import BundleClaimReaper
from src.services.subscription_repository import SubscriptionRepository

pytestmark = pytest.mark.anyio

NOW = datetime(2026, 8, 29, 12, tzinfo=timezone.utc)


class FakeAdminClient:
    def __init__(self):
        self.deactivated = []
        self.failure = None

    async def deactivate_user(self, user_mxid):
        if self.failure:
            raise self.failure
        self.deactivated.append(user_mxid)


def test_destructive_reaper_delays_its_first_run():
    reaper = BundleClaimReaper(object(), FakeAdminClient())

    assert reaper._startup_delay_seconds == 60


async def setup_claim(repository, suffix, expires_at):
    entitlement_id = f"entitlement-{suffix}"
    token = f"token-{suffix}"
    await repository.create_entitlement(
        entitlement_id=entitlement_id,
        obfuscated_account_id=f"obfuscated-{suffix}",
        auth_secret_hash="auth-hash",
        now=NOW - timedelta(days=1),
    )
    await repository.store_verified_subscription(
        VerifiedSubscription(
            entitlement_id=entitlement_id,
            token_fingerprint=token,
            encrypted_purchase_token=b"encrypted-token",
            encryption_key_id="key-v1",
            package_name="com.matthiasn.lotti",
            product_id="lotti_sync",
            base_plan_id="monthly",
            latest_order_id="GPA.1234",
            google_state=GoogleSubscriptionState.ACTIVE,
            entitlement_state=EntitlementState.ACTIVE,
            start_time=NOW - timedelta(days=1),
            current_period_end=NOW + timedelta(days=29),
            grace_deadline=None,
            acknowledgement_state=AcknowledgementState.ACKNOWLEDGED,
            binding_verified=True,
            last_verified_at=NOW,
            next_reconciliation_at=NOW + timedelta(hours=6),
        ),
        now=NOW - timedelta(days=1),
    )
    provisioning_token = f"reaper-test-{suffix}"
    assert await repository.reserve_paid_bundle_provisioning(
        entitlement_id,
        token_fingerprint=token,
        operation_token=provisioning_token,
        now=NOW - timedelta(days=1),
        stale_before=NOW - timedelta(days=1, minutes=5),
    )
    _, claim = await repository.store_paid_bundle(
        token_fingerprint=token,
        provisioning_token=provisioning_token,
        bundle_id=f"bundle-{suffix}",
        username=f"sync_{suffix}",
        user_mxid=f"@sync_{suffix}:example.com",
        home_server="https://matrix.example.com",
        server_name="example.com",
        room_id=f"!room_{suffix}:example.com",
        display_name="Lotti SYNC",
        bundle_fingerprint="b" * 64,
        notes="Verified Google Play subscription",
        claim_secret_hash="claim-hash",
        encrypted_bundle=b"encrypted-bundle",
        encryption_key_id="key-v1",
        expires_at=expires_at,
        now=NOW - timedelta(days=1),
    )
    return entitlement_id, claim


@pytest.fixture
def setup(tmp_path):
    repository = SubscriptionRepository(str(tmp_path / "subscriptions.db"))
    admin = FakeAdminClient()
    reaper = BundleClaimReaper(
        repository,
        admin,
        now_provider=lambda: NOW,
    )
    return repository, admin, reaper


async def test_expired_claim_deactivates_revokes_and_destroys_escrow(setup):
    repository, admin, reaper = setup
    entitlement_id, claim = await setup_claim(repository, "expired", NOW)

    assert await reaper.reap_once() == 1

    user = await repository.get(claim.bundle_id)
    destroyed = await repository.get_bundle_claim_for_entitlement(entitlement_id)
    assert admin.deactivated == ["@sync_expired:example.com"]
    assert user.status.value == "revoked"
    assert destroyed.encrypted_bundle is None
    assert destroyed.confirmed_at is None
    assert destroyed.destroyed_at == NOW
    assert destroyed.abandoned_at == NOW


async def test_future_claim_is_not_touched(setup):
    repository, admin, reaper = setup
    _, claim = await setup_claim(repository, "future", NOW + timedelta(microseconds=1))

    assert await reaper.reap_once() == 0

    assert admin.deactivated == []
    assert (await repository.get(claim.bundle_id)).status.value == "unused"


async def test_synapse_failure_leaves_claim_for_next_retry(setup):
    repository, admin, reaper = setup
    entitlement_id, claim = await setup_claim(repository, "failed", NOW)
    admin.failure = RuntimeError("synapse unavailable")

    assert await reaper.reap_once() == 0

    stored = await repository.get_bundle_claim_for_entitlement(entitlement_id)
    assert stored.encrypted_bundle is not None
    assert (await repository.get(claim.bundle_id)).status.value == "unused"
    assert (
        await repository.list_expired_bundle_claims(
            NOW,
            stale_before=NOW - timedelta(minutes=5),
            limit=50,
        )
        == []
    )
    assert await repository.list_expired_bundle_claims(
        NOW + timedelta(minutes=5),
        stale_before=NOW,
        limit=50,
    ) == [stored]


async def test_failed_batch_head_is_rescheduled_so_later_claim_is_reaped(tmp_path):
    repository = SubscriptionRepository(str(tmp_path / "subscriptions.db"))
    _, failed = await setup_claim(
        repository,
        "failed",
        NOW - timedelta(minutes=1),
    )
    _, healthy = await setup_claim(repository, "healthy", NOW)

    class SelectiveAdmin(FakeAdminClient):
        async def deactivate_user(self, user_mxid):
            if user_mxid == "@sync_failed:example.com":
                raise RuntimeError("permanent failure")
            await super().deactivate_user(user_mxid)

    reaper = BundleClaimReaper(
        repository,
        SelectiveAdmin(),
        batch_size=1,
        now_provider=lambda: NOW,
    )

    assert await reaper.reap_once() == 0
    assert await reaper.reap_once() == 1
    assert (await repository.get(failed.bundle_id)).status.value == "unused"
    assert (await repository.get(healthy.bundle_id)).status.value == "revoked"


async def test_missing_account_still_destroys_expired_escrow():
    claim = type("Claim", (), {"bundle_id": "missing-bundle"})()

    class Repository:
        def __init__(self):
            self.abandoned = []

        async def list_expired_bundle_claims(self, now, *, stale_before, limit):
            assert (now, limit) == (NOW, 50)
            assert stale_before == NOW - timedelta(minutes=5)
            return [claim]

        async def reserve_bundle_reap(
            self,
            bundle_id,
            *,
            operation_token,
            now,
            stale_before,
        ):
            assert bundle_id == claim.bundle_id
            assert operation_token
            assert now == NOW
            assert stale_before == NOW - timedelta(minutes=5)
            return True

        async def get(self, bundle_id):
            assert bundle_id == claim.bundle_id
            return None

        async def abandon_bundle_claim(self, bundle_id, *, now, operation_token):
            self.abandoned.append((bundle_id, now, operation_token))

        async def reschedule_bundle_claim_reap(
            self,
            bundle_id,
            *,
            next_reap_at,
            operation_token,
        ):
            raise AssertionError("successful claims are not rescheduled")

    repository = Repository()
    reaper = BundleClaimReaper(repository, FakeAdminClient(), now_provider=lambda: NOW)

    await reaper.run_once()

    assert len(repository.abandoned) == 1
    assert repository.abandoned[0][:2] == (claim.bundle_id, NOW)
    assert repository.abandoned[0][2]


async def test_claim_reserved_by_another_worker_is_skipped():
    claim = type("Claim", (), {"bundle_id": "leased-bundle"})()

    class Repository:
        async def list_expired_bundle_claims(self, now, *, stale_before, limit):
            return [claim]

        async def reserve_bundle_reap(self, bundle_id, **_kwargs):
            assert bundle_id == claim.bundle_id
            return False

        async def get(self, _bundle_id):
            raise AssertionError("an unreserved claim must not reach Matrix lookup")

    admin = FakeAdminClient()
    reaper = BundleClaimReaper(Repository(), admin, now_provider=lambda: NOW)

    assert await reaper.reap_once() == 0
    assert admin.deactivated == []
