"""Tests proving paid escrow survives until Matrix rotation is verified."""

# ruff: noqa: S106 - explicit non-production credential fixtures

from __future__ import annotations

from datetime import datetime, timedelta, timezone

import pytest
from src.core.exceptions import BundleClaimConflictException
from src.core.subscriptions import (
    AcknowledgementState,
    EntitlementState,
    GoogleSubscriptionState,
    VerifiedSubscription,
)
from src.services.bundle_rotation_service import BundleRotationService
from src.services.paid_bundle_service import rotation_challenge
from src.services.secret_cipher import SecretCipher
from src.services.subscription_identity_service import SubscriptionIdentityService
from src.services.subscription_repository import SubscriptionRepository
from src.services.subscription_security import SecretHasher

from shared.matrix import BundleKind, SyncBundle

pytestmark = pytest.mark.anyio

NOW = datetime(2026, 8, 29, 12, tzinfo=timezone.utc)


class FakeAdminClient:
    def __init__(self):
        self.state = {}
        self.password_is_valid = False
        self.state_calls = 0
        self.password_calls = 0

    async def get_room_state_as_user(self, *_args, **_kwargs):
        self.state_calls += 1
        return self.state

    async def password_authenticates(self, _user_mxid, _password):
        self.password_calls += 1
        return self.password_is_valid


async def setup_claim(repository, identity_service, cipher):
    entitlement = await identity_service.create_entitlement(now=NOW)
    subscription = await repository.store_verified_subscription(
        VerifiedSubscription(
            entitlement_id=entitlement.entitlement_id,
            token_fingerprint="purchase-token",
            encrypted_purchase_token=b"encrypted-token",
            encryption_key_id="test-key",
            package_name="com.matthiasn.lotti",
            product_id="lotti_sync",
            base_plan_id="monthly",
            latest_order_id="GPA.1234",
            google_state=GoogleSubscriptionState.ACTIVE,
            entitlement_state=EntitlementState.ACTIVE,
            start_time=NOW,
            current_period_end=NOW + timedelta(days=30),
            grace_deadline=None,
            acknowledgement_state=AcknowledgementState.ACKNOWLEDGED,
            binding_verified=True,
            last_verified_at=NOW,
            next_reconciliation_at=NOW + timedelta(hours=6),
        ),
        now=NOW,
    )
    bundle_id = "paid-bundle"
    encoded = SyncBundle(
        home_server="https://matrix.example.com",
        user="@sync_paid:example.com",
        password="bootstrap-password",
        room_id="!paid:example.com",
        kind=BundleKind.PROVISIONED,
    ).encode()
    _, claim = await repository.store_paid_bundle(
        token_fingerprint=subscription.token_fingerprint,
        bundle_id=bundle_id,
        username="sync_paid",
        user_mxid="@sync_paid:example.com",
        home_server="https://matrix.example.com",
        server_name="example.com",
        room_id="!paid:example.com",
        display_name="Lotti SYNC",
        bundle_fingerprint="b" * 64,
        notes="Verified Google Play subscription",
        claim_secret_hash=SecretHasher().hash("claim-secret"),
        encrypted_bundle=cipher.encrypt(encoded.encode(), purpose="bundle", record_id=bundle_id),
        encryption_key_id=cipher.key_id,
        expires_at=NOW + timedelta(hours=24),
        now=NOW,
    )
    return entitlement, claim


@pytest.fixture
def dependencies(tmp_path):
    repository = SubscriptionRepository(str(tmp_path / "subscriptions.db"))
    identity_service = SubscriptionIdentityService(
        repository,
        account_binding_key=bytes(range(32)),
        allowed_products={"lotti_sync": frozenset({"monthly", "annual"})},
    )
    admin_client = FakeAdminClient()
    cipher = SecretCipher(key_id="test-key", key=bytes(reversed(range(32))))
    service = BundleRotationService(
        repository,
        identity_service,
        admin_client,
        cipher,
    )
    return repository, identity_service, admin_client, cipher, service


async def test_valid_room_challenge_and_rotated_password_destroy_escrow(dependencies):
    repository, identity_service, admin_client, cipher, service = dependencies
    entitlement, claim = await setup_claim(repository, identity_service, cipher)
    admin_client.state = {
        "challenge": rotation_challenge(
            "claim-secret",
            claim.bundle_id,
        )
    }

    confirmed = await service.confirm_rotation(
        entitlement_id=entitlement.entitlement_id,
        entitlement_auth_secret=entitlement.auth_secret,
        bundle_id=claim.bundle_id,
        claim_secret="claim-secret",
        now=NOW + timedelta(minutes=1),
    )

    user = await repository.get(claim.bundle_id)
    assert confirmed.encrypted_bundle is None
    assert confirmed.confirmed_at == NOW + timedelta(minutes=1)
    assert user.status.value == "rotated"
    assert admin_client.state_calls == 1
    assert admin_client.password_calls == 1


async def test_matching_challenge_is_not_enough_while_password_still_works(
    dependencies,
):
    repository, identity_service, admin_client, cipher, service = dependencies
    entitlement, claim = await setup_claim(repository, identity_service, cipher)
    admin_client.state = {
        "challenge": rotation_challenge(
            "claim-secret",
            claim.bundle_id,
        )
    }
    admin_client.password_is_valid = True

    with pytest.raises(BundleClaimConflictException, match="still authenticates"):
        await service.confirm_rotation(
            entitlement_id=entitlement.entitlement_id,
            entitlement_auth_secret=entitlement.auth_secret,
            bundle_id=claim.bundle_id,
            claim_secret="claim-secret",
            now=NOW + timedelta(minutes=1),
        )

    assert (
        await repository.get_bundle_claim_for_entitlement(entitlement.entitlement_id)
    ).encrypted_bundle is not None


async def test_wrong_room_challenge_never_checks_or_destroys_password(dependencies):
    repository, identity_service, admin_client, cipher, service = dependencies
    entitlement, claim = await setup_claim(repository, identity_service, cipher)
    admin_client.state = {"challenge": "attacker-proof"}

    with pytest.raises(BundleClaimConflictException, match="does not match"):
        await service.confirm_rotation(
            entitlement_id=entitlement.entitlement_id,
            entitlement_auth_secret=entitlement.auth_secret,
            bundle_id=claim.bundle_id,
            claim_secret="claim-secret",
            now=NOW + timedelta(minutes=1),
        )

    assert admin_client.password_calls == 0


async def test_repeated_valid_confirmation_is_idempotent_without_matrix_calls(
    dependencies,
):
    repository, identity_service, admin_client, cipher, service = dependencies
    entitlement, claim = await setup_claim(repository, identity_service, cipher)
    admin_client.state = {
        "challenge": rotation_challenge(
            "claim-secret",
            claim.bundle_id,
        )
    }
    first = await service.confirm_rotation(
        entitlement_id=entitlement.entitlement_id,
        entitlement_auth_secret=entitlement.auth_secret,
        bundle_id=claim.bundle_id,
        claim_secret="claim-secret",
        now=NOW + timedelta(minutes=1),
    )

    second = await service.confirm_rotation(
        entitlement_id=entitlement.entitlement_id,
        entitlement_auth_secret=entitlement.auth_secret,
        bundle_id=claim.bundle_id,
        claim_secret="claim-secret",
        now=NOW + timedelta(minutes=2),
    )

    assert second.destroyed_at == first.destroyed_at
    assert admin_client.state_calls == 1
    assert admin_client.password_calls == 1


async def test_wrong_claim_secret_is_rejected_before_matrix_lookup(dependencies):
    repository, identity_service, admin_client, cipher, service = dependencies
    entitlement, claim = await setup_claim(repository, identity_service, cipher)

    with pytest.raises(BundleClaimConflictException, match="Invalid bundle claim"):
        await service.confirm_rotation(
            entitlement_id=entitlement.entitlement_id,
            entitlement_auth_secret=entitlement.auth_secret,
            bundle_id=claim.bundle_id,
            claim_secret="attacker-secret",
            now=NOW + timedelta(minutes=1),
        )

    assert admin_client.state_calls == 0


async def test_expired_claim_is_rejected_before_matrix_lookup(dependencies):
    repository, identity_service, admin_client, cipher, service = dependencies
    entitlement, claim = await setup_claim(repository, identity_service, cipher)

    with pytest.raises(BundleClaimConflictException, match="expired"):
        await service.confirm_rotation(
            entitlement_id=entitlement.entitlement_id,
            entitlement_auth_secret=entitlement.auth_secret,
            bundle_id=claim.bundle_id,
            claim_secret="claim-secret",
            now=claim.expires_at,
        )

    assert admin_client.state_calls == 0


async def test_missing_provisioned_account_fails_before_matrix_lookup(
    dependencies,
    monkeypatch,
):
    repository, identity_service, admin_client, cipher, service = dependencies
    entitlement, claim = await setup_claim(repository, identity_service, cipher)

    async def missing_user(_bundle_id):
        return None

    monkeypatch.setattr(repository, "get", missing_user)

    with pytest.raises(BundleClaimConflictException, match="account is missing"):
        await service.confirm_rotation(
            entitlement_id=entitlement.entitlement_id,
            entitlement_auth_secret=entitlement.auth_secret,
            bundle_id=claim.bundle_id,
            claim_secret="claim-secret",
            now=NOW + timedelta(minutes=1),
        )

    assert admin_client.state_calls == 0
