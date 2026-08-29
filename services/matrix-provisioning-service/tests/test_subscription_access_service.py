"""Tests for reversible Matrix enforcement at entitlement boundaries."""

# ruff: noqa: S106 - explicit non-production credential fixtures

from __future__ import annotations

from datetime import datetime, timedelta, timezone
from types import SimpleNamespace

import pytest
from src.core.exceptions import BundleClaimConflictException
from src.core.subscriptions import (
    AcknowledgementState,
    EntitlementState,
    GoogleSubscriptionState,
    VerifiedSubscription,
)
from src.services.subscription_access_service import SubscriptionAccessService
from src.services.subscription_repository import SubscriptionRepository

pytestmark = pytest.mark.anyio

NOW = datetime(2026, 8, 29, 12, tzinfo=timezone.utc)


class FakeAdminClient:
    def __init__(self, *, suspended=False):
        self.suspended = suspended
        self.changes = []
        self.failure = None
        self.activity_calls = 0

    async def get_user_activity(self, _user_mxid):
        self.activity_calls += 1
        if self.failure:
            raise self.failure
        return SimpleNamespace(suspended=self.suspended)

    async def set_user_suspended(self, user_mxid, *, suspended):
        if self.failure:
            raise self.failure
        self.changes.append((user_mxid, suspended))
        self.suspended = suspended


async def setup_subscription(repository, *, state, period_end=None, with_bundle=True):
    await repository.create_entitlement(
        entitlement_id="entitlement-one",
        obfuscated_account_id="obfuscated-one",
        auth_secret_hash="auth-hash",
        now=NOW,
    )
    stored = await repository.store_verified_subscription(
        VerifiedSubscription(
            entitlement_id="entitlement-one",
            token_fingerprint="purchase-token",
            encrypted_purchase_token=b"encrypted-token",
            encryption_key_id="test-key",
            package_name="com.matthiasn.lotti",
            product_id="lotti_sync",
            base_plan_id="monthly",
            latest_order_id="GPA.1234",
            google_state=GoogleSubscriptionState.ACTIVE,
            entitlement_state=state,
            start_time=NOW,
            current_period_end=period_end,
            grace_deadline=None,
            acknowledgement_state=AcknowledgementState.ACKNOWLEDGED,
            binding_verified=True,
            last_verified_at=NOW,
            next_reconciliation_at=NOW + timedelta(hours=6),
        ),
        now=NOW,
    )
    if not with_bundle:
        return stored
    provisioning_token = "access-service-test"  # noqa: S105 - fixture lease token
    assert await repository.reserve_paid_bundle_provisioning(
        stored.entitlement_id,
        token_fingerprint=stored.token_fingerprint,
        operation_token=provisioning_token,
        now=NOW,
        stale_before=NOW - timedelta(minutes=5),
    )
    await repository.store_paid_bundle(
        token_fingerprint=stored.token_fingerprint,
        provisioning_token=provisioning_token,
        bundle_id="bundle-one",
        username="sync_one",
        user_mxid="@sync_one:example.com",
        home_server="https://matrix.example.com",
        server_name="example.com",
        room_id="!sync:example.com",
        display_name="Lotti SYNC",
        bundle_fingerprint="b" * 64,
        notes="Verified Google Play subscription",
        claim_secret_hash="claim-hash",
        encrypted_bundle=b"encrypted-bundle",
        encryption_key_id="test-key",
        expires_at=NOW + timedelta(hours=24),
        now=NOW,
    )
    return await repository.get_subscription_by_token(stored.token_fingerprint)


@pytest.fixture
def repository(tmp_path):
    return SubscriptionRepository(str(tmp_path / "subscriptions.db"))


@pytest.mark.parametrize(
    "state",
    [EntitlementState.SUSPENDED, EntitlementState.EXPIRED, EntitlementState.PENDING],
)
async def test_non_grantable_state_suspends_matrix_account(repository, state):
    subscription = await setup_subscription(repository, state=state)
    admin = FakeAdminClient(suspended=False)
    service = SubscriptionAccessService(repository, admin)

    desired = await service.enforce(subscription, now=NOW)

    assert desired is True
    assert admin.changes == [("@sync_one:example.com", True)]
    stored = await repository.get_subscription_by_token("purchase-token")
    assert stored.suspended_at == NOW
    assert stored.last_error is None


@pytest.mark.parametrize(
    "state",
    [EntitlementState.ACTIVE, EntitlementState.GRACE, EntitlementState.CANCELED_ACTIVE],
)
async def test_grantable_state_restores_suspended_matrix_account(repository, state):
    subscription = await setup_subscription(
        repository,
        state=state,
        period_end=NOW + timedelta(seconds=1),
    )
    admin = FakeAdminClient(suspended=True)
    service = SubscriptionAccessService(repository, admin)

    desired = await service.enforce(subscription, now=NOW)

    assert desired is False
    assert admin.changes == [("@sync_one:example.com", False)]
    stored = await repository.get_subscription_by_token("purchase-token")
    assert stored.unsuspended_at == NOW


async def test_access_is_suspended_exactly_at_authoritative_deadline(repository):
    subscription = await setup_subscription(
        repository,
        state=EntitlementState.GRACE,
        period_end=NOW,
    )
    admin = FakeAdminClient()
    service = SubscriptionAccessService(repository, admin)

    assert await service.enforce(subscription, now=NOW) is True
    assert admin.changes == [("@sync_one:example.com", True)]


async def test_unprovisioned_subscription_has_no_matrix_side_effect(repository):
    subscription = await setup_subscription(
        repository,
        state=EntitlementState.ACTIVE,
        with_bundle=False,
    )
    admin = FakeAdminClient()
    service = SubscriptionAccessService(repository, admin)

    assert await service.enforce(subscription, now=NOW) is None
    assert admin.changes == []


async def test_retired_entitlement_without_current_subscription_has_no_side_effect():
    subscription = SimpleNamespace(entitlement_id="retired-entitlement")

    class Repository:
        async def get_current_subscription(self, entitlement_id):
            assert entitlement_id == subscription.entitlement_id
            return None

    admin = FakeAdminClient()
    service = SubscriptionAccessService(Repository(), admin)

    assert await service.enforce(subscription, now=NOW) is None
    assert admin.activity_calls == 0


async def test_synapse_failure_is_recorded_and_propagated(repository):
    subscription = await setup_subscription(
        repository,
        state=EntitlementState.SUSPENDED,
    )
    admin = FakeAdminClient()
    admin.failure = RuntimeError("synapse unavailable")
    service = SubscriptionAccessService(repository, admin)

    with pytest.raises(RuntimeError, match="synapse unavailable"):
        await service.enforce(subscription, now=NOW)

    stored = await repository.get_subscription_by_token("purchase-token")
    assert stored.last_error == "synapse unavailable"


async def test_subscription_with_dangling_bundle_reference_fails_closed():
    class Repository:
        async def get_current_subscription(self, entitlement_id):
            assert entitlement_id == "entitlement-one"
            return subscription

        async def get(self, bundle_id):
            assert bundle_id == "missing-bundle"
            return None

    service = SubscriptionAccessService(Repository(), FakeAdminClient())
    subscription = SimpleNamespace(
        entitlement_id="entitlement-one",
        bundle_id="missing-bundle",
    )

    with pytest.raises(BundleClaimConflictException, match="missing Matrix bundle"):
        await service.enforce(subscription, now=NOW)


async def test_stale_predecessor_enforces_current_replacement(repository):
    predecessor = await setup_subscription(
        repository,
        state=EntitlementState.EXPIRED,
    )
    await repository.store_verified_subscription(
        VerifiedSubscription(
            entitlement_id="entitlement-one",
            token_fingerprint="replacement-token",
            encrypted_purchase_token=b"replacement-token",
            encryption_key_id="test-key",
            package_name="com.matthiasn.lotti",
            product_id="lotti_sync",
            base_plan_id="annual",
            latest_order_id="GPA.5678",
            google_state=GoogleSubscriptionState.ACTIVE,
            entitlement_state=EntitlementState.ACTIVE,
            start_time=NOW,
            current_period_end=NOW + timedelta(days=365),
            grace_deadline=None,
            acknowledgement_state=AcknowledgementState.ACKNOWLEDGED,
            binding_verified=True,
            last_verified_at=NOW,
            next_reconciliation_at=NOW + timedelta(hours=6),
            linked_token_fingerprint=predecessor.token_fingerprint,
        ),
        now=NOW,
    )
    admin = FakeAdminClient(suspended=True)
    service = SubscriptionAccessService(repository, admin)

    assert await service.enforce(predecessor, now=NOW) is False
    assert admin.changes == [("@sync_one:example.com", False)]
    assert admin.suspended is False
