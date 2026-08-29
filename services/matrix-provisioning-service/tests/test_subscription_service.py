"""Tests for the end-to-end Play verification and persistence transaction."""

# ruff: noqa: S105,S106 - explicit non-production token and secret fixtures

from __future__ import annotations

import asyncio
import sqlite3
from dataclasses import replace
from datetime import datetime, timedelta, timezone

import pytest
from src.core.exceptions import (
    EntitlementAuthenticationException,
    GooglePlayVerificationException,
    InvalidSubscriptionProductException,
    PurchaseIntentExpiredException,
    PurchaseIntentNotFoundException,
    PurchaseIntentReplayException,
    PurchaseVerificationRateLimitException,
)
from src.core.subscriptions import (
    AcknowledgementState,
    EntitlementState,
    GooglePlayLineItem,
    GooglePlaySnapshot,
    GoogleSubscriptionState,
    PurchaseSubmission,
)
from src.services.secret_cipher import SecretCipher
from src.services.subscription_identity_service import SubscriptionIdentityService
from src.services.subscription_repository import SubscriptionRepository
from src.services.subscription_security import (
    canonical_purchase_request_hash,
    fingerprint,
)
from src.services.subscription_service import SubscriptionService

pytestmark = pytest.mark.anyio

NOW = datetime(2026, 8, 29, 12, tzinfo=timezone.utc)
PACKAGE = "com.matthiasn.lotti"
CERTIFICATE_DIGEST = "release-certificate-sha256"


class MutableClock:
    def __init__(self, value):
        self.value = value

    def __call__(self):
        return self.value


class FakeGooglePlayClient:
    def __init__(self):
        self.integrity_payload = None
        self.snapshot = None
        self.decoded_tokens = []
        self.queried_tokens = []
        self.acknowledgements = []

    async def decode_integrity_token(self, package_name, integrity_token):
        self.decoded_tokens.append((package_name, integrity_token))
        return self.integrity_payload

    async def get_subscription(self, package_name, purchase_token):
        self.queried_tokens.append((package_name, purchase_token))
        return self.snapshot

    async def acknowledge_subscription(self, package_name, product_id, purchase_token):
        self.acknowledgements.append((package_name, product_id, purchase_token))


@pytest.fixture
def repository(tmp_path):
    return SubscriptionRepository(str(tmp_path / "subscriptions.db"))


@pytest.fixture
def identity_service(repository):
    return SubscriptionIdentityService(
        repository,
        account_binding_key=bytes(range(32)),
        allowed_products={"lotti_sync": frozenset({"monthly", "annual"})},
    )


@pytest.fixture
def google_client():
    return FakeGooglePlayClient()


@pytest.fixture
def cipher():
    return SecretCipher(key_id="test-key", key=bytes(reversed(range(32))))


@pytest.fixture
def clock():
    return MutableClock(NOW)


@pytest.fixture
def service(repository, identity_service, google_client, cipher, clock):
    return SubscriptionService(
        repository,
        identity_service,
        google_client,
        cipher,
        package_name=PACKAGE,
        allowed_products={"lotti_sync": frozenset({"monthly", "annual"})},
        certificate_sha256_digests=frozenset({CERTIFICATE_DIGEST}),
        now_provider=clock,
    )


async def purchase_context(identity_service, google_client, **submission_overrides):
    entitlement = await identity_service.create_entitlement(
        client_identifier="203.0.113.1",
        now=NOW,
    )
    intent = await identity_service.create_purchase_intent(
        entitlement_id=entitlement.entitlement_id,
        auth_secret=entitlement.auth_secret,
        product_id="lotti_sync",
        base_plan_id="monthly",
        now=NOW,
    )
    values = {
        "package_name": PACKAGE,
        "product_id": "lotti_sync",
        "base_plan_id": "monthly",
        "entitlement_id": entitlement.entitlement_id,
        "purchase_intent_id": intent.intent_id,
        "purchase_token": "purchase-token",
        "intent_secret": intent.intent_secret,
        "claim_secret": "claim-secret",
        "integrity_token": "signed-integrity-token",
    }
    values.update(submission_overrides)
    submission = PurchaseSubmission(**values)
    request_hash = canonical_purchase_request_hash(
        package_name=submission.package_name,
        product_id=submission.product_id,
        base_plan_id=submission.base_plan_id,
        entitlement_id=submission.entitlement_id,
        purchase_intent_id=submission.purchase_intent_id,
        purchase_token=submission.purchase_token,
        intent_secret=submission.intent_secret,
        claim_secret=submission.claim_secret,
    )
    google_client.integrity_payload = {
        "tokenPayloadExternal": {
            "requestDetails": {
                "requestPackageName": PACKAGE,
                "requestHash": request_hash,
                "timestampMillis": str(int(NOW.timestamp() * 1000)),
            },
            "appIntegrity": {
                "appRecognitionVerdict": "PLAY_RECOGNIZED",
                "packageName": PACKAGE,
                "certificateSha256Digest": [CERTIFICATE_DIGEST],
            },
            "accountDetails": {"appLicensingVerdict": "LICENSED"},
            "deviceIntegrity": {"deviceRecognitionVerdict": ["MEETS_DEVICE_INTEGRITY"]},
        }
    }
    google_client.snapshot = GooglePlaySnapshot(
        state=GoogleSubscriptionState.ACTIVE,
        acknowledgement_state=AcknowledgementState.PENDING,
        line_items=(
            GooglePlayLineItem(
                product_id="lotti_sync",
                base_plan_id="monthly",
                expiry_time=NOW + timedelta(days=30),
                latest_successful_order_id="GPA.1234",
            ),
        ),
        start_time=NOW,
        linked_purchase_token=None,
        obfuscated_external_account_id=entitlement.obfuscated_account_id,
        obfuscated_external_profile_id=entitlement.obfuscated_account_id,
        test_purchase=False,
        expired_purchase_token=None,
        expired_obfuscated_external_account_id=None,
        expired_obfuscated_external_profile_id=None,
    )
    return entitlement, submission


async def test_valid_purchase_is_bound_and_stored_with_encrypted_token(
    service,
    identity_service,
    google_client,
    repository,
    cipher,
):
    entitlement, submission = await purchase_context(identity_service, google_client)

    result = await service.verify_purchase(
        submission,
        entitlement_auth_secret=entitlement.auth_secret,
        now=NOW,
    )

    stored = await repository.get_subscription_by_token(fingerprint("purchase-token"))
    assert result.subscription == stored
    assert stored.entitlement_state is EntitlementState.ACTIVE
    assert stored.binding_verified is True
    assert stored.next_reconciliation_at == NOW + timedelta(hours=6)
    assert b"purchase-token" not in stored.encrypted_purchase_token
    assert (
        cipher.decrypt(
            stored.encrypted_purchase_token,
            purpose="purchase-token",
            record_id=stored.token_fingerprint,
        )
        == b"purchase-token"
    )
    assert result.claim_secret_hash != "claim-secret"
    assert google_client.decoded_tokens == [(PACKAGE, "signed-integrity-token")]
    assert google_client.queried_tokens == [(PACKAGE, "purchase-token")]


async def test_purchase_verification_attempt_limit_rejects_replay_before_auth_and_google(
    repository,
    identity_service,
    google_client,
    cipher,
    clock,
    monkeypatch,
):
    entitlement, submission = await purchase_context(identity_service, google_client)
    service = SubscriptionService(
        repository,
        identity_service,
        google_client,
        cipher,
        package_name=PACKAGE,
        allowed_products={"lotti_sync": frozenset({"monthly", "annual"})},
        certificate_sha256_digests=frozenset({CERTIFICATE_DIGEST}),
        purchase_verification_attempt_limit=1,
        purchase_verification_attempt_window=timedelta(minutes=15),
        now_provider=clock,
    )
    authenticate_calls = 0
    original_authenticate = identity_service.authenticate

    async def counted_authenticate(entitlement_id, auth_secret):
        nonlocal authenticate_calls
        authenticate_calls += 1
        return await original_authenticate(entitlement_id, auth_secret)

    monkeypatch.setattr(identity_service, "authenticate", counted_authenticate)

    await service.verify_purchase(
        submission,
        entitlement_auth_secret=entitlement.auth_secret,
        now=NOW,
    )
    with pytest.raises(PurchaseVerificationRateLimitException) as error:
        await service.verify_purchase(
            submission,
            entitlement_auth_secret=entitlement.auth_secret,
            now=NOW + timedelta(seconds=1),
        )

    assert error.value.retry_after_seconds == 899
    assert authenticate_calls == 1
    assert google_client.decoded_tokens == [(PACKAGE, "signed-integrity-token")]
    assert google_client.queried_tokens == [(PACKAGE, "purchase-token")]
    connection = sqlite3.connect(repository.db_path)
    try:
        attempts = dict(
            connection.execute(
                "SELECT operation_kind, request_count FROM subscription_attempt_limits "
                "WHERE entitlement_id = ?",
                (entitlement.entitlement_id,),
            ).fetchall()
        )
    finally:
        connection.close()
    assert attempts == {"purchase_intent": 1, "purchase_verification": 1}


async def test_purchase_verification_does_not_track_unknown_entitlements(
    service,
    identity_service,
    google_client,
    repository,
    monkeypatch,
):
    _, submission = await purchase_context(identity_service, google_client)

    async def unexpected_authentication(_entitlement_id, _auth_secret):
        pytest.fail("Unknown entitlements must be rejected before scrypt")

    monkeypatch.setattr(identity_service, "authenticate", unexpected_authentication)

    with pytest.raises(EntitlementAuthenticationException):
        await service.verify_purchase(
            replace(submission, entitlement_id="unknown-entitlement"),
            entitlement_auth_secret="unknown-secret",
            now=NOW,
        )

    assert google_client.decoded_tokens == []
    connection = sqlite3.connect(repository.db_path)
    try:
        verification_attempts = connection.execute(
            "SELECT COUNT(*) FROM subscription_attempt_limits "
            "WHERE operation_kind = 'purchase_verification'"
        ).fetchone()[0]
    finally:
        connection.close()
    assert verification_attempts == 0


async def test_grace_purchase_uses_google_expiry_as_reconciliation_deadline(
    service,
    identity_service,
    google_client,
):
    entitlement, submission = await purchase_context(identity_service, google_client)
    deadline = NOW + timedelta(hours=2)
    google_client.snapshot = replace(
        google_client.snapshot,
        state=GoogleSubscriptionState.IN_GRACE_PERIOD,
        line_items=(replace(google_client.snapshot.line_items[0], expiry_time=deadline),),
    )

    result = await service.verify_purchase(
        submission,
        entitlement_auth_secret=entitlement.auth_secret,
        now=NOW,
    )

    assert result.subscription.entitlement_state is EntitlementState.GRACE
    assert result.subscription.grace_deadline == deadline
    assert result.subscription.next_reconciliation_at == deadline


@pytest.mark.parametrize(
    ("section", "field", "value"),
    [
        ("requestDetails", "requestPackageName", "other.package"),
        ("requestDetails", "requestHash", "tampered-request"),
        ("appIntegrity", "appRecognitionVerdict", "UNRECOGNIZED_VERSION"),
        ("appIntegrity", "packageName", "other.package"),
        ("appIntegrity", "certificateSha256Digest", ["other-certificate"]),
        ("accountDetails", "appLicensingVerdict", "UNLICENSED"),
        ("deviceIntegrity", "deviceRecognitionVerdict", []),
    ],
)
async def test_integrity_verdict_must_match_every_security_boundary(
    service,
    identity_service,
    google_client,
    section,
    field,
    value,
):
    entitlement, submission = await purchase_context(identity_service, google_client)
    google_client.integrity_payload["tokenPayloadExternal"][section][field] = value

    with pytest.raises(GooglePlayVerificationException):
        await service.verify_purchase(
            submission,
            entitlement_auth_secret=entitlement.auth_secret,
            now=NOW,
        )

    assert google_client.queried_tokens == []


@pytest.mark.parametrize(
    "timestamp",
    [
        NOW - timedelta(minutes=5, milliseconds=1),
        NOW + timedelta(seconds=30, milliseconds=1),
    ],
)
async def test_integrity_verdict_must_be_fresh(
    service,
    identity_service,
    google_client,
    timestamp,
):
    entitlement, submission = await purchase_context(identity_service, google_client)
    google_client.integrity_payload["tokenPayloadExternal"]["requestDetails"]["timestampMillis"] = (
        str(int(timestamp.timestamp() * 1000))
    )

    with pytest.raises(GooglePlayVerificationException):
        await service.verify_purchase(
            submission,
            entitlement_auth_secret=entitlement.auth_secret,
            now=NOW,
        )


async def test_google_product_must_match_requested_product(
    service,
    identity_service,
    google_client,
):
    entitlement, submission = await purchase_context(identity_service, google_client)
    google_client.snapshot = replace(
        google_client.snapshot,
        line_items=(replace(google_client.snapshot.line_items[0], base_plan_id="annual"),),
    )

    with pytest.raises(GooglePlayVerificationException, match="line item"):
        await service.verify_purchase(
            submission,
            entitlement_auth_secret=entitlement.auth_secret,
            now=NOW,
        )


async def test_google_account_binding_must_match_entitlement(
    service,
    identity_service,
    google_client,
):
    entitlement, submission = await purchase_context(identity_service, google_client)
    google_client.snapshot = replace(
        google_client.snapshot,
        obfuscated_external_account_id="attacker-binding",
    )

    with pytest.raises(GooglePlayVerificationException, match="not bound"):
        await service.verify_purchase(
            submission,
            entitlement_auth_secret=entitlement.auth_secret,
            now=NOW,
        )


async def test_production_rejects_test_purchase(
    service,
    identity_service,
    google_client,
):
    entitlement, submission = await purchase_context(identity_service, google_client)
    google_client.snapshot = replace(google_client.snapshot, test_purchase=True)

    with pytest.raises(GooglePlayVerificationException, match="Test purchases"):
        await service.verify_purchase(
            submission,
            entitlement_auth_secret=entitlement.auth_secret,
            now=NOW,
        )


async def test_reusing_intent_with_a_different_purchase_is_rejected(
    service,
    identity_service,
    google_client,
):
    entitlement, submission = await purchase_context(identity_service, google_client)
    await service.verify_purchase(
        submission,
        entitlement_auth_secret=entitlement.auth_secret,
        now=NOW,
    )
    changed = replace(submission, purchase_token="stolen-second-token")
    google_client.integrity_payload["tokenPayloadExternal"]["requestDetails"]["requestHash"] = (
        canonical_purchase_request_hash(
            package_name=changed.package_name,
            product_id=changed.product_id,
            base_plan_id=changed.base_plan_id,
            entitlement_id=changed.entitlement_id,
            purchase_intent_id=changed.purchase_intent_id,
            purchase_token=changed.purchase_token,
            intent_secret=changed.intent_secret,
            claim_secret=changed.claim_secret,
        )
    )

    with pytest.raises(PurchaseIntentReplayException):
        await service.verify_purchase(
            changed,
            entitlement_auth_secret=entitlement.auth_secret,
            now=NOW + timedelta(minutes=1),
        )


async def test_unconfigured_requested_plan_is_rejected_before_google(
    service,
    identity_service,
    google_client,
):
    entitlement, submission = await purchase_context(identity_service, google_client)
    changed = replace(submission, base_plan_id="weekly")

    with pytest.raises(InvalidSubscriptionProductException):
        await service.verify_purchase(
            changed,
            entitlement_auth_secret=entitlement.auth_secret,
            now=NOW,
        )

    assert google_client.decoded_tokens == []


async def test_unexpected_package_is_rejected_before_google(
    service,
    identity_service,
    google_client,
):
    entitlement, submission = await purchase_context(identity_service, google_client)

    with pytest.raises(GooglePlayVerificationException, match="package"):
        await service.verify_purchase(
            replace(submission, package_name="attacker.package"),
            entitlement_auth_secret=entitlement.auth_secret,
            now=NOW,
        )

    assert google_client.decoded_tokens == []


async def test_unknown_and_expired_purchase_intents_fail_before_google(
    service,
    identity_service,
    google_client,
):
    entitlement, submission = await purchase_context(identity_service, google_client)

    with pytest.raises(PurchaseIntentNotFoundException):
        await service.verify_purchase(
            replace(submission, purchase_intent_id="missing-intent"),
            entitlement_auth_secret=entitlement.auth_secret,
            now=NOW,
        )
    with pytest.raises(PurchaseIntentExpiredException):
        await service.verify_purchase(
            submission,
            entitlement_auth_secret=entitlement.auth_secret,
            now=NOW + timedelta(minutes=15),
        )

    assert google_client.decoded_tokens == []


async def test_known_rtdn_token_is_requeried_and_updates_authoritative_state(
    service,
    identity_service,
    google_client,
    repository,
    clock,
):
    entitlement, initial = await purchase_context(identity_service, google_client)
    await service.verify_purchase(
        initial,
        entitlement_auth_secret=entitlement.auth_secret,
        now=NOW,
    )
    google_client.queried_tokens.clear()
    google_client.snapshot = replace(
        google_client.snapshot,
        state=GoogleSubscriptionState.ON_HOLD,
    )
    clock.value = NOW + timedelta(hours=1)

    refreshed = await service.refresh_known_purchase(
        initial.purchase_token,
        now=NOW + timedelta(hours=1),
    )

    assert refreshed.entitlement_state is EntitlementState.SUSPENDED
    assert refreshed.last_verified_at == NOW + timedelta(hours=1)
    assert google_client.queried_tokens == [(PACKAGE, initial.purchase_token)]
    assert await repository.get_current_subscription(entitlement.entitlement_id) == refreshed


async def test_authoritative_refresh_reencrypts_token_with_active_key(
    service,
    identity_service,
    google_client,
    repository,
    cipher,
    clock,
):
    entitlement, initial = await purchase_context(identity_service, google_client)
    original = await service.verify_purchase(
        initial,
        entitlement_auth_secret=entitlement.auth_secret,
        now=NOW,
    )
    rotated_cipher = SecretCipher(
        key_id="rotated-key",
        key=bytes(range(32)),
        decryption_keys={cipher.key_id: bytes(reversed(range(32)))},
    )
    rotated_service = SubscriptionService(
        repository,
        identity_service,
        google_client,
        rotated_cipher,
        package_name=PACKAGE,
        allowed_products={"lotti_sync": frozenset({"monthly", "annual"})},
        certificate_sha256_digests=frozenset({CERTIFICATE_DIGEST}),
        now_provider=clock,
    )
    clock.value = NOW + timedelta(hours=1)

    refreshed = await rotated_service.refresh_known_purchase(
        initial.purchase_token,
        now=NOW + timedelta(hours=1),
    )

    assert refreshed.encryption_key_id == "rotated-key"
    assert refreshed.encrypted_purchase_token != original.subscription.encrypted_purchase_token
    assert (
        rotated_cipher.decrypt(
            refreshed.encrypted_purchase_token,
            purpose="purchase-token",
            record_id=refreshed.token_fingerprint,
            key_id="rotated-key",
        )
        == initial.purchase_token.encode()
    )


async def test_authoritative_refresh_recovers_pending_acknowledgement_after_provisioning(
    service,
    identity_service,
    google_client,
    repository,
    clock,
):
    entitlement, initial = await purchase_context(identity_service, google_client)
    original = await service.verify_purchase(
        initial,
        entitlement_auth_secret=entitlement.auth_secret,
        now=NOW,
    )
    provisioning_token = "subscription-service-test"
    assert await repository.reserve_paid_bundle_provisioning(
        entitlement.entitlement_id,
        token_fingerprint=original.subscription.token_fingerprint,
        operation_token=provisioning_token,
        now=NOW,
        stale_before=NOW - timedelta(minutes=5),
    )
    await repository.store_paid_bundle(
        token_fingerprint=original.subscription.token_fingerprint,
        provisioning_token=provisioning_token,
        bundle_id="paid-bundle",
        username="sync_paid",
        user_mxid="@sync_paid:example.com",
        home_server="https://matrix.example.com",
        server_name="example.com",
        room_id="!paid:example.com",
        display_name="Lotti SYNC",
        bundle_fingerprint="b" * 64,
        notes="Verified Google Play subscription",
        claim_secret_hash="claim-hash",
        encrypted_bundle=b"encrypted-bundle",
        encryption_key_id="test-key",
        expires_at=NOW + timedelta(hours=24),
        now=NOW,
    )
    clock.value = NOW + timedelta(minutes=1)

    refreshed = await service.refresh_known_purchase(
        initial.purchase_token,
        now=NOW + timedelta(minutes=1),
    )

    assert google_client.acknowledgements == [(PACKAGE, "lotti_sync", initial.purchase_token)]
    assert refreshed.acknowledgement_state is AcknowledgementState.ACKNOWLEDGED
    assert refreshed.acknowledged_at == NOW + timedelta(minutes=1)


async def test_later_google_response_wins_even_when_its_request_started_first(
    service,
    identity_service,
    google_client,
    repository,
    clock,
    monkeypatch,
):
    entitlement, initial = await purchase_context(identity_service, google_client)
    original = await service.verify_purchase(
        initial,
        entitlement_auth_secret=entitlement.auth_secret,
        now=NOW,
    )
    active = google_client.snapshot
    on_hold = replace(active, state=GoogleSubscriptionState.ON_HOLD)
    first_started = asyncio.Event()
    release_first = asyncio.Event()
    response_count = 0

    async def racing_get_subscription(_package_name, _purchase_token):
        nonlocal response_count
        response_count += 1
        if response_count == 1:
            first_started.set()
            await release_first.wait()
            clock.value = NOW + timedelta(minutes=3)
            return active
        clock.value = NOW + timedelta(minutes=2)
        return on_hold

    monkeypatch.setattr(google_client, "get_subscription", racing_get_subscription)
    slower_first_request = asyncio.create_task(
        service.refresh_known_purchase(
            initial.purchase_token,
            now=NOW + timedelta(minutes=1),
        )
    )
    await first_started.wait()

    faster_second_request = await service.refresh_known_purchase(
        initial.purchase_token,
        now=NOW + timedelta(minutes=2),
    )
    release_first.set()
    later_response = await slower_first_request
    stored = await repository.get_subscription_by_token(original.subscription.token_fingerprint)

    assert faster_second_request.entitlement_state is EntitlementState.SUSPENDED
    assert later_response.entitlement_state is EntitlementState.ACTIVE
    assert stored.entitlement_state is EntitlementState.ACTIVE
    assert stored.last_verified_at == NOW + timedelta(minutes=3)


async def test_unknown_rtdn_token_cannot_create_or_rebind_entitlement(
    service,
    google_client,
):
    with pytest.raises(GooglePlayVerificationException, match="not bound"):
        await service.refresh_known_purchase("unknown-token", now=NOW)

    assert google_client.queried_tokens == []


async def test_rtdn_binding_mismatch_does_not_modify_stored_state(
    service,
    identity_service,
    google_client,
    repository,
):
    entitlement, initial = await purchase_context(identity_service, google_client)
    original = await service.verify_purchase(
        initial,
        entitlement_auth_secret=entitlement.auth_secret,
        now=NOW,
    )
    google_client.snapshot = replace(
        google_client.snapshot,
        state=GoogleSubscriptionState.ON_HOLD,
        obfuscated_external_account_id="different-account",
    )

    with pytest.raises(GooglePlayVerificationException, match="not bound"):
        await service.refresh_known_purchase(
            initial.purchase_token,
            now=NOW + timedelta(hours=1),
        )

    stored = await repository.get_subscription_by_token(original.subscription.token_fingerprint)
    assert stored.entitlement_state is EntitlementState.ACTIVE


async def test_refresh_fails_closed_if_entitlement_record_is_missing(
    service,
    identity_service,
    google_client,
    repository,
    monkeypatch,
):
    entitlement, initial = await purchase_context(identity_service, google_client)
    await service.verify_purchase(
        initial,
        entitlement_auth_secret=entitlement.auth_secret,
        now=NOW,
    )

    async def missing_entitlement(_entitlement_id):
        return None

    monkeypatch.setattr(repository, "get_entitlement", missing_entitlement)

    with pytest.raises(GooglePlayVerificationException, match="entitlement is missing"):
        await service.refresh_known_purchase(initial.purchase_token, now=NOW)


async def test_refresh_rejects_test_purchase_in_production(
    service,
    identity_service,
    google_client,
):
    entitlement, initial = await purchase_context(identity_service, google_client)
    await service.verify_purchase(
        initial,
        entitlement_auth_secret=entitlement.auth_secret,
        now=NOW,
    )
    google_client.snapshot = replace(google_client.snapshot, test_purchase=True)

    with pytest.raises(GooglePlayVerificationException, match="Test purchases"):
        await service.refresh_known_purchase(initial.purchase_token, now=NOW)


@pytest.mark.parametrize(
    "changed",
    [
        {"base_plan_id": "annual"},
        {"intent_secret": "wrong-intent-secret"},
    ],
)
async def test_submission_must_match_one_time_purchase_intent(
    service,
    identity_service,
    google_client,
    changed,
):
    entitlement, submission = await purchase_context(identity_service, google_client)

    with pytest.raises(GooglePlayVerificationException, match="Purchase intent"):
        await service.verify_purchase(
            replace(submission, **changed),
            entitlement_auth_secret=entitlement.auth_secret,
            now=NOW,
        )

    assert google_client.decoded_tokens == []


async def test_incomplete_integrity_payload_is_rejected_before_publisher_query(
    service,
    identity_service,
    google_client,
):
    entitlement, submission = await purchase_context(identity_service, google_client)
    del google_client.integrity_payload["tokenPayloadExternal"]["deviceIntegrity"]

    with pytest.raises(GooglePlayVerificationException, match="incomplete"):
        await service.verify_purchase(
            submission,
            entitlement_auth_secret=entitlement.auth_secret,
            now=NOW,
        )

    assert google_client.queried_tokens == []


async def test_out_of_app_resubscription_accepts_matching_expired_binding(
    service,
    identity_service,
    google_client,
):
    entitlement, submission = await purchase_context(identity_service, google_client)
    google_client.snapshot = replace(
        google_client.snapshot,
        obfuscated_external_account_id=None,
        obfuscated_external_profile_id=None,
        expired_purchase_token=None,
        expired_obfuscated_external_account_id=entitlement.obfuscated_account_id,
    )

    result = await service.verify_purchase(
        submission,
        entitlement_auth_secret=entitlement.auth_secret,
        now=NOW,
    )

    assert result.subscription.binding_verified is True


def test_signing_certificate_configuration_is_required(
    repository,
    identity_service,
    google_client,
    cipher,
):
    with pytest.raises(ValueError, match="signing certificate"):
        SubscriptionService(
            repository,
            identity_service,
            google_client,
            cipher,
            package_name=PACKAGE,
            allowed_products={"lotti_sync": frozenset({"monthly"})},
            certificate_sha256_digests=frozenset(),
        )


@pytest.mark.parametrize(
    ("limit", "window", "message"),
    [
        (0, timedelta(minutes=15), "attempt limit"),
        (1, timedelta(0), "attempt window"),
    ],
)
def test_purchase_verification_rate_limit_configuration_must_be_positive(
    repository,
    identity_service,
    google_client,
    cipher,
    limit,
    window,
    message,
):
    with pytest.raises(ValueError, match=message):
        SubscriptionService(
            repository,
            identity_service,
            google_client,
            cipher,
            package_name=PACKAGE,
            allowed_products={"lotti_sync": frozenset({"monthly"})},
            certificate_sha256_digests=frozenset({CERTIFICATE_DIGEST}),
            purchase_verification_attempt_limit=limit,
            purchase_verification_attempt_window=window,
        )
