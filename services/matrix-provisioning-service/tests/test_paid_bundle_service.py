"""Tests for idempotent paid Matrix provisioning and encrypted delivery."""

# ruff: noqa: S106 - explicit non-production credential fixtures

from __future__ import annotations

import asyncio
from dataclasses import replace
from datetime import datetime, timedelta, timezone

import pytest
from src.core.exceptions import (
    BundleClaimConflictException,
    GooglePlayVerificationException,
)
from src.core.subscriptions import (
    AcknowledgementState,
    EntitlementState,
    GoogleSubscriptionState,
    PurchaseSubmission,
    VerifiedPurchaseResult,
    VerifiedSubscription,
)
from src.services.paid_bundle_service import PaidBundleService
from src.services.secret_cipher import SecretCipher
from src.services.subscription_repository import SubscriptionRepository
from src.services.subscription_security import SecretHasher

from shared.matrix import BundleKind, ProvisionResult, SyncBundle

pytestmark = pytest.mark.anyio

NOW = datetime(2026, 8, 29, 12, tzinfo=timezone.utc)
ENCODED_BUNDLE = SyncBundle(
    home_server="https://matrix.example.com",
    user="@sync_entitlementone:example.com",
    password="bootstrap-password",
    room_id="!paid:example.com",
    kind=BundleKind.PROVISIONED,
).encode()


class FakeBundleService:
    def __init__(self, *, block_first=False):
        self.calls = []
        self.block_first = block_first
        self.first_started = asyncio.Event()
        self.release_first = asyncio.Event()

    async def create_bundle_with_persistence(self, request, persist):
        self.calls.append(request)
        if self.block_first and len(self.calls) == 1:
            self.first_started.set()
            await self.release_first.wait()
        result = ProvisionResult(
            bundle=SyncBundle.decode(ENCODED_BUNDLE),
            user_mxid="@sync_entitlementone:example.com",
            room_id="!paid:example.com",
            server_name="example.com",
        )
        return await persist(result, ENCODED_BUNDLE)


class FakeGooglePlayClient:
    def __init__(self):
        self.acknowledgements = []
        self.failure = None

    async def acknowledge_subscription(self, package_name, product_id, purchase_token):
        if self.failure:
            raise self.failure
        self.acknowledgements.append((package_name, product_id, purchase_token))


@pytest.fixture
def repository(tmp_path):
    return SubscriptionRepository(str(tmp_path / "subscriptions.db"))


@pytest.fixture
def bundle_service():
    return FakeBundleService()


@pytest.fixture
def google_client():
    return FakeGooglePlayClient()


@pytest.fixture
def cipher():
    return SecretCipher(key_id="test-key", key=bytes(range(32)))


@pytest.fixture
def service(bundle_service, repository, google_client, cipher):
    return PaidBundleService(bundle_service, repository, google_client, cipher)


async def verified_purchase(repository, *, state=EntitlementState.ACTIVE):
    entitlement = await repository.create_entitlement(
        entitlement_id="entitlement-one",
        obfuscated_account_id="obfuscated-one",
        auth_secret_hash="auth-hash",
        now=NOW,
    )
    stored = await repository.store_verified_subscription(
        VerifiedSubscription(
            entitlement_id=entitlement.entitlement_id,
            token_fingerprint="purchase-token-fingerprint",
            encrypted_purchase_token=b"encrypted-purchase-token",
            encryption_key_id="test-key",
            package_name="com.matthiasn.lotti",
            product_id="lotti_sync",
            base_plan_id="monthly",
            latest_order_id="GPA.1234",
            google_state=GoogleSubscriptionState.ACTIVE,
            entitlement_state=state,
            start_time=NOW,
            current_period_end=NOW + timedelta(days=30),
            grace_deadline=None,
            acknowledgement_state=AcknowledgementState.PENDING,
            binding_verified=True,
            last_verified_at=NOW,
            next_reconciliation_at=NOW + timedelta(hours=6),
        ),
        now=NOW,
    )
    return VerifiedPurchaseResult(
        subscription=stored,
        request_hash="request-hash",
        claim_secret_hash=SecretHasher().hash("claim-secret"),
    )


def submission(**overrides):
    values = {
        "package_name": "com.matthiasn.lotti",
        "product_id": "lotti_sync",
        "base_plan_id": "monthly",
        "entitlement_id": "entitlement-one",
        "purchase_intent_id": "intent-one",
        "purchase_token": "purchase-token",
        "intent_secret": "intent-secret",
        "claim_secret": "claim-secret",
        "integrity_token": "integrity-token",
    }
    values.update(overrides)
    return PurchaseSubmission(**values)


async def test_first_delivery_provisions_once_escrows_and_acknowledges(
    service,
    repository,
    bundle_service,
    google_client,
):
    verified = await verified_purchase(repository)

    delivery = await service.provision_or_deliver(verified, submission(), now=NOW)

    claim = await repository.get_bundle_claim_for_entitlement("entitlement-one")
    stored = await repository.get_subscription_by_token("purchase-token-fingerprint")
    assert delivery.bundle == ENCODED_BUNDLE
    assert delivery.bundle_id == claim.bundle_id
    assert delivery.expires_at == NOW + timedelta(hours=24)
    assert delivery.rotation_challenge
    assert claim.encrypted_bundle != ENCODED_BUNDLE.encode()
    assert claim.first_delivered_at == NOW
    assert len(bundle_service.calls) == 1
    assert google_client.acknowledgements == [
        ("com.matthiasn.lotti", "lotti_sync", "purchase-token")
    ]
    assert stored.acknowledgement_state is AcknowledgementState.ACKNOWLEDGED
    assert stored.acknowledged_at == NOW


async def test_lost_response_retry_returns_same_bundle_without_second_account(
    service,
    repository,
    bundle_service,
):
    verified = await verified_purchase(repository)
    first = await service.provision_or_deliver(verified, submission(), now=NOW)

    retry = await service.provision_or_deliver(
        replace(
            verified,
            subscription=await repository.get_subscription_by_token("purchase-token-fingerprint"),
            claim_secret_hash=SecretHasher().hash("claim-secret"),
        ),
        submission(),
        now=NOW + timedelta(minutes=1),
    )

    assert retry.bundle_id == first.bundle_id
    assert retry.bundle == first.bundle
    assert retry.rotation_challenge == first.rotation_challenge
    assert len(bundle_service.calls) == 1


async def test_wrong_claim_secret_cannot_read_escrow(service, repository):
    verified = await verified_purchase(repository)

    with pytest.raises(BundleClaimConflictException, match="claim secret"):
        await service.provision_or_deliver(
            verified,
            submission(claim_secret="attacker-secret"),
            now=NOW,
        )


async def test_non_grantable_purchase_never_provisions(service, repository, bundle_service):
    verified = await verified_purchase(repository, state=EntitlementState.SUSPENDED)

    with pytest.raises(GooglePlayVerificationException, match="does not currently grant"):
        await service.provision_or_deliver(verified, submission(), now=NOW)

    assert bundle_service.calls == []


async def test_acknowledgement_failure_leaves_bundle_available_for_retry(
    service,
    repository,
    google_client,
    bundle_service,
):
    verified = await verified_purchase(repository)
    google_client.failure = RuntimeError("google unavailable")

    with pytest.raises(RuntimeError, match="google unavailable"):
        await service.provision_or_deliver(verified, submission(), now=NOW)

    claim = await repository.get_bundle_claim_for_entitlement("entitlement-one")
    assert claim.encrypted_bundle is not None
    assert len(bundle_service.calls) == 1

    google_client.failure = None
    current = await repository.get_subscription_by_token("purchase-token-fingerprint")
    delivery = await service.provision_or_deliver(
        replace(verified, subscription=current),
        submission(),
        now=NOW + timedelta(minutes=1),
    )
    assert delivery.bundle == ENCODED_BUNDLE
    assert len(bundle_service.calls) == 1


async def test_confirmed_claim_recovers_replacement_purchase_without_redelivery(
    service,
    repository,
    bundle_service,
    google_client,
):
    original = await verified_purchase(repository)
    first_delivery = await service.provision_or_deliver(original, submission(), now=NOW)
    await repository.destroy_bundle_claim(
        first_delivery.bundle_id,
        now=NOW + timedelta(minutes=1),
    )
    replacement = await repository.store_verified_subscription(
        VerifiedSubscription(
            entitlement_id="entitlement-one",
            token_fingerprint="replacement-token-fingerprint",
            encrypted_purchase_token=b"encrypted-replacement-token",
            encryption_key_id="test-key",
            package_name="com.matthiasn.lotti",
            product_id="lotti_sync",
            base_plan_id="annual",
            latest_order_id="GPA.5678",
            google_state=GoogleSubscriptionState.ACTIVE,
            entitlement_state=EntitlementState.ACTIVE,
            start_time=NOW + timedelta(days=30),
            current_period_end=NOW + timedelta(days=395),
            grace_deadline=None,
            acknowledgement_state=AcknowledgementState.PENDING,
            binding_verified=True,
            last_verified_at=NOW + timedelta(days=30),
            next_reconciliation_at=NOW + timedelta(days=30, hours=6),
            linked_token_fingerprint="purchase-token-fingerprint",
        ),
        now=NOW + timedelta(days=30),
    )

    recovered = await service.provision_or_deliver(
        VerifiedPurchaseResult(
            subscription=replacement,
            request_hash="replacement-request-hash",
            claim_secret_hash=SecretHasher().hash("new-claim-secret"),
        ),
        submission(
            base_plan_id="annual",
            purchase_token="replacement-token",
            claim_secret="new-claim-secret",
        ),
        now=NOW + timedelta(days=30),
    )

    assert recovered.bundle_id == first_delivery.bundle_id
    assert recovered.bundle is None
    assert recovered.expires_at is None
    assert recovered.rotation_challenge is None
    assert recovered.bundle_import_required is False
    assert len(bundle_service.calls) == 1
    assert google_client.acknowledgements[-1] == (
        "com.matthiasn.lotti",
        "lotti_sync",
        "replacement-token",
    )


async def test_overlapping_retries_share_one_provisioned_bundle(
    repository,
    google_client,
    cipher,
):
    bundle_service = FakeBundleService(block_first=True)
    service = PaidBundleService(bundle_service, repository, google_client, cipher)
    verified = await verified_purchase(repository)

    first = asyncio.create_task(service.provision_or_deliver(verified, submission(), now=NOW))
    await bundle_service.first_started.wait()
    second = asyncio.create_task(service.provision_or_deliver(verified, submission(), now=NOW))
    asyncio.get_running_loop().call_soon(bundle_service.release_first.set)

    first_delivery, second_delivery = await asyncio.gather(first, second)

    assert first_delivery.bundle_id == second_delivery.bundle_id
    assert first_delivery.bundle == second_delivery.bundle
    assert len(bundle_service.calls) == 1


async def test_delivery_retry_rejects_missing_claim(service):
    with pytest.raises(BundleClaimConflictException, match="No bundle claim"):
        await service.deliver_existing_claim(
            entitlement_id="unknown-entitlement",
            claim_secret="claim-secret",
            now=NOW,
        )


async def test_delivery_retry_rejects_expired_claim(service, repository):
    verified = await verified_purchase(repository)
    await service.provision_or_deliver(verified, submission(), now=NOW)

    with pytest.raises(BundleClaimConflictException, match="expired"):
        await service.deliver_existing_claim(
            entitlement_id="entitlement-one",
            claim_secret="claim-secret",
            now=NOW + timedelta(hours=24),
        )


async def test_delivery_retry_rejects_wrong_claim_secret(service, repository):
    verified = await verified_purchase(repository)
    await service.provision_or_deliver(verified, submission(), now=NOW)

    with pytest.raises(BundleClaimConflictException, match="Invalid bundle claim secret"):
        await service.deliver_existing_claim(
            entitlement_id="entitlement-one",
            claim_secret="attacker-secret",
            now=NOW + timedelta(minutes=1),
        )


def test_paid_username_is_deterministic_safe_and_bounded():
    username = PaidBundleService._username("ABC-def_123" * 20)

    assert username.startswith("sync_abcdef123")
    assert len(username) == 64
    assert username.replace("_", "").isalnum()
