"""Tests for durable Google Play entitlement and token ownership state."""

# ruff: noqa: S105,S106 - explicit non-production token and secret fixtures

from __future__ import annotations

import sqlite3
from dataclasses import replace
from datetime import datetime, timedelta, timezone

import pytest
from src.core.exceptions import (
    BundleClaimConflictException,
    PurchaseIntentExpiredException,
    PurchaseIntentNotFoundException,
    PurchaseIntentReplayException,
    PurchaseTokenConflictException,
    SubscriptionLineageException,
)
from src.core.subscriptions import (
    AcknowledgementState,
    EntitlementState,
    GoogleSubscriptionState,
    VerifiedSubscription,
)
from src.services.subscription_repository import SubscriptionRepository
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
    } <= columns


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


async def store_paid_bundle(repository, token_fingerprint, **overrides):
    values = {
        "token_fingerprint": token_fingerprint,
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
    assert claim.encrypted_bundle == b"encrypted-bundle"
    assert linked.bundle_id == "bundle-paid"
    assert (
        await subscription_repository.get_bundle_claim_for_entitlement(entitlement.entitlement_id)
        == claim
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

    first = await subscription_repository.mark_bundle_delivered(
        claim.bundle_id,
        now=NOW + timedelta(minutes=1),
    )
    retry = await subscription_repository.mark_bundle_delivered(
        claim.bundle_id,
        now=NOW + timedelta(minutes=2),
    )

    assert retry.first_delivered_at == first.first_delivered_at


async def test_destroying_claim_removes_only_ciphertext_and_is_idempotent(
    subscription_repository,
):
    entitlement = await create_entitlement(subscription_repository)
    await subscription_repository.store_verified_subscription(
        verified_subscription(entitlement.entitlement_id, "paid-token"),
        now=NOW,
    )
    _, claim = await store_paid_bundle(subscription_repository, "paid-token")

    destroyed = await subscription_repository.destroy_bundle_claim(
        claim.bundle_id,
        now=NOW + timedelta(minutes=3),
    )
    retry = await subscription_repository.destroy_bundle_claim(
        claim.bundle_id,
        now=NOW + timedelta(minutes=4),
    )

    assert destroyed.encrypted_bundle is None
    assert retry.destroyed_at == destroyed.destroyed_at
    assert retry.confirmed_at == destroyed.confirmed_at


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


async def test_terminal_and_unknown_claims_cannot_be_reserved(subscription_repository):
    entitlement = await create_entitlement(subscription_repository)
    await subscription_repository.store_verified_subscription(
        verified_subscription(entitlement.entitlement_id, "paid-token"),
        now=NOW,
    )
    _, claim = await store_paid_bundle(subscription_repository, "paid-token")
    await subscription_repository.destroy_bundle_claim(claim.bundle_id, now=NOW)

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
            claim_secret_hash="replacement-secret-hash",
        )
    with pytest.raises(BundleClaimConflictException, match="rotation lease was lost"):
        await subscription_repository.confirm_paid_bundle_rotation(
            claim.bundle_id,
            now=NOW,
            operation_token="wrong-operation",
        )


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
        lambda repository: repository.mark_bundle_delivered("unknown", now=NOW),
        lambda repository: repository.destroy_bundle_claim("unknown", now=NOW),
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
