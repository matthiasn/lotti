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
    _, claim = await repository.store_paid_bundle(
        token_fingerprint=token,
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


async def test_missing_account_still_destroys_expired_escrow():
    claim = type("Claim", (), {"bundle_id": "missing-bundle"})()

    class Repository:
        def __init__(self):
            self.abandoned = []

        async def list_expired_bundle_claims(self, now, *, limit):
            assert (now, limit) == (NOW, 50)
            return [claim]

        async def get(self, bundle_id):
            assert bundle_id == claim.bundle_id
            return None

        async def abandon_bundle_claim(self, bundle_id, *, now):
            self.abandoned.append((bundle_id, now))

    repository = Repository()
    reaper = BundleClaimReaper(repository, FakeAdminClient(), now_provider=lambda: NOW)

    await reaper.run_once()

    assert repository.abandoned == [(claim.bundle_id, NOW)]
