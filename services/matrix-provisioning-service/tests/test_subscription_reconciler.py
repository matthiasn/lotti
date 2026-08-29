"""Tests for missed-RTDN recovery and per-token failure isolation."""

from __future__ import annotations

from datetime import datetime, timedelta, timezone

import pytest
from src.core.subscriptions import (
    AcknowledgementState,
    EntitlementState,
    GoogleSubscriptionState,
    VerifiedSubscription,
)
from src.services.secret_cipher import SecretCipher
from src.services.subscription_reconciler import SubscriptionReconciler
from src.services.subscription_repository import SubscriptionRepository
from src.services.subscription_security import fingerprint


pytestmark = pytest.mark.anyio

NOW = datetime(2026, 8, 29, 12, tzinfo=timezone.utc)


class FakeSubscriptionService:
    def __init__(self):
        self.calls = []
        self.failure_tokens = set()

    async def refresh_known_purchase(self, token, *, now):
        self.calls.append((token, now))
        if token in self.failure_tokens:
            raise RuntimeError(f"cannot refresh {token}")
        return token


class FakeAccessService:
    def __init__(self):
        self.calls = []
        self.failure = None

    async def enforce(self, subscription, *, now):
        self.calls.append((subscription, now))
        if self.failure:
            raise self.failure


async def add_due(repository, cipher, entitlement_id, token, **overrides):
    await repository.create_entitlement(
        entitlement_id=entitlement_id,
        obfuscated_account_id=f"obfuscated-{entitlement_id}",
        auth_secret_hash="auth-hash",
        now=NOW,
    )
    token_hash = fingerprint(token)
    values = {
        "entitlement_id": entitlement_id,
        "token_fingerprint": token_hash,
        "encrypted_purchase_token": cipher.encrypt(
            token.encode(), purpose="purchase-token", record_id=token_hash
        ),
        "encryption_key_id": cipher.key_id,
        "package_name": "com.matthiasn.lotti",
        "product_id": "lotti_sync",
        "base_plan_id": "monthly",
        "latest_order_id": "GPA.1234",
        "google_state": GoogleSubscriptionState.ACTIVE,
        "entitlement_state": EntitlementState.ACTIVE,
        "start_time": NOW,
        "current_period_end": NOW + timedelta(days=30),
        "grace_deadline": None,
        "acknowledgement_state": AcknowledgementState.ACKNOWLEDGED,
        "binding_verified": True,
        "last_verified_at": NOW - timedelta(hours=1),
        "next_reconciliation_at": NOW,
    }
    values.update(overrides)
    return await repository.store_verified_subscription(
        VerifiedSubscription(**values),
        now=NOW - timedelta(hours=1),
    )


@pytest.fixture
def setup(tmp_path):
    repository = SubscriptionRepository(str(tmp_path / "subscriptions.db"))
    cipher = SecretCipher(key_id="key-v1", key=bytes(range(32)))
    subscriptions = FakeSubscriptionService()
    access = FakeAccessService()
    reconciler = SubscriptionReconciler(
        repository,
        subscriptions,
        access,
        cipher,
        now_provider=lambda: NOW,
    )
    return repository, cipher, subscriptions, access, reconciler


async def test_due_encrypted_token_is_refreshed_then_enforced(setup):
    repository, cipher, subscriptions, access, reconciler = setup
    await add_due(repository, cipher, "entitlement-one", "raw-purchase-token")

    count = await reconciler.reconcile_once()

    assert count == 1
    assert subscriptions.calls == [("raw-purchase-token", NOW)]
    assert access.calls == [("raw-purchase-token", NOW)]


async def test_one_failed_token_does_not_block_rest_of_batch(setup):
    repository, cipher, subscriptions, access, reconciler = setup
    failed = await add_due(repository, cipher, "entitlement-one", "failed-token")
    await add_due(repository, cipher, "entitlement-two", "healthy-token")
    subscriptions.failure_tokens.add("failed-token")

    count = await reconciler.reconcile_once()

    assert count == 1
    assert ("healthy-token", NOW) in subscriptions.calls
    assert (failed, NOW) in access.calls
    assert ("healthy-token", NOW) in access.calls
    failed_after = await repository.get_subscription_by_token(failed.token_fingerprint)
    assert failed_after.last_error == "cannot refresh failed-token"


async def test_unknown_encryption_key_is_recorded_without_decrypting(setup):
    repository, cipher, subscriptions, access, reconciler = setup
    stored = await add_due(
        repository,
        cipher,
        "entitlement-one",
        "raw-purchase-token",
        encryption_key_id="retired-key",
    )

    assert await reconciler.reconcile_once() == 0

    failed = await repository.get_subscription_by_token(stored.token_fingerprint)
    assert "retired-key" in failed.last_error
    assert subscriptions.calls == []
    assert access.calls == [(stored, NOW)]


async def test_future_subscription_is_not_reconciled(setup):
    repository, cipher, subscriptions, access, reconciler = setup
    await add_due(
        repository,
        cipher,
        "entitlement-one",
        "future-token",
        next_reconciliation_at=NOW + timedelta(microseconds=1),
    )

    assert await reconciler.reconcile_once() == 0
    assert subscriptions.calls == []


async def test_periodic_entrypoint_runs_one_reconciliation_batch(setup):
    repository, cipher, subscriptions, access, reconciler = setup
    await add_due(repository, cipher, "entitlement-one", "raw-purchase-token")

    await reconciler.run_once()

    assert subscriptions.calls == [("raw-purchase-token", NOW)]
    assert access.calls == [("raw-purchase-token", NOW)]


async def test_refresh_and_stored_state_enforcement_failures_are_both_recorded(setup):
    repository, cipher, subscriptions, access, reconciler = setup
    stored = await add_due(repository, cipher, "entitlement-one", "failed-token")
    subscriptions.failure_tokens.add("failed-token")
    access.failure = RuntimeError("synapse unavailable")

    assert await reconciler.reconcile_once() == 0

    failed = await repository.get_subscription_by_token(stored.token_fingerprint)
    assert failed.last_error == (
        "cannot refresh failed-token; stored-state enforcement failed: synapse unavailable"
    )
