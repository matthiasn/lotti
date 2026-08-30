"""Tests for idempotent paid Matrix provisioning and encrypted delivery."""

# ruff: noqa: S106 - explicit non-production credential fixtures

from __future__ import annotations

import asyncio
import threading
from dataclasses import fields, replace
from datetime import datetime, timedelta, timezone

import pytest
from src.core.exceptions import (
    BundleClaimConflictException,
    GooglePlayVerificationException,
    UsernameAlreadyProvisionedException,
)
from src.core.subscriptions import (
    AcknowledgementState,
    EntitlementState,
    GoogleSubscriptionState,
    PurchaseSubmission,
    VerifiedPurchaseResult,
    VerifiedSubscription,
)
from src.services.bundle_claim_reaper import BundleClaimReaper
from src.services.bundle_service import BundleService
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
    def __init__(self, *, block_first=False, reject_first_username=False):
        self.calls = []
        self.block_first = block_first
        self.reject_first_username = reject_first_username
        self.first_started = asyncio.Event()
        self.release_first = asyncio.Event()

    async def create_bundle_with_persistence(self, request, persist):
        self.calls.append(request)
        if self.reject_first_username and len(self.calls) == 1:
            raise UsernameAlreadyProvisionedException("localpart already exists")
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


class FakeReaperAdmin:
    def __init__(self):
        self.deactivated = []

    async def deactivate_user(self, user_mxid):
        self.deactivated.append(user_mxid)


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
    return PaidBundleService(
        bundle_service,
        repository,
        google_client,
        cipher,
        now_provider=lambda: NOW,
    )


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


def refreshed_snapshot(stored, **overrides):
    values = {field.name: getattr(stored, field.name) for field in fields(VerifiedSubscription)}
    values.update(overrides)
    return VerifiedSubscription(**values)


async def confirm_paid_claim(repository, bundle_id, *, now):
    operation_token = "test-rotation-operation"  # noqa: S105 - fixture lease token
    await repository.reserve_bundle_rotation(
        bundle_id,
        operation_token=operation_token,
        now=now,
        stale_before=now - timedelta(minutes=5),
    )
    _, claim = await repository.confirm_paid_bundle_rotation(
        bundle_id,
        now=now,
        operation_token=operation_token,
    )
    return claim


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


async def test_provisioning_rechecks_access_after_matrix_account_creation(
    repository,
    google_client,
    cipher,
):
    bundle_service = FakeBundleService(block_first=True)
    current_time = NOW
    service = PaidBundleService(
        bundle_service,
        repository,
        google_client,
        cipher,
        now_provider=lambda: current_time,
    )
    verified = await verified_purchase(repository)
    expiring = replace(
        verified,
        subscription=await repository.store_verified_subscription(
            refreshed_snapshot(
                verified.subscription,
                current_period_end=NOW + timedelta(minutes=1),
            ),
            now=NOW,
        ),
    )

    provisioning = asyncio.create_task(
        service.provision_or_deliver(expiring, submission(), now=NOW)
    )
    await bundle_service.first_started.wait()
    current_time = NOW + timedelta(minutes=1)
    bundle_service.release_first.set()

    with pytest.raises(GooglePlayVerificationException, match="does not currently grant"):
        await provisioning

    assert await repository.get_bundle_claim_for_entitlement("entitlement-one") is None
    assert google_client.acknowledgements == []


async def test_default_clock_rejects_purchase_that_expired_after_request_started(
    repository,
    bundle_service,
    google_client,
    cipher,
    monkeypatch,
):
    class FakeDatetime:
        @classmethod
        def now(cls, _timezone):
            return NOW + timedelta(minutes=1)

    monkeypatch.setattr("src.services.paid_bundle_service.datetime", FakeDatetime)
    service = PaidBundleService(bundle_service, repository, google_client, cipher)
    verified = await verified_purchase(repository)
    expiring = replace(
        verified,
        subscription=await repository.store_verified_subscription(
            refreshed_snapshot(
                verified.subscription,
                current_period_end=NOW + timedelta(minutes=1),
            ),
            now=NOW,
        ),
    )

    with pytest.raises(GooglePlayVerificationException, match="does not currently grant"):
        await service.provision_or_deliver(expiring, submission(), now=NOW)

    assert bundle_service.calls == []
    assert await repository.get_bundle_claim_for_entitlement("entitlement-one") is None


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


async def test_purchase_that_loses_access_before_stripe_never_provisions(
    service,
    repository,
    bundle_service,
):
    verified = await verified_purchase(repository)
    await repository.store_verified_subscription(
        refreshed_snapshot(
            verified.subscription,
            entitlement_state=EntitlementState.SUSPENDED,
        ),
        now=NOW + timedelta(minutes=1),
    )

    with pytest.raises(GooglePlayVerificationException, match="does not currently grant"):
        await service.provision_or_deliver(
            verified,
            submission(),
            now=NOW + timedelta(minutes=1),
        )

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


async def test_admin_revocation_during_acknowledgement_blocks_plaintext_return(
    service,
    repository,
    google_client,
    bundle_service,
    monkeypatch,
):
    verified = await verified_purchase(repository)
    acknowledgement_started = asyncio.Event()
    release_acknowledgement = asyncio.Event()
    acknowledge = google_client.acknowledge_subscription

    async def blocking_acknowledgement(package_name, product_id, purchase_token):
        acknowledgement_started.set()
        await release_acknowledgement.wait()
        await acknowledge(package_name, product_id, purchase_token)

    monkeypatch.setattr(
        google_client,
        "acknowledge_subscription",
        blocking_acknowledgement,
    )
    provisioning = asyncio.create_task(
        service.provision_or_deliver(verified, submission(), now=NOW)
    )
    await acknowledgement_started.wait()
    claim = await repository.get_bundle_claim_for_entitlement("entitlement-one")
    await repository.revoke(
        claim.bundle_id,
        "revoked during acknowledgement",
        now=NOW + timedelta(seconds=1),
    )
    release_acknowledgement.set()

    with pytest.raises(BundleClaimConflictException, match="terminal"):
        await provisioning

    destroyed = await repository.get_bundle_claim_for_entitlement("entitlement-one")
    assert destroyed.encrypted_bundle is None
    assert destroyed.destroyed_at == NOW + timedelta(seconds=1)
    assert len(bundle_service.calls) == 1


async def test_acknowledgement_crossing_claim_expiry_blocks_plaintext_return(
    service,
    repository,
    google_client,
    monkeypatch,
):
    verified = await verified_purchase(repository)
    current_time = NOW
    service._now_provider = lambda: current_time
    acknowledgement_started = asyncio.Event()
    release_acknowledgement = asyncio.Event()
    acknowledge = google_client.acknowledge_subscription

    async def blocking_acknowledgement(package_name, product_id, purchase_token):
        acknowledgement_started.set()
        await release_acknowledgement.wait()
        await acknowledge(package_name, product_id, purchase_token)

    monkeypatch.setattr(
        google_client,
        "acknowledge_subscription",
        blocking_acknowledgement,
    )
    provisioning = asyncio.create_task(
        service.provision_or_deliver(verified, submission(), now=NOW)
    )
    await acknowledgement_started.wait()
    claim = await repository.get_bundle_claim_for_entitlement("entitlement-one")
    current_time = claim.expires_at
    release_acknowledgement.set()

    with pytest.raises(BundleClaimConflictException, match="terminal"):
        await provisioning

    retained = await repository.get_bundle_claim_for_entitlement("entitlement-one")
    assert retained.encrypted_bundle is not None
    assert retained.destroyed_at is None


async def test_confirmed_claim_recovers_replacement_purchase_without_redelivery(
    service,
    repository,
    bundle_service,
    google_client,
):
    original = await verified_purchase(repository)
    first_delivery = await service.provision_or_deliver(original, submission(), now=NOW)
    await confirm_paid_claim(
        repository,
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


async def test_confirmed_claim_cannot_recover_admin_revoked_bundle(
    service,
    repository,
    bundle_service,
):
    verified = await verified_purchase(repository)
    delivered = await service.provision_or_deliver(verified, submission(), now=NOW)
    await confirm_paid_claim(
        repository,
        delivered.bundle_id,
        now=NOW + timedelta(minutes=1),
    )
    await repository.revoke(
        delivered.bundle_id,
        "revoked by administrator",
        now=NOW + timedelta(minutes=2),
    )

    with pytest.raises(BundleClaimConflictException, match="terminal"):
        await service.provision_or_deliver(
            verified,
            submission(),
            now=NOW + timedelta(minutes=3),
        )

    assert len(bundle_service.calls) == 1


async def test_admin_revocation_during_confirmed_recovery_wins(
    service,
    repository,
    bundle_service,
    monkeypatch,
):
    verified = await verified_purchase(repository)
    delivered = await service.provision_or_deliver(verified, submission(), now=NOW)
    await confirm_paid_claim(
        repository,
        delivered.bundle_id,
        now=NOW + timedelta(minutes=1),
    )
    load_subscription = service._load_current_subscription
    second_load_started = asyncio.Event()
    release_second_load = asyncio.Event()
    load_count = 0

    async def blocking_load_subscription(current_verified, *, now):
        nonlocal load_count
        current = await load_subscription(current_verified, now=now)
        load_count += 1
        if load_count == 2:
            second_load_started.set()
            await release_second_load.wait()
        return current

    monkeypatch.setattr(service, "_load_current_subscription", blocking_load_subscription)
    recovery = asyncio.create_task(
        service.provision_or_deliver(
            verified,
            submission(),
            now=NOW + timedelta(minutes=2),
        )
    )
    await second_load_started.wait()
    await repository.revoke(
        delivered.bundle_id,
        "revoked by administrator",
        now=NOW + timedelta(minutes=3),
    )
    release_second_load.set()

    with pytest.raises(BundleClaimConflictException, match="terminal"):
        await recovery

    assert len(bundle_service.calls) == 1


async def test_overlapping_retries_share_one_provisioned_bundle(
    repository,
    google_client,
    cipher,
):
    bundle_service = FakeBundleService(block_first=True)
    service = PaidBundleService(
        bundle_service,
        repository,
        google_client,
        cipher,
        now_provider=lambda: NOW,
    )
    verified = await verified_purchase(repository)

    first = asyncio.create_task(service.provision_or_deliver(verified, submission(), now=NOW))
    await bundle_service.first_started.wait()
    second = asyncio.create_task(service.provision_or_deliver(verified, submission(), now=NOW))
    asyncio.get_running_loop().call_soon(bundle_service.release_first.set)

    first_delivery, second_delivery = await asyncio.gather(first, second)

    assert first_delivery.bundle_id == second_delivery.bundle_id
    assert first_delivery.bundle == second_delivery.bundle
    assert len(bundle_service.calls) == 1


async def test_separate_service_instances_share_one_durable_provisioning_reservation(
    repository,
    google_client,
    cipher,
):
    bundle_service = FakeBundleService(block_first=True)
    second_repository = SubscriptionRepository(repository.db_path)
    second_waiting = asyncio.Event()
    allow_second_retry = asyncio.Event()

    async def wait_for_first_provisioning(_seconds):
        second_waiting.set()
        await allow_second_retry.wait()

    first_service = PaidBundleService(
        bundle_service,
        repository,
        google_client,
        cipher,
        now_provider=lambda: NOW,
    )
    second_service = PaidBundleService(
        bundle_service,
        second_repository,
        google_client,
        cipher,
        provisioning_waiter=wait_for_first_provisioning,
        now_provider=lambda: NOW,
    )
    verified = await verified_purchase(repository)

    first = asyncio.create_task(first_service.provision_or_deliver(verified, submission(), now=NOW))
    await bundle_service.first_started.wait()
    second = asyncio.create_task(
        second_service.provision_or_deliver(verified, submission(), now=NOW)
    )
    await second_waiting.wait()
    bundle_service.release_first.set()
    first_delivery = await first
    allow_second_retry.set()
    second_delivery = await second

    assert first_delivery.bundle_id == second_delivery.bundle_id
    assert first_delivery.bundle == second_delivery.bundle
    assert len(bundle_service.calls) == 1


async def test_cancellation_during_paid_bundle_commit_keeps_persisted_account(
    repository,
    google_client,
    cipher,
    monkeypatch,
):
    class Provisioner:
        async def provision(self, *, username, display_name):
            return ProvisionResult(
                bundle=SyncBundle.decode(ENCODED_BUNDLE),
                user_mxid=f"@{username}:example.com",
                room_id="!paid:example.com",
                server_name="example.com",
            )

    admin_client = FakeReaperAdmin()
    bundle_service = BundleService(Provisioner(), repository, admin_client)
    service = PaidBundleService(
        bundle_service,
        repository,
        google_client,
        cipher,
        now_provider=lambda: NOW,
    )
    verified = await verified_purchase(repository)
    write_started = asyncio.Event()
    allow_write = threading.Event()
    loop = asyncio.get_running_loop()
    original_store = repository._store_paid_bundle_sync

    def blocked_store(**kwargs):
        loop.call_soon_threadsafe(write_started.set)
        allow_write.wait()
        return original_store(**kwargs)

    monkeypatch.setattr(repository, "_store_paid_bundle_sync", blocked_store)
    provisioning = asyncio.create_task(
        service.provision_or_deliver(verified, submission(), now=NOW)
    )
    await write_started.wait()
    provisioning.cancel()
    allow_write.set()

    with pytest.raises(asyncio.CancelledError):
        await provisioning

    claim = await repository.get_bundle_claim_for_entitlement("entitlement-one")
    assert claim is not None
    assert await repository.get(claim.bundle_id) is not None
    assert admin_client.deactivated == []


async def test_stale_provisioning_takeover_uses_fenced_matrix_localpart(
    repository,
    google_client,
    cipher,
):
    class BlockingProvisioner:
        def __init__(self):
            self.calls = []
            self.first_started = asyncio.Event()
            self.release_first = asyncio.Event()

        async def provision(self, *, username, display_name):
            self.calls.append(username)
            if len(self.calls) == 1:
                self.first_started.set()
                await self.release_first.wait()
            encoded = SyncBundle(
                home_server="https://matrix.example.com",
                user=f"@{username}:example.com",
                password=f"password-{username}",
                room_id=f"!{username}:example.com",
                kind=BundleKind.PROVISIONED,
            ).encode()
            return ProvisionResult(
                bundle=SyncBundle.decode(encoded),
                user_mxid=f"@{username}:example.com",
                room_id=f"!{username}:example.com",
                server_name="example.com",
            )

    provisioner = BlockingProvisioner()
    admin_client = FakeReaperAdmin()
    bundle_service = BundleService(provisioner, repository, admin_client)
    current_time = NOW
    first_service = PaidBundleService(
        bundle_service,
        repository,
        google_client,
        cipher,
        now_provider=lambda: current_time,
    )
    second_service = PaidBundleService(
        bundle_service,
        SubscriptionRepository(repository.db_path),
        google_client,
        cipher,
        now_provider=lambda: current_time,
    )
    verified = await verified_purchase(repository)
    first = asyncio.create_task(first_service.provision_or_deliver(verified, submission(), now=NOW))
    await provisioner.first_started.wait()

    # The paid reservation and the lower-level username claim have the same
    # production TTL. Model both expiring while the first Synapse call is still
    # in flight, which is the window where an unfenced replacement can reuse
    # the same Matrix account and have the stale worker deactivate it.
    conn = repository._connect()
    try:
        conn.execute(
            "UPDATE provisioning_claims SET claimed_at = ? WHERE username = ?",
            ((NOW - timedelta(days=1)).isoformat(), "sync_entitlementone"),
        )
        conn.commit()
    finally:
        conn.close()

    current_time = NOW + timedelta(minutes=5)
    winner = await second_service.provision_or_deliver(
        verified,
        submission(),
        now=current_time,
    )
    provisioner.release_first.set()

    with pytest.raises(BundleClaimConflictException):
        await first

    first_username, winner_username = provisioner.calls
    assert first_username == "sync_entitlementone"
    assert winner_username.startswith(first_username)
    assert winner_username != first_username
    assert SyncBundle.decode(winner.bundle).user == f"@{winner_username}:example.com"
    stored_user = await repository.get(winner.bundle_id)
    assert stored_user.user_mxid == f"@{winner_username}:example.com"
    assert admin_client.deactivated == [f"@{first_username}:example.com"]
    assert stored_user.user_mxid not in admin_client.deactivated


async def test_busy_cross_process_reservation_returns_retryable_conflict_without_provisioning(
    repository,
    google_client,
    cipher,
):
    bundle_service = FakeBundleService()
    verified = await verified_purchase(repository)
    assert await repository.reserve_paid_bundle_provisioning(
        "entitlement-one",
        token_fingerprint=verified.subscription.token_fingerprint,
        operation_token="other-process",
        now=NOW,
        stale_before=NOW - timedelta(minutes=5),
    )
    service = PaidBundleService(
        bundle_service,
        repository,
        google_client,
        cipher,
        provisioning_wait_seconds=0,
        now_provider=lambda: NOW,
    )

    with pytest.raises(BundleClaimConflictException, match="already in progress"):
        await service.provision_or_deliver(verified, submission(), now=NOW)

    assert bundle_service.calls == []


@pytest.mark.parametrize(
    ("kwargs", "message"),
    [
        ({"provisioning_wait_seconds": -1}, "wait"),
        ({"provisioning_poll_seconds": 0}, "poll interval"),
        ({"provisioning_operation_timeout": timedelta(0)}, "operation timeout"),
    ],
)
def test_paid_provisioning_timing_configuration_is_validated(
    bundle_service,
    repository,
    google_client,
    cipher,
    kwargs,
    message,
):
    with pytest.raises(ValueError, match=message):
        PaidBundleService(
            bundle_service,
            repository,
            google_client,
            cipher,
            **kwargs,
        )


async def test_abandoned_claim_is_replaced_by_fresh_bundle(
    service,
    repository,
    bundle_service,
):
    verified = await verified_purchase(repository)
    abandoned = await service.provision_or_deliver(verified, submission(), now=NOW)
    await repository.revoke(abandoned.bundle_id, "claim expired")
    await repository.abandon_bundle_claim(
        abandoned.bundle_id,
        now=NOW + timedelta(days=1),
    )
    current = await repository.get_current_subscription("entitlement-one")

    replacement = await service.provision_or_deliver(
        VerifiedPurchaseResult(
            subscription=current,
            request_hash="replacement-request-hash",
            claim_secret_hash=SecretHasher().hash("replacement-claim-secret"),
        ),
        submission(claim_secret="replacement-claim-secret"),
        now=NOW + timedelta(days=1),
    )

    assert replacement.bundle_id != abandoned.bundle_id
    assert replacement.bundle == ENCODED_BUNDLE
    assert len(bundle_service.calls) == 2
    assert (await repository.get(abandoned.bundle_id)).status.value == "revoked"


async def test_admin_revoked_claim_cannot_be_reprovisioned(
    service,
    repository,
    bundle_service,
):
    verified = await verified_purchase(repository)
    revoked = await service.provision_or_deliver(verified, submission(), now=NOW)
    await repository.revoke(revoked.bundle_id, "revoked by administrator")

    with pytest.raises(BundleClaimConflictException, match="terminal"):
        await service.provision_or_deliver(
            verified,
            submission(),
            now=NOW + timedelta(minutes=1),
        )

    claim = await repository.get_bundle_claim_for_entitlement("entitlement-one")
    current = await repository.get_current_subscription("entitlement-one")
    assert claim.bundle_id == revoked.bundle_id
    assert claim.destroyed_at is not None
    assert current.bundle_id == revoked.bundle_id
    assert len(bundle_service.calls) == 1


async def test_replacement_purchase_reauthorizes_pending_escrow(
    service,
    repository,
    bundle_service,
):
    original = await verified_purchase(repository)
    first = await service.provision_or_deliver(original, submission(), now=NOW)
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
            start_time=NOW + timedelta(minutes=30),
            current_period_end=NOW + timedelta(days=395),
            grace_deadline=None,
            acknowledgement_state=AcknowledgementState.PENDING,
            binding_verified=True,
            last_verified_at=NOW + timedelta(minutes=30),
            next_reconciliation_at=NOW + timedelta(hours=6, minutes=30),
            linked_token_fingerprint=original.subscription.token_fingerprint,
        ),
        now=NOW + timedelta(minutes=30),
    )
    replacement_verified = VerifiedPurchaseResult(
        subscription=replacement,
        request_hash="replacement-request-hash",
        claim_secret_hash=SecretHasher().hash("replacement-claim-secret"),
    )

    delivered = await service.provision_or_deliver(
        replacement_verified,
        submission(
            base_plan_id="annual",
            purchase_token="replacement-token",
            claim_secret="replacement-claim-secret",
        ),
        now=NOW + timedelta(minutes=30),
    )

    assert delivered.bundle_id == first.bundle_id
    assert delivered.bundle == first.bundle
    assert len(bundle_service.calls) == 1
    with pytest.raises(BundleClaimConflictException, match="Invalid bundle claim secret"):
        await service.deliver_existing_claim(
            entitlement_id="entitlement-one",
            claim_secret="claim-secret",
            now=NOW + timedelta(minutes=30),
        )


async def test_same_purchase_token_cannot_reauthorize_pending_escrow(
    service,
    repository,
    bundle_service,
):
    original = await verified_purchase(repository)
    first = await service.provision_or_deliver(original, submission(), now=NOW)
    same_token = VerifiedPurchaseResult(
        subscription=original.subscription,
        request_hash="second-request-hash",
        claim_secret_hash=SecretHasher().hash("second-claim-secret"),
    )

    with pytest.raises(BundleClaimConflictException, match="Invalid bundle claim secret"):
        await service.provision_or_deliver(
            same_token,
            submission(claim_secret="second-claim-secret"),
            now=NOW + timedelta(minutes=1),
        )

    recovered = await service.deliver_existing_claim(
        entitlement_id="entitlement-one",
        claim_secret="claim-secret",
        now=NOW + timedelta(minutes=1),
    )
    assert recovered.bundle_id == first.bundle_id
    assert recovered.bundle == first.bundle
    assert len(bundle_service.calls) == 1


async def test_stale_predecessor_cannot_rebind_replacement_escrow(
    service,
    repository,
):
    predecessor = await verified_purchase(repository)
    first = await service.provision_or_deliver(predecessor, submission(), now=NOW)
    replacement = await repository.store_verified_subscription(
        refreshed_snapshot(
            predecessor.subscription,
            token_fingerprint="replacement-token-fingerprint",
            encrypted_purchase_token=b"encrypted-replacement-token",
            base_plan_id="annual",
            latest_order_id="GPA.5678",
            acknowledgement_state=AcknowledgementState.PENDING,
            acknowledged_at=None,
            linked_token_fingerprint=predecessor.subscription.token_fingerprint,
            bundle_id=None,
        ),
        now=NOW + timedelta(minutes=1),
    )
    replacement_verified = VerifiedPurchaseResult(
        subscription=replacement,
        request_hash="replacement-request-hash",
        claim_secret_hash=SecretHasher().hash("replacement-claim-secret"),
    )
    await service.provision_or_deliver(
        replacement_verified,
        submission(
            base_plan_id="annual",
            purchase_token="replacement-token",
            claim_secret="replacement-claim-secret",
        ),
        now=NOW + timedelta(minutes=1),
    )

    with pytest.raises(GooglePlayVerificationException, match="no longer current"):
        await service.provision_or_deliver(
            predecessor,
            submission(),
            now=NOW + timedelta(minutes=2),
        )

    recovered = await service.deliver_existing_claim(
        entitlement_id="entitlement-one",
        claim_secret="replacement-claim-secret",
        now=NOW + timedelta(minutes=2),
    )
    assert recovered.bundle_id == first.bundle_id


async def test_occupied_deterministic_username_retries_with_fresh_localpart(
    repository,
    google_client,
    cipher,
):
    bundle_service = FakeBundleService(reject_first_username=True)
    service = PaidBundleService(
        bundle_service,
        repository,
        google_client,
        cipher,
        now_provider=lambda: NOW,
    )
    verified = await verified_purchase(repository)

    delivered = await service.provision_or_deliver(verified, submission(), now=NOW)

    assert delivered.bundle == ENCODED_BUNDLE
    assert len(bundle_service.calls) == 2
    assert bundle_service.calls[0].username == "sync_entitlementone"
    assert bundle_service.calls[1].username.startswith("sync_entitlementone")
    assert bundle_service.calls[1].username != bundle_service.calls[0].username


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


async def test_delivery_retry_rejects_admin_revoked_paid_claim(service, repository):
    verified = await verified_purchase(repository)
    delivered = await service.provision_or_deliver(verified, submission(), now=NOW)

    await repository.revoke(delivered.bundle_id, "leaked")

    with pytest.raises(BundleClaimConflictException, match="terminal"):
        await service.deliver_existing_claim(
            entitlement_id="entitlement-one",
            claim_secret="claim-secret",
            now=NOW + timedelta(minutes=1),
        )

    claim = await repository.get_bundle_claim_for_entitlement("entitlement-one")
    assert claim.encrypted_bundle is None
    assert claim.destroyed_at is not None


async def test_delivery_retry_final_check_rejects_revocation_after_decryption(
    service,
    repository,
):
    verified = await verified_purchase(repository)
    first = await service.provision_or_deliver(verified, submission(), now=NOW)
    delivery = await service.deliver_existing_claim(
        entitlement_id="entitlement-one",
        claim_secret="claim-secret",
        now=NOW + timedelta(minutes=1),
    )

    await repository.revoke(first.bundle_id, "leaked")

    with pytest.raises(BundleClaimConflictException, match="terminal"):
        await service.require_returnable_delivery(
            delivery,
            entitlement_id="entitlement-one",
            now=NOW + timedelta(minutes=2),
        )


async def test_delivery_retry_final_check_rejects_newly_expired_subscription(
    service,
    repository,
):
    verified = await verified_purchase(repository)
    delivery = await service.provision_or_deliver(verified, submission(), now=NOW)
    expired_at = NOW + timedelta(minutes=1)
    await repository.store_verified_subscription(
        replace(
            verified.subscription,
            google_state=GoogleSubscriptionState.EXPIRED,
            entitlement_state=EntitlementState.EXPIRED,
            current_period_end=expired_at,
            last_verified_at=expired_at,
        ),
        now=expired_at,
    )

    with pytest.raises(GooglePlayVerificationException, match="does not currently grant"):
        await service.require_returnable_delivery(
            delivery,
            entitlement_id="entitlement-one",
            now=expired_at,
        )


async def test_admin_revocation_wins_against_inflight_paid_delivery(
    service,
    repository,
    monkeypatch,
):
    verified = await verified_purchase(repository)
    first = await service.provision_or_deliver(verified, submission(), now=NOW)
    authorization_started = asyncio.Event()
    release_authorization = asyncio.Event()
    authorize = service._authorize_claim_secret

    async def blocking_authorize(claim, claim_secret):
        authorization_started.set()
        await release_authorization.wait()
        await authorize(claim, claim_secret)

    monkeypatch.setattr(service, "_authorize_claim_secret", blocking_authorize)
    delivery = asyncio.create_task(
        service.deliver_existing_claim(
            entitlement_id="entitlement-one",
            claim_secret="claim-secret",
            now=NOW + timedelta(minutes=1),
        )
    )
    await authorization_started.wait()

    await repository.revoke(first.bundle_id, "leaked")
    release_authorization.set()

    with pytest.raises(BundleClaimConflictException, match="lease was lost"):
        await delivery

    claim = await repository.get_bundle_claim_for_entitlement("entitlement-one")
    assert claim.encrypted_bundle is None
    assert claim.destroyed_at is not None


async def test_delivery_retry_lease_blocks_reaper_during_secret_verification(
    service,
    repository,
    monkeypatch,
):
    verified = await verified_purchase(repository)
    await service.provision_or_deliver(verified, submission(), now=NOW)
    claim = await repository.get_bundle_claim_for_entitlement("entitlement-one")
    current_time = claim.expires_at - timedelta(seconds=1)
    service._now_provider = lambda: current_time
    authorization_started = asyncio.Event()
    release_authorization = asyncio.Event()
    authorize = service._authorize_claim_secret

    async def blocking_authorize(current_claim, claim_secret):
        authorization_started.set()
        await release_authorization.wait()
        await authorize(current_claim, claim_secret)

    monkeypatch.setattr(service, "_authorize_claim_secret", blocking_authorize)
    delivery = asyncio.create_task(
        service.deliver_existing_claim(
            entitlement_id="entitlement-one",
            claim_secret="claim-secret",
            now=claim.expires_at - timedelta(seconds=1),
        )
    )
    await authorization_started.wait()

    reaper_admin = FakeReaperAdmin()
    reaper = BundleClaimReaper(
        repository,
        reaper_admin,
        now_provider=lambda: claim.expires_at,
    )
    reaped = await reaper.reap_once()
    current_time = claim.expires_at
    release_authorization.set()

    assert reaped == 0
    assert reaper_admin.deactivated == []
    with pytest.raises(BundleClaimConflictException, match="expired"):
        await delivery
    assert (
        await repository.get_bundle_claim_for_entitlement("entitlement-one")
    ).encrypted_bundle is not None


async def test_delivery_retry_rejects_wrong_claim_secret(service, repository):
    verified = await verified_purchase(repository)
    await service.provision_or_deliver(verified, submission(), now=NOW)

    with pytest.raises(BundleClaimConflictException, match="Invalid bundle claim secret"):
        await service.deliver_existing_claim(
            entitlement_id="entitlement-one",
            claim_secret="attacker-secret",
            now=NOW + timedelta(minutes=1),
        )


async def test_delivery_retry_rejects_reserved_claim_without_ciphertext(
    service,
    repository,
    monkeypatch,
):
    verified = await verified_purchase(repository)
    await service.provision_or_deliver(verified, submission(), now=NOW)
    claim = await repository.get_bundle_claim_for_entitlement("entitlement-one")

    async def missing_ciphertext(*_args, **_kwargs):
        return replace(claim, encrypted_bundle=None)

    monkeypatch.setattr(repository, "reserve_bundle_delivery", missing_ciphertext)

    with pytest.raises(BundleClaimConflictException, match="already destroyed"):
        await service.deliver_existing_claim(
            entitlement_id="entitlement-one",
            claim_secret="claim-secret",
            now=NOW + timedelta(minutes=1),
        )


@pytest.mark.parametrize(
    ("state", "period_end"),
    [
        (EntitlementState.SUSPENDED, NOW + timedelta(days=30)),
        (EntitlementState.ACTIVE, NOW + timedelta(minutes=1)),
    ],
)
async def test_delivery_retry_rejects_current_subscription_without_access(
    service,
    repository,
    state,
    period_end,
):
    verified = await verified_purchase(repository)
    first = await service.provision_or_deliver(verified, submission(), now=NOW)
    await repository.store_verified_subscription(
        refreshed_snapshot(
            await repository.get_current_subscription("entitlement-one"),
            entitlement_state=state,
            current_period_end=period_end,
        ),
        now=NOW + timedelta(minutes=1),
    )

    with pytest.raises(GooglePlayVerificationException, match="does not currently grant"):
        await service.deliver_existing_claim(
            entitlement_id="entitlement-one",
            claim_secret="claim-secret",
            now=NOW + timedelta(minutes=1),
        )

    assert (await repository.get_bundle_claim_for_entitlement("entitlement-one")).bundle_id == (
        first.bundle_id
    )


def test_paid_username_is_deterministic_safe_and_bounded():
    username = PaidBundleService._username("ABC-def_123" * 20)

    retry = PaidBundleService._username("ABC-def_123" * 20, retry_suffix="deadbeef")

    assert username.startswith("sync_abcdef123")
    assert len(username) == 64
    assert username.replace("_", "").isalnum()
    assert len(retry) == 64
    assert retry.endswith("deadbeef")
    assert retry != username
