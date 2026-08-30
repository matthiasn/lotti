"""Tests for durable Google Play entitlement and token ownership state."""

# ruff: noqa: S105,S106 - explicit non-production token and secret fixtures

from __future__ import annotations

import sqlite3
from dataclasses import replace
from datetime import datetime, timedelta, timezone

import pytest
from src.core.exceptions import (
    BundleClaimConflictException,
    InvalidBundleStateException,
    PurchaseIntentExpiredException,
    PurchaseIntentNotFoundException,
    PurchaseIntentReplayException,
    PurchaseTokenConflictException,
    SubscriptionLineageException,
)
from src.core.models import BundleStatus
from src.core.subscriptions import (
    AcknowledgementState,
    EntitlementState,
    GoogleSubscriptionState,
    VerifiedSubscription,
)
from src.services.subscription_repository import (
    ATTEMPT_KIND_PURCHASE_INTENT,
    ATTEMPT_KIND_PURCHASE_VERIFICATION,
    SubscriptionRepository,
)
from tests.conftest import seed_user

pytestmark = pytest.mark.anyio

NOW = datetime(2026, 8, 29, 12, tzinfo=timezone.utc)


@pytest.fixture
def subscription_repository(tmp_path):
    return SubscriptionRepository(str(tmp_path / "subscriptions.db"))


def test_existing_bundle_claim_schema_is_migrated(tmp_path):
    db_path = tmp_path / "legacy.db"
    connection = sqlite3.connect(db_path)
    connection.execute(
        "CREATE TABLE bundle_claims ("
        "bundle_id TEXT PRIMARY KEY, subscription_id TEXT NOT NULL UNIQUE, "
        "claim_secret_hash TEXT NOT NULL, encrypted_bundle BLOB, "
        "encryption_key_id TEXT NOT NULL, expires_at TEXT NOT NULL, "
        "first_delivered_at TEXT, confirmed_at TEXT, destroyed_at TEXT, "
        "created_at TEXT NOT NULL)"
    )
    connection.commit()
    connection.close()

    SubscriptionRepository(str(db_path))

    connection = sqlite3.connect(db_path)
    columns = {row[1] for row in connection.execute("PRAGMA table_info(bundle_claims)")}
    connection.close()
    assert {
        "next_reap_at",
        "operation_token",
        "operation_kind",
        "operation_started_at",
        "authorized_token_fingerprint",
        "abandoned_at",
    } <= columns


def test_existing_subscription_schema_is_migrated_with_matrix_state(tmp_path):
    db_path = tmp_path / "legacy-subscriptions.db"
    SubscriptionRepository(str(db_path))
    connection = sqlite3.connect(db_path)
    connection.execute("ALTER TABLE play_subscriptions DROP COLUMN matrix_suspended")
    connection.commit()
    connection.close()

    SubscriptionRepository(str(db_path))

    connection = sqlite3.connect(db_path)
    columns = {row[1] for row in connection.execute("PRAGMA table_info(play_subscriptions)")}
    connection.close()
    assert "matrix_suspended" in columns


def verified_subscription(
    entitlement_id: str,
    token_fingerprint: str,
    **overrides,
) -> VerifiedSubscription:
    values = {
        "entitlement_id": entitlement_id,
        "token_fingerprint": token_fingerprint,
        "encrypted_purchase_token": b"encrypted-token",
        "encryption_key_id": "test-key-v1",
        "package_name": "com.matthiasn.lotti",
        "product_id": "lotti_sync",
        "base_plan_id": "monthly",
        "latest_order_id": "GPA.1234",
        "google_state": GoogleSubscriptionState.ACTIVE,
        "entitlement_state": EntitlementState.ACTIVE,
        "start_time": NOW - timedelta(days=1),
        "current_period_end": NOW + timedelta(days=29),
        "grace_deadline": None,
        "acknowledgement_state": AcknowledgementState.PENDING,
        "binding_verified": True,
        "last_verified_at": NOW,
        "next_reconciliation_at": NOW + timedelta(hours=6),
    }
    values.update(overrides)
    return VerifiedSubscription(**values)


async def create_entitlement(repository, suffix="one"):
    return await repository.create_entitlement(
        entitlement_id=f"entitlement-{suffix}",
        obfuscated_account_id=f"obfuscated-{suffix}",
        auth_secret_hash=f"secret-hash-{suffix}",
        now=NOW,
    )


async def test_entitlement_stores_only_the_auth_secret_hash(subscription_repository):
    created = await create_entitlement(subscription_repository)

    loaded = await subscription_repository.get_entitlement(created.entitlement_id)

    assert loaded == created
    assert loaded.auth_secret_hash == "secret-hash-one"


async def test_obfuscated_account_id_cannot_identify_two_entitlements(
    subscription_repository,
):
    await create_entitlement(subscription_repository)

    with pytest.raises(PurchaseTokenConflictException):
        await subscription_repository.create_entitlement(
            entitlement_id="entitlement-two",
            obfuscated_account_id="obfuscated-one",
            auth_secret_hash="different-hash",
            now=NOW,
        )


async def create_intent(repository, entitlement, suffix="one", **overrides):
    values = {
        "intent_id": f"intent-{suffix}",
        "entitlement_id": entitlement.entitlement_id,
        "intent_secret_hash": f"intent-secret-hash-{suffix}",
        "product_id": "lotti_sync",
        "base_plan_id": "monthly",
        "obfuscated_account_id": entitlement.obfuscated_account_id,
        "expires_at": NOW + timedelta(minutes=15),
        "now": NOW,
    }
    values.update(overrides)
    return await repository.create_purchase_intent(**values)


async def test_purchase_intent_starts_unconsumed_and_bound_to_billing_fields(
    subscription_repository,
):
    entitlement = await create_entitlement(subscription_repository)

    intent = await create_intent(subscription_repository, entitlement)

    assert intent.entitlement_id == entitlement.entitlement_id
    assert intent.intent_secret_hash == "intent-secret-hash-one"
    assert intent.product_id == "lotti_sync"
    assert intent.base_plan_id == "monthly"
    assert intent.obfuscated_account_id == entitlement.obfuscated_account_id
    assert intent.consumed_at is None


async def test_purchase_intent_quota_rolls_back_and_closes_on_database_failure(
    subscription_repository,
    monkeypatch,
):
    class FailingConnection:
        def __init__(self):
            self.rollback_called = False
            self.close_called = False
            self.execute_count = 0

        def execute(self, _query, _parameters=()):
            self.execute_count += 1
            if self.execute_count > 1:
                raise sqlite3.OperationalError("injected quota failure")

        def rollback(self):
            self.rollback_called = True

        def close(self):
            self.close_called = True

    connection = FailingConnection()
    monkeypatch.setattr(subscription_repository, "_connect", lambda: connection)

    with pytest.raises(sqlite3.OperationalError, match="injected quota failure"):
        await subscription_repository.consume_purchase_intent_issuance_quota(
            "entitlement-one",
            now=NOW,
            window=timedelta(minutes=15),
            max_requests=10,
        )

    assert connection.rollback_called is True
    assert connection.close_called is True


async def test_purchase_intent_attempt_quota_rolls_back_and_closes_on_database_failure(
    subscription_repository,
    monkeypatch,
):
    class FailingConnection:
        def __init__(self):
            self.rollback_called = False
            self.close_called = False

        def execute(self, _query, _parameters=()):
            raise sqlite3.OperationalError("injected attempt quota failure")

        def rollback(self):
            self.rollback_called = True

        def close(self):
            self.close_called = True

    connection = FailingConnection()
    monkeypatch.setattr(subscription_repository, "_connect", lambda: connection)

    with pytest.raises(sqlite3.OperationalError, match="injected attempt quota failure"):
        await subscription_repository.consume_subscription_attempt_quota(
            "entitlement-one",
            "purchase_intent",
            now=NOW,
            window=timedelta(minutes=15),
            max_requests=10,
        )

    assert connection.rollback_called is True
    assert connection.close_called is True


async def test_attempt_quota_cleanup_preserves_other_operation_windows(
    subscription_repository,
):
    entitlement = await create_entitlement(subscription_repository)

    assert (
        await subscription_repository.consume_subscription_attempt_quota(
            entitlement.entitlement_id,
            ATTEMPT_KIND_PURCHASE_VERIFICATION,
            now=NOW,
            window=timedelta(minutes=15),
            max_requests=1,
        )
        is None
    )

    assert (
        await subscription_repository.consume_subscription_attempt_quota(
            entitlement.entitlement_id,
            ATTEMPT_KIND_PURCHASE_INTENT,
            now=NOW + timedelta(minutes=2),
            window=timedelta(minutes=1),
            max_requests=1,
        )
        is None
    )

    retry_after = await subscription_repository.consume_subscription_attempt_quota(
        entitlement.entitlement_id,
        ATTEMPT_KIND_PURCHASE_VERIFICATION,
        now=NOW + timedelta(minutes=2),
        window=timedelta(minutes=15),
        max_requests=1,
    )

    assert retry_after == 13 * 60


async def test_duplicate_purchase_intent_id_is_rejected(subscription_repository):
    entitlement = await create_entitlement(subscription_repository)
    await create_intent(subscription_repository, entitlement)

    with pytest.raises(PurchaseTokenConflictException):
        await create_intent(subscription_repository, entitlement)


async def test_purchase_intent_consumption_is_idempotent_for_the_same_proofs(
    subscription_repository,
):
    entitlement = await create_entitlement(subscription_repository)
    intent = await create_intent(subscription_repository, entitlement)
    kwargs = {
        "intent_id": intent.intent_id,
        "entitlement_id": entitlement.entitlement_id,
        "expected_request_hash": "request-hash",
        "token_fingerprint": "purchase-token-hash",
        "integrity_token_fingerprint": "integrity-token-hash",
        "now": NOW + timedelta(minutes=1),
    }

    first = await subscription_repository.consume_purchase_intent(**kwargs)
    retry = await subscription_repository.consume_purchase_intent(
        **{**kwargs, "now": NOW + timedelta(minutes=2)}
    )

    assert retry == first
    assert retry.consumed_at == NOW + timedelta(minutes=1)


@pytest.mark.parametrize(
    ("changed_field", "changed_value"),
    [
        ("expected_request_hash", "other-request"),
        ("token_fingerprint", "other-purchase"),
    ],
)
async def test_purchase_intent_rejects_non_idempotent_replay(
    subscription_repository,
    changed_field,
    changed_value,
):
    entitlement = await create_entitlement(subscription_repository)
    intent = await create_intent(subscription_repository, entitlement)
    kwargs = {
        "intent_id": intent.intent_id,
        "entitlement_id": entitlement.entitlement_id,
        "expected_request_hash": "request-hash",
        "token_fingerprint": "purchase-token-hash",
        "integrity_token_fingerprint": "integrity-token-hash",
        "now": NOW + timedelta(minutes=1),
    }
    await subscription_repository.consume_purchase_intent(**kwargs)

    with pytest.raises(PurchaseIntentReplayException):
        await subscription_repository.consume_purchase_intent(
            **{
                **kwargs,
                changed_field: changed_value,
                "now": NOW + timedelta(minutes=2),
            }
        )


async def test_same_purchase_retry_accepts_a_fresh_integrity_token(
    subscription_repository,
):
    entitlement = await create_entitlement(subscription_repository)
    intent = await create_intent(subscription_repository, entitlement)
    kwargs = {
        "intent_id": intent.intent_id,
        "entitlement_id": entitlement.entitlement_id,
        "expected_request_hash": "request-hash",
        "token_fingerprint": "purchase-token-hash",
        "integrity_token_fingerprint": "first-integrity-token",
        "now": NOW + timedelta(minutes=1),
    }
    first = await subscription_repository.consume_purchase_intent(**kwargs)

    retry = await subscription_repository.consume_purchase_intent(
        **{
            **kwargs,
            "integrity_token_fingerprint": "fresh-integrity-token",
            "now": NOW + timedelta(minutes=2),
        }
    )

    assert retry.consumed_at == first.consumed_at
    assert retry.integrity_token_fingerprint == "fresh-integrity-token"


async def test_integrity_token_cannot_be_replayed_across_purchase_intents(
    subscription_repository,
):
    entitlement = await create_entitlement(subscription_repository)
    first = await create_intent(subscription_repository, entitlement, "one")
    second = await create_intent(subscription_repository, entitlement, "two")
    await subscription_repository.consume_purchase_intent(
        intent_id=first.intent_id,
        entitlement_id=entitlement.entitlement_id,
        expected_request_hash="first-request",
        token_fingerprint="first-purchase",
        integrity_token_fingerprint="replayed-integrity",
        now=NOW + timedelta(minutes=1),
    )

    with pytest.raises(PurchaseIntentReplayException):
        await subscription_repository.consume_purchase_intent(
            intent_id=second.intent_id,
            entitlement_id=entitlement.entitlement_id,
            expected_request_hash="second-request",
            token_fingerprint="second-purchase",
            integrity_token_fingerprint="replayed-integrity",
            now=NOW + timedelta(minutes=1),
        )


async def test_expired_purchase_intent_cannot_be_consumed(subscription_repository):
    entitlement = await create_entitlement(subscription_repository)
    intent = await create_intent(subscription_repository, entitlement)

    with pytest.raises(PurchaseIntentExpiredException):
        await subscription_repository.consume_purchase_intent(
            intent_id=intent.intent_id,
            entitlement_id=entitlement.entitlement_id,
            expected_request_hash="request-hash",
            token_fingerprint="purchase-token-hash",
            integrity_token_fingerprint="integrity-token-hash",
            now=intent.expires_at,
        )


async def test_purchase_intent_cannot_be_consumed_by_another_entitlement(
    subscription_repository,
):
    owner = await create_entitlement(subscription_repository, "owner")
    attacker = await create_entitlement(subscription_repository, "attacker")
    intent = await create_intent(subscription_repository, owner)

    with pytest.raises(PurchaseIntentNotFoundException):
        await subscription_repository.consume_purchase_intent(
            intent_id=intent.intent_id,
            entitlement_id=attacker.entitlement_id,
            expected_request_hash="request-hash",
            token_fingerprint="purchase-token-hash",
            integrity_token_fingerprint="integrity-token-hash",
            now=NOW + timedelta(minutes=1),
        )


async def test_verified_subscription_round_trips_security_and_state_fields(
    subscription_repository,
):
    entitlement = await create_entitlement(subscription_repository)
    snapshot = verified_subscription(entitlement.entitlement_id, "fingerprint-one")

    stored = await subscription_repository.store_verified_subscription(snapshot, now=NOW)
    loaded = await subscription_repository.get_subscription_by_token("fingerprint-one")

    assert loaded == stored
    assert loaded.encrypted_purchase_token == b"encrypted-token"
    assert loaded.google_state is GoogleSubscriptionState.ACTIVE
    assert loaded.entitlement_state is EntitlementState.ACTIVE
    assert loaded.is_current is True
    assert loaded.binding_verified is True


async def test_same_token_updates_in_place_for_idempotent_rtdn(subscription_repository):
    entitlement = await create_entitlement(subscription_repository)
    original = verified_subscription(entitlement.entitlement_id, "fingerprint-one")
    first = await subscription_repository.store_verified_subscription(original, now=NOW)
    renewed = replace(
        original,
        current_period_end=NOW + timedelta(days=60),
        acknowledgement_state=AcknowledgementState.ACKNOWLEDGED,
        last_verified_at=NOW + timedelta(minutes=1),
        next_reconciliation_at=NOW + timedelta(hours=12),
    )

    second = await subscription_repository.store_verified_subscription(
        renewed,
        now=NOW + timedelta(minutes=1),
    )

    assert second.subscription_id == first.subscription_id
    assert second.created_at == first.created_at
    assert second.updated_at == NOW + timedelta(minutes=1)
    assert second.current_period_end == NOW + timedelta(days=60)
    assert second.acknowledgement_state is AcknowledgementState.ACKNOWLEDGED


async def test_older_same_token_snapshot_cannot_overwrite_newer_google_state(
    subscription_repository,
):
    entitlement = await create_entitlement(subscription_repository)
    original = verified_subscription(entitlement.entitlement_id, "fingerprint-one")
    await subscription_repository.store_verified_subscription(original, now=NOW)
    newer = replace(
        original,
        google_state=GoogleSubscriptionState.ON_HOLD,
        entitlement_state=EntitlementState.SUSPENDED,
        last_verified_at=NOW + timedelta(minutes=2),
    )
    stored_newer = await subscription_repository.store_verified_subscription(
        newer,
        now=NOW + timedelta(minutes=2),
    )
    stale = replace(
        original,
        current_period_end=NOW + timedelta(days=60),
        last_verified_at=NOW + timedelta(minutes=1),
    )

    stale_result = await subscription_repository.store_verified_subscription(
        stale,
        now=NOW + timedelta(minutes=3),
    )

    persisted = await subscription_repository.get_subscription_by_token("fingerprint-one")
    assert stale_result == stored_newer
    assert persisted == stored_newer
    assert persisted.entitlement_state is EntitlementState.SUSPENDED
    assert persisted.updated_at == NOW + timedelta(minutes=2)


async def test_purchase_token_cannot_be_rebound_to_another_entitlement(
    subscription_repository,
):
    first_entitlement = await create_entitlement(subscription_repository, "one")
    second_entitlement = await create_entitlement(subscription_repository, "two")
    original = verified_subscription(first_entitlement.entitlement_id, "stolen-token")
    await subscription_repository.store_verified_subscription(original, now=NOW)

    with pytest.raises(PurchaseTokenConflictException):
        await subscription_repository.store_verified_subscription(
            replace(original, entitlement_id=second_entitlement.entitlement_id),
            now=NOW + timedelta(minutes=1),
        )

    loaded = await subscription_repository.get_subscription_by_token("stolen-token")
    assert loaded.entitlement_id == first_entitlement.entitlement_id


async def test_linked_token_retires_old_token_atomically(subscription_repository):
    entitlement = await create_entitlement(subscription_repository)
    old = verified_subscription(entitlement.entitlement_id, "old-token")
    await subscription_repository.store_verified_subscription(old, now=NOW)
    new = verified_subscription(
        entitlement.entitlement_id,
        "new-token",
        base_plan_id="annual",
        linked_token_fingerprint="old-token",
    )

    current = await subscription_repository.store_verified_subscription(
        new,
        now=NOW + timedelta(minutes=1),
    )
    retired = await subscription_repository.get_subscription_by_token("old-token")

    assert current.token_fingerprint == "new-token"
    assert current.is_current is True
    assert retired.is_current is False
    assert retired.replaced_by_token_fingerprint == "new-token"
    assert retired.retired_at == NOW + timedelta(minutes=1)
    assert (
        await subscription_repository.get_current_subscription(entitlement.entitlement_id)
        == current
    )


async def test_unknown_linked_token_does_not_retire_current_subscription(
    subscription_repository,
):
    entitlement = await create_entitlement(subscription_repository)
    old = verified_subscription(entitlement.entitlement_id, "old-token")
    await subscription_repository.store_verified_subscription(old, now=NOW)
    invalid = verified_subscription(
        entitlement.entitlement_id,
        "new-token",
        linked_token_fingerprint="unknown-token",
    )

    with pytest.raises(SubscriptionLineageException):
        await subscription_repository.store_verified_subscription(
            invalid,
            now=NOW + timedelta(minutes=1),
        )

    current = await subscription_repository.get_current_subscription(entitlement.entitlement_id)
    assert current.token_fingerprint == "old-token"
    assert current.is_current is True


async def test_unlinked_new_token_does_not_replace_current_subscription(
    subscription_repository,
):
    entitlement = await create_entitlement(subscription_repository)
    await subscription_repository.store_verified_subscription(
        verified_subscription(entitlement.entitlement_id, "old-token"),
        now=NOW,
    )

    with pytest.raises(SubscriptionLineageException):
        await subscription_repository.store_verified_subscription(
            verified_subscription(entitlement.entitlement_id, "unlinked-token"),
            now=NOW + timedelta(minutes=1),
        )

    current = await subscription_repository.get_current_subscription(entitlement.entitlement_id)
    assert current.token_fingerprint == "old-token"


async def test_delayed_replacement_cannot_retire_a_newer_current_token(
    subscription_repository,
):
    entitlement = await create_entitlement(subscription_repository)
    await subscription_repository.store_verified_subscription(
        verified_subscription(entitlement.entitlement_id, "old-token"),
        now=NOW,
    )
    await subscription_repository.store_verified_subscription(
        verified_subscription(
            entitlement.entitlement_id,
            "current-token",
            linked_token_fingerprint="old-token",
        ),
        now=NOW + timedelta(minutes=1),
    )

    with pytest.raises(SubscriptionLineageException):
        await subscription_repository.store_verified_subscription(
            verified_subscription(
                entitlement.entitlement_id,
                "delayed-token",
                linked_token_fingerprint="old-token",
            ),
            now=NOW + timedelta(minutes=2),
        )

    current = await subscription_repository.get_current_subscription(entitlement.entitlement_id)
    assert current.token_fingerprint == "current-token"


async def test_linked_token_owned_by_someone_else_is_rejected(subscription_repository):
    first = await create_entitlement(subscription_repository, "one")
    second = await create_entitlement(subscription_repository, "two")
    await subscription_repository.store_verified_subscription(
        verified_subscription(first.entitlement_id, "first-token"),
        now=NOW,
    )

    with pytest.raises(SubscriptionLineageException):
        await subscription_repository.store_verified_subscription(
            verified_subscription(
                second.entitlement_id,
                "second-token",
                linked_token_fingerprint="first-token",
            ),
            now=NOW + timedelta(minutes=1),
        )


async def test_due_reconciliation_excludes_retired_and_future_rows(
    subscription_repository,
):
    first = await create_entitlement(subscription_repository, "one")
    second = await create_entitlement(subscription_repository, "two")
    await subscription_repository.store_verified_subscription(
        verified_subscription(
            first.entitlement_id,
            "old-token",
            next_reconciliation_at=NOW - timedelta(minutes=1),
        ),
        now=NOW - timedelta(hours=1),
    )
    await subscription_repository.store_verified_subscription(
        verified_subscription(
            first.entitlement_id,
            "new-token",
            linked_token_fingerprint="old-token",
            next_reconciliation_at=NOW + timedelta(hours=1),
        ),
        now=NOW,
    )
    due = verified_subscription(
        second.entitlement_id,
        "due-token",
        next_reconciliation_at=NOW,
    )
    await subscription_repository.store_verified_subscription(due, now=NOW)

    rows = await subscription_repository.list_due_reconciliation(NOW, limit=10)

    assert [row.token_fingerprint for row in rows] == ["due-token"]


async def test_state_change_stays_due_until_matrix_enforcement_is_recorded(
    subscription_repository,
):
    entitlement = await create_entitlement(subscription_repository)
    snapshot = verified_subscription(entitlement.entitlement_id, "paid-token")
    await subscription_repository.store_verified_subscription(snapshot, now=NOW)
    await store_paid_bundle(subscription_repository, "paid-token")

    initially_pending = await subscription_repository.list_due_reconciliation(NOW, limit=10)

    assert [row.token_fingerprint for row in initially_pending] == ["paid-token"]

    await subscription_repository.record_subscription_enforcement(
        "paid-token",
        suspended=False,
        now=NOW,
    )
    assert await subscription_repository.list_due_reconciliation(NOW, limit=10) == []
    refresh_time = NOW + timedelta(minutes=1)
    await subscription_repository.store_verified_subscription(
        replace(
            snapshot,
            google_state=GoogleSubscriptionState.ON_HOLD,
            entitlement_state=EntitlementState.SUSPENDED,
            last_verified_at=refresh_time,
            next_reconciliation_at=refresh_time + timedelta(hours=6),
        ),
        now=refresh_time,
    )

    pending = await subscription_repository.list_due_reconciliation(refresh_time, limit=10)

    assert [row.token_fingerprint for row in pending] == ["paid-token"]

    await subscription_repository.record_subscription_enforcement(
        "paid-token",
        suspended=True,
        now=refresh_time,
    )

    assert await subscription_repository.list_due_reconciliation(refresh_time, limit=10) == []


async def test_elapsed_access_deadline_becomes_due_before_next_google_refresh(
    subscription_repository,
):
    entitlement = await create_entitlement(subscription_repository)
    deadline = NOW + timedelta(minutes=1)
    await subscription_repository.store_verified_subscription(
        verified_subscription(
            entitlement.entitlement_id,
            "paid-token",
            current_period_end=deadline,
            next_reconciliation_at=NOW + timedelta(hours=6),
        ),
        now=NOW,
    )
    await store_paid_bundle(subscription_repository, "paid-token")
    await subscription_repository.record_subscription_enforcement(
        "paid-token",
        suspended=False,
        now=NOW,
    )

    assert await subscription_repository.list_due_reconciliation(NOW, limit=10) == []

    due = await subscription_repository.list_due_reconciliation(deadline, limit=10)

    assert [row.token_fingerprint for row in due] == ["paid-token"]


async def test_pending_matrix_enforcement_precedes_scheduled_google_refresh(
    subscription_repository,
):
    pending_entitlement = await create_entitlement(subscription_repository, "pending")
    pending_snapshot = verified_subscription(
        pending_entitlement.entitlement_id,
        "pending-token",
    )
    await subscription_repository.store_verified_subscription(pending_snapshot, now=NOW)
    await store_paid_bundle(
        subscription_repository,
        "pending-token",
        bundle_id="pending-bundle",
    )
    await subscription_repository.record_subscription_enforcement(
        "pending-token",
        suspended=False,
        now=NOW,
    )
    refresh_time = NOW + timedelta(minutes=1)
    await subscription_repository.store_verified_subscription(
        replace(
            pending_snapshot,
            google_state=GoogleSubscriptionState.ON_HOLD,
            entitlement_state=EntitlementState.SUSPENDED,
            last_verified_at=refresh_time,
            next_reconciliation_at=refresh_time + timedelta(hours=6),
        ),
        now=refresh_time,
    )
    scheduled_entitlement = await create_entitlement(subscription_repository, "scheduled")
    await subscription_repository.store_verified_subscription(
        verified_subscription(
            scheduled_entitlement.entitlement_id,
            "scheduled-token",
            next_reconciliation_at=refresh_time,
        ),
        now=refresh_time,
    )

    due = await subscription_repository.list_due_reconciliation(refresh_time, limit=1)

    assert [row.token_fingerprint for row in due] == ["pending-token"]


async def test_failed_matrix_enforcement_observes_retry_deadline_and_batch_fairness(
    subscription_repository,
):
    failed_entitlement = await create_entitlement(subscription_repository, "failed")
    failed_snapshot = verified_subscription(failed_entitlement.entitlement_id, "failed-token")
    await subscription_repository.store_verified_subscription(failed_snapshot, now=NOW)
    await store_paid_bundle(
        subscription_repository,
        "failed-token",
        bundle_id="failed-bundle",
    )
    await subscription_repository.record_subscription_enforcement(
        "failed-token",
        suspended=False,
        now=NOW,
    )
    failure_time = NOW + timedelta(minutes=1)
    retry_at = failure_time + timedelta(minutes=5)
    await subscription_repository.store_verified_subscription(
        replace(
            failed_snapshot,
            google_state=GoogleSubscriptionState.ON_HOLD,
            entitlement_state=EntitlementState.SUSPENDED,
            last_verified_at=failure_time,
            next_reconciliation_at=failure_time + timedelta(hours=6),
        ),
        now=failure_time,
    )
    await subscription_repository.record_subscription_error(
        "failed-token",
        last_error="synapse unavailable",
        now=failure_time,
        next_reconciliation_at=retry_at,
    )
    scheduled_entitlement = await create_entitlement(subscription_repository, "scheduled")
    await subscription_repository.store_verified_subscription(
        verified_subscription(
            scheduled_entitlement.entitlement_id,
            "scheduled-token",
            next_reconciliation_at=failure_time,
        ),
        now=failure_time,
    )

    due_during_backoff = await subscription_repository.list_due_reconciliation(
        failure_time,
        limit=1,
    )
    due_at_retry = await subscription_repository.list_due_reconciliation(retry_at, limit=10)

    assert [row.token_fingerprint for row in due_during_backoff] == ["scheduled-token"]
    assert {row.token_fingerprint for row in due_at_retry} == {
        "failed-token",
        "scheduled-token",
    }


async def test_stale_token_enforcement_records_actual_state_on_current_replacement(
    subscription_repository,
):
    entitlement = await create_entitlement(subscription_repository)
    original = verified_subscription(entitlement.entitlement_id, "old-token")
    await subscription_repository.store_verified_subscription(original, now=NOW)
    await store_paid_bundle(subscription_repository, "old-token")
    await subscription_repository.record_subscription_enforcement(
        "old-token",
        suspended=True,
        now=NOW,
    )
    replacement_time = NOW + timedelta(minutes=1)
    replacement = await subscription_repository.store_verified_subscription(
        verified_subscription(
            entitlement.entitlement_id,
            "new-token",
            google_state=GoogleSubscriptionState.ON_HOLD,
            entitlement_state=EntitlementState.SUSPENDED,
            linked_token_fingerprint="old-token",
            last_verified_at=replacement_time,
            next_reconciliation_at=replacement_time + timedelta(hours=6),
        ),
        now=replacement_time,
    )

    assert replacement.matrix_suspended is True

    current = await subscription_repository.record_subscription_enforcement(
        "old-token",
        suspended=False,
        now=replacement_time,
    )

    assert current.token_fingerprint == "new-token"
    assert current.matrix_suspended is False
    due = await subscription_repository.list_due_reconciliation(replacement_time, limit=10)
    assert [row.token_fingerprint for row in due] == ["new-token"]


async def test_enforcement_rejects_entitlement_without_current_token(
    subscription_repository,
):
    entitlement = await create_entitlement(subscription_repository)
    await subscription_repository.store_verified_subscription(
        verified_subscription(entitlement.entitlement_id, "retired-token"),
        now=NOW,
    )
    connection = sqlite3.connect(subscription_repository.db_path)
    connection.execute(
        "UPDATE play_subscriptions SET is_current = 0 WHERE token_fingerprint = ?",
        ("retired-token",),
    )
    connection.commit()
    connection.close()

    with pytest.raises(PurchaseTokenConflictException, match="Unknown purchase token"):
        await subscription_repository.record_subscription_enforcement(
            "retired-token",
            suspended=True,
            now=NOW,
        )


async def store_paid_bundle(repository, token_fingerprint, **overrides):
    subscription = await repository.get_subscription_by_token(token_fingerprint)
    provisioning_token = overrides.pop("provisioning_token", "test-provisioning-operation")
    if overrides.pop("reserve", True):
        await repository.reserve_paid_bundle_provisioning(
            subscription.entitlement_id,
            token_fingerprint=token_fingerprint,
            operation_token=provisioning_token,
            now=overrides.get("now", NOW),
            stale_before=overrides.get("now", NOW) - timedelta(minutes=5),
        )
    values = {
        "token_fingerprint": token_fingerprint,
        "provisioning_token": provisioning_token,
        "bundle_id": "bundle-paid",
        "username": "sync_paid",
        "user_mxid": "@sync_paid:example.com",
        "home_server": "https://matrix.example.com",
        "server_name": "example.com",
        "room_id": "!paid:example.com",
        "display_name": "Lotti SYNC",
        "bundle_fingerprint": "b" * 64,
        "notes": "Verified Google Play subscription",
        "claim_secret_hash": "claim-secret-hash",
        "encrypted_bundle": b"encrypted-bundle",
        "encryption_key_id": "test-key-v1",
        "expires_at": NOW + timedelta(hours=24),
        "now": NOW,
    }
    values.update(overrides)
    return await repository.store_paid_bundle(**values)


async def test_paid_bundle_account_claim_and_subscription_link_commit_together(
    subscription_repository,
):
    entitlement = await create_entitlement(subscription_repository)
    subscription = await subscription_repository.store_verified_subscription(
        verified_subscription(entitlement.entitlement_id, "paid-token"),
        now=NOW,
    )

    user, claim = await store_paid_bundle(subscription_repository, "paid-token")
    linked = await subscription_repository.get_subscription_by_token("paid-token")

    assert user.bundle_id == "bundle-paid"
    assert user.payment_status.value == "paying"
    assert claim.subscription_id == subscription.subscription_id
    assert claim.authorized_token_fingerprint == "paid-token"
    assert claim.encrypted_bundle == b"encrypted-bundle"
    assert linked.bundle_id == "bundle-paid"
    assert (
        await subscription_repository.get_bundle_claim_for_entitlement(entitlement.entitlement_id)
        == claim
    )


async def test_legacy_rotation_rejects_paid_bundle_claim(subscription_repository):
    entitlement = await create_entitlement(subscription_repository)
    await subscription_repository.store_verified_subscription(
        verified_subscription(entitlement.entitlement_id, "paid-token"),
        now=NOW,
    )
    user, claim = await store_paid_bundle(subscription_repository, "paid-token")

    with pytest.raises(InvalidBundleStateException, match="paid bundle"):
        await subscription_repository.mark_rotated(user.bundle_id)

    unchanged_user = await subscription_repository.get(user.bundle_id)
    unchanged_claim = await subscription_repository.get_bundle_claim_for_entitlement(
        entitlement.entitlement_id
    )
    assert unchanged_user.status is BundleStatus.UNUSED
    assert unchanged_claim.confirmed_at is None
    assert unchanged_claim.encrypted_bundle == claim.encrypted_bundle


async def test_legacy_rotation_still_accepts_standard_bundle(subscription_repository):
    user = await seed_user(subscription_repository, "standard_bundle")

    rotated = await subscription_repository.mark_rotated(user.bundle_id)

    assert rotated.status is BundleStatus.ROTATED
    assert rotated.rotated_at is not None


async def test_paid_provisioning_reservation_is_exclusive_owned_and_recoverable(
    subscription_repository,
):
    entitlement = await create_entitlement(subscription_repository)
    await subscription_repository.store_verified_subscription(
        verified_subscription(entitlement.entitlement_id, "paid-token"),
        now=NOW,
    )

    assert await subscription_repository.reserve_paid_bundle_provisioning(
        entitlement.entitlement_id,
        token_fingerprint="paid-token",
        operation_token="owner-one",
        now=NOW,
        stale_before=NOW - timedelta(minutes=5),
    )
    assert await subscription_repository.reserve_paid_bundle_provisioning(
        entitlement.entitlement_id,
        token_fingerprint="paid-token",
        operation_token="owner-one",
        now=NOW,
        stale_before=NOW - timedelta(minutes=5),
    )
    assert not await subscription_repository.reserve_paid_bundle_provisioning(
        entitlement.entitlement_id,
        token_fingerprint="paid-token",
        operation_token="owner-two",
        now=NOW + timedelta(minutes=1),
        stale_before=NOW - timedelta(minutes=4),
    )
    assert not await subscription_repository.release_paid_bundle_provisioning(
        entitlement.entitlement_id,
        operation_token="wrong-owner",
    )
    assert await subscription_repository.reserve_paid_bundle_provisioning(
        entitlement.entitlement_id,
        token_fingerprint="paid-token",
        operation_token="owner-two",
        now=NOW + timedelta(minutes=5),
        stale_before=NOW,
    )
    assert not await subscription_repository.release_paid_bundle_provisioning(
        entitlement.entitlement_id,
        operation_token="owner-one",
    )
    assert await subscription_repository.release_paid_bundle_provisioning(
        entitlement.entitlement_id,
        operation_token="owner-two",
    )


async def test_paid_bundle_store_requires_the_reservation_owner(subscription_repository):
    entitlement = await create_entitlement(subscription_repository)
    await subscription_repository.store_verified_subscription(
        verified_subscription(entitlement.entitlement_id, "paid-token"),
        now=NOW,
    )

    with pytest.raises(BundleClaimConflictException, match="reservation was lost"):
        await store_paid_bundle(
            subscription_repository,
            "paid-token",
            provisioning_token="not-an-owner",
            reserve=False,
        )


async def test_subscription_timestamps_are_normalized_to_utc_and_reject_naive_values(
    subscription_repository,
):
    local_time = datetime(2026, 8, 29, 14, tzinfo=timezone(timedelta(hours=2)))

    stored = await subscription_repository.create_entitlement(
        entitlement_id="localized-entitlement",
        obfuscated_account_id="localized-obfuscated",
        auth_secret_hash="auth-hash",
        now=local_time,
    )

    assert stored.created_at == NOW
    with pytest.raises(ValueError, match="timezone-aware"):
        await subscription_repository.create_entitlement(
            entitlement_id="naive-entitlement",
            obfuscated_account_id="naive-obfuscated",
            auth_secret_hash="auth-hash",
            now=datetime(2026, 8, 29, 12),
        )


async def test_quota_and_reservation_roll_back_after_invalid_naive_timestamps(
    subscription_repository,
):
    entitlement = await create_entitlement(subscription_repository)
    await subscription_repository.store_verified_subscription(
        verified_subscription(entitlement.entitlement_id, "paid-token"),
        now=NOW,
    )
    naive = datetime(2026, 8, 29, 12)

    with pytest.raises(ValueError, match="timezone-aware"):
        await subscription_repository.consume_entitlement_issuance_quota(
            "client-key",
            now=naive,
            window=timedelta(hours=1),
            max_requests=1,
        )
    assert (
        await subscription_repository.consume_entitlement_issuance_quota(
            "client-key",
            now=NOW,
            window=timedelta(hours=1),
            max_requests=1,
        )
        is None
    )

    with pytest.raises(ValueError, match="timezone-aware"):
        await subscription_repository.reserve_paid_bundle_provisioning(
            entitlement.entitlement_id,
            token_fingerprint="paid-token",
            operation_token="naive-operation",
            now=naive,
            stale_before=NOW - timedelta(minutes=5),
        )
    assert await subscription_repository.reserve_paid_bundle_provisioning(
        entitlement.entitlement_id,
        token_fingerprint="paid-token",
        operation_token="valid-operation",
        now=NOW,
        stale_before=NOW - timedelta(minutes=5),
    )


async def test_paid_bundle_write_rolls_back_every_table_on_username_conflict(
    subscription_repository,
):
    entitlement = await create_entitlement(subscription_repository)
    await subscription_repository.store_verified_subscription(
        verified_subscription(entitlement.entitlement_id, "paid-token"),
        now=NOW,
    )
    await seed_user(subscription_repository, username="sync_paid")

    with pytest.raises(BundleClaimConflictException):
        await store_paid_bundle(subscription_repository, "paid-token")

    subscription = await subscription_repository.get_subscription_by_token("paid-token")
    assert subscription.bundle_id is None
    assert (
        await subscription_repository.get_bundle_claim_for_entitlement(entitlement.entitlement_id)
        is None
    )


async def test_paid_bundle_cannot_be_attached_twice(subscription_repository):
    entitlement = await create_entitlement(subscription_repository)
    await subscription_repository.store_verified_subscription(
        verified_subscription(entitlement.entitlement_id, "paid-token"),
        now=NOW,
    )
    await store_paid_bundle(subscription_repository, "paid-token")

    with pytest.raises(BundleClaimConflictException):
        await store_paid_bundle(
            subscription_repository,
            "paid-token",
            bundle_id="second-bundle",
            username="sync_second",
            user_mxid="@sync_second:example.com",
        )

    assert await subscription_repository.get("second-bundle") is None


async def test_bundle_delivery_timestamp_is_idempotent(subscription_repository):
    entitlement = await create_entitlement(subscription_repository)
    await subscription_repository.store_verified_subscription(
        verified_subscription(entitlement.entitlement_id, "paid-token"),
        now=NOW,
    )
    _, claim = await store_paid_bundle(subscription_repository, "paid-token")

    first_lease = await subscription_repository.reserve_bundle_delivery(
        claim.bundle_id,
        operation_token="delivery-one",
        now=NOW + timedelta(minutes=1),
        stale_before=NOW - timedelta(minutes=4),
    )
    first = await subscription_repository.complete_bundle_delivery(
        claim.bundle_id,
        operation_token="delivery-one",
        now=NOW + timedelta(minutes=1),
    )
    retry_lease = await subscription_repository.reserve_bundle_delivery(
        claim.bundle_id,
        operation_token="delivery-two",
        now=NOW + timedelta(minutes=2),
        stale_before=NOW - timedelta(minutes=3),
    )
    retry = await subscription_repository.complete_bundle_delivery(
        claim.bundle_id,
        operation_token="delivery-two",
        now=NOW + timedelta(minutes=2),
    )

    assert first_lease.bundle_id == claim.bundle_id
    assert retry_lease.bundle_id == claim.bundle_id
    assert retry.first_delivered_at == first.first_delivered_at


async def test_linked_purchase_inherits_existing_bundle_claim(subscription_repository):
    entitlement = await create_entitlement(subscription_repository)
    await subscription_repository.store_verified_subscription(
        verified_subscription(entitlement.entitlement_id, "old-token"),
        now=NOW,
    )
    _, original_claim = await store_paid_bundle(subscription_repository, "old-token")

    replacement = await subscription_repository.store_verified_subscription(
        verified_subscription(
            entitlement.entitlement_id,
            "new-token",
            linked_token_fingerprint="old-token",
        ),
        now=NOW + timedelta(days=1),
    )
    moved_claim = await subscription_repository.get_bundle_claim_for_entitlement(
        entitlement.entitlement_id
    )

    assert replacement.bundle_id == original_claim.bundle_id
    assert moved_claim.bundle_id == original_claim.bundle_id
    assert moved_claim.subscription_id == replacement.subscription_id


async def test_bundle_claim_operation_lease_is_exclusive_and_recoverable(
    subscription_repository,
):
    entitlement = await create_entitlement(subscription_repository)
    await subscription_repository.store_verified_subscription(
        verified_subscription(entitlement.entitlement_id, "paid-token"),
        now=NOW,
    )
    _, claim = await store_paid_bundle(subscription_repository, "paid-token")
    await subscription_repository.reserve_bundle_rotation(
        claim.bundle_id,
        operation_token="rotation-one",
        now=NOW,
        stale_before=NOW - timedelta(minutes=5),
    )

    with pytest.raises(BundleClaimConflictException, match="already being processed"):
        await subscription_repository.reserve_bundle_rotation(
            claim.bundle_id,
            operation_token="rotation-two",
            now=NOW + timedelta(minutes=1),
            stale_before=NOW - timedelta(minutes=4),
        )
    assert not await subscription_repository.reserve_bundle_reap(
        claim.bundle_id,
        operation_token="early-reap",
        now=NOW + timedelta(hours=1),
        stale_before=NOW - timedelta(minutes=4),
    )
    assert not await subscription_repository.release_bundle_claim_operation(
        claim.bundle_id,
        operation_token="wrong-owner",
    )

    assert await subscription_repository.reserve_bundle_reap(
        claim.bundle_id,
        operation_token="stale-reap",
        now=claim.expires_at,
        stale_before=NOW,
    )
    assert not await subscription_repository.release_bundle_claim_operation(
        claim.bundle_id,
        operation_token="rotation-one",
    )
    with pytest.raises(BundleClaimConflictException, match="lease was lost"):
        await subscription_repository.reschedule_bundle_claim_reap(
            claim.bundle_id,
            next_reap_at=claim.expires_at + timedelta(minutes=5),
            operation_token="wrong-owner",
        )
    rescheduled = await subscription_repository.reschedule_bundle_claim_reap(
        claim.bundle_id,
        next_reap_at=claim.expires_at + timedelta(minutes=5),
        operation_token="stale-reap",
    )

    assert rescheduled.encrypted_bundle is not None
    assert (
        await subscription_repository.list_expired_bundle_claims(
            claim.expires_at,
            stale_before=claim.expires_at - timedelta(minutes=5),
            limit=50,
        )
        == []
    )

    reap_at = claim.expires_at + timedelta(minutes=5)
    assert await subscription_repository.reserve_bundle_reap(
        claim.bundle_id,
        operation_token="final-reap",
        now=reap_at,
        stale_before=claim.expires_at,
    )
    abandoned = await subscription_repository.abandon_bundle_claim(
        claim.bundle_id,
        now=reap_at,
        operation_token="final-reap",
    )

    assert abandoned.encrypted_bundle is None
    assert abandoned.destroyed_at == reap_at


async def test_terminal_and_unknown_claims_cannot_be_reserved(subscription_repository):
    entitlement = await create_entitlement(subscription_repository)
    await subscription_repository.store_verified_subscription(
        verified_subscription(entitlement.entitlement_id, "paid-token"),
        now=NOW,
    )
    _, claim = await store_paid_bundle(subscription_repository, "paid-token")

    with pytest.raises(BundleClaimConflictException, match="expired"):
        await subscription_repository.reserve_bundle_delivery(
            claim.bundle_id,
            operation_token="late-delivery",
            now=claim.expires_at,
            stale_before=NOW,
        )
    await subscription_repository.reserve_bundle_rotation(
        claim.bundle_id,
        operation_token="rotation-operation",
        now=NOW,
        stale_before=NOW - timedelta(minutes=5),
    )
    await subscription_repository.confirm_paid_bundle_rotation(
        claim.bundle_id,
        now=NOW,
        operation_token="rotation-operation",
    )

    assert not await subscription_repository.reserve_bundle_reap(
        claim.bundle_id,
        operation_token="reap-operation",
        now=claim.expires_at,
        stale_before=NOW,
    )
    with pytest.raises(BundleClaimConflictException, match="already being processed"):
        await subscription_repository.reserve_bundle_rotation(
            claim.bundle_id,
            operation_token="rotation-operation",
            now=NOW,
            stale_before=NOW - timedelta(minutes=5),
        )
    with pytest.raises(BundleClaimConflictException, match="Unknown bundle claim"):
        await subscription_repository.reserve_bundle_rotation(
            "unknown",
            operation_token="rotation-operation",
            now=NOW,
            stale_before=NOW - timedelta(minutes=5),
        )


async def test_pending_claim_reauthorization_rejects_active_operation(
    subscription_repository,
):
    entitlement = await create_entitlement(subscription_repository)
    await subscription_repository.store_verified_subscription(
        verified_subscription(entitlement.entitlement_id, "paid-token"),
        now=NOW,
    )
    _, claim = await store_paid_bundle(subscription_repository, "paid-token")
    await subscription_repository.reserve_bundle_rotation(
        claim.bundle_id,
        operation_token="rotation-operation",
        now=NOW,
        stale_before=NOW - timedelta(minutes=5),
    )

    with pytest.raises(BundleClaimConflictException, match="cannot be reauthorized"):
        await subscription_repository.reauthorize_pending_bundle_claim(
            entitlement.entitlement_id,
            token_fingerprint="paid-token",
            claim_secret_hash="replacement-secret-hash",
        )
    with pytest.raises(BundleClaimConflictException, match="rotation lease was lost"):
        await subscription_repository.confirm_paid_bundle_rotation(
            claim.bundle_id,
            now=NOW,
            operation_token="wrong-operation",
        )


async def test_pending_claim_reauthorization_requires_a_replacement_token(
    subscription_repository,
):
    entitlement = await create_entitlement(subscription_repository)
    await subscription_repository.store_verified_subscription(
        verified_subscription(entitlement.entitlement_id, "paid-token"),
        now=NOW,
    )
    _, claim = await store_paid_bundle(subscription_repository, "paid-token")

    with pytest.raises(BundleClaimConflictException, match="cannot be reauthorized"):
        await subscription_repository.reauthorize_pending_bundle_claim(
            entitlement.entitlement_id,
            token_fingerprint="paid-token",
            claim_secret_hash="replacement-secret-hash",
        )

    unchanged = await subscription_repository.get_bundle_claim_for_entitlement(
        entitlement.entitlement_id
    )
    assert unchanged.bundle_id == claim.bundle_id
    assert unchanged.claim_secret_hash == "claim-secret-hash"
    assert unchanged.authorized_token_fingerprint == "paid-token"


async def test_same_token_refresh_does_not_clear_existing_bundle(
    subscription_repository,
):
    entitlement = await create_entitlement(subscription_repository)
    snapshot = verified_subscription(entitlement.entitlement_id, "paid-token")
    await subscription_repository.store_verified_subscription(snapshot, now=NOW)
    _, claim = await store_paid_bundle(subscription_repository, "paid-token")

    refreshed = await subscription_repository.store_verified_subscription(
        replace(snapshot, current_period_end=NOW + timedelta(days=60)),
        now=NOW + timedelta(days=1),
    )

    assert refreshed.bundle_id == claim.bundle_id
    assert (
        await subscription_repository.get_bundle_claim_for_entitlement(entitlement.entitlement_id)
        is not None
    )


@pytest.mark.parametrize(
    "operation",
    [
        lambda repository: repository.complete_bundle_delivery(
            "unknown",
            operation_token="delivery-operation",
            now=NOW,
        ),
        lambda repository: repository.abandon_bundle_claim("unknown", now=NOW),
        lambda repository: repository.reschedule_bundle_claim_reap(
            "unknown",
            next_reap_at=NOW,
            operation_token="reap-operation",
        ),
        lambda repository: repository.confirm_paid_bundle_rotation(
            "unknown",
            now=NOW,
            operation_token="rotation-operation",
        ),
    ],
)
async def test_unknown_bundle_claim_mutations_are_rejected(
    subscription_repository,
    operation,
):
    with pytest.raises(BundleClaimConflictException):
        await operation(subscription_repository)


async def test_only_revoked_abandoned_claim_can_be_released(subscription_repository):
    with pytest.raises(BundleClaimConflictException, match="not abandoned"):
        await subscription_repository.release_abandoned_bundle_claim("unknown", now=NOW)

    entitlement = await create_entitlement(subscription_repository)
    await subscription_repository.store_verified_subscription(
        verified_subscription(entitlement.entitlement_id, "paid-token"),
        now=NOW,
    )
    user, claim = await store_paid_bundle(subscription_repository, "paid-token")
    await subscription_repository.revoke(user.bundle_id, "revoked by administrator", now=NOW)

    with pytest.raises(BundleClaimConflictException, match="not abandoned"):
        await subscription_repository.release_abandoned_bundle_claim(
            entitlement.entitlement_id,
            now=NOW,
        )

    current = await subscription_repository.get_current_subscription(entitlement.entitlement_id)
    stored_claim = await subscription_repository.get_bundle_claim_for_entitlement(
        entitlement.entitlement_id
    )
    assert current.bundle_id == user.bundle_id
    assert stored_claim.bundle_id == claim.bundle_id
    assert stored_claim.abandoned_at is None


@pytest.mark.parametrize(
    "operation",
    [
        lambda repository: repository.mark_subscription_acknowledged("unknown", now=NOW),
        lambda repository: repository.record_subscription_enforcement(
            "unknown", suspended=True, now=NOW
        ),
        lambda repository: repository.record_subscription_error(
            "unknown", last_error="failure", now=NOW
        ),
    ],
)
async def test_unknown_subscription_mutations_are_rejected(
    subscription_repository,
    operation,
):
    with pytest.raises(PurchaseTokenConflictException):
        await operation(subscription_repository)


async def test_revoked_paid_bundle_cannot_be_confirmed(subscription_repository):
    entitlement = await create_entitlement(subscription_repository)
    await subscription_repository.store_verified_subscription(
        verified_subscription(entitlement.entitlement_id, "paid-token"),
        now=NOW,
    )
    user, _ = await store_paid_bundle(subscription_repository, "paid-token")
    await subscription_repository.revoke(user.bundle_id, "abandoned")

    with pytest.raises(BundleClaimConflictException, match="Revoked"):
        await subscription_repository.confirm_paid_bundle_rotation(
            user.bundle_id,
            now=NOW,
            operation_token="rotation-operation",
        )
