"""Tests for entitlement credentials and one-time Billing authorization."""

from __future__ import annotations

import sqlite3
from datetime import datetime, timedelta, timezone

import pytest
from src.core.exceptions import (
    BundleClaimRateLimitException,
    EntitlementAuthenticationException,
    EntitlementRateLimitException,
    InvalidSubscriptionProductException,
    PurchaseIntentRateLimitException,
)
from src.services.subscription_identity_service import SubscriptionIdentityService
from src.services.subscription_repository import SubscriptionRepository
from src.services.subscription_security import SecretHasher

pytestmark = pytest.mark.anyio

NOW = datetime(2026, 8, 29, 12, tzinfo=timezone.utc)


class CountingHasher:
    def __init__(self):
        self.verify_calls = 0

    def hash(self, secret):
        return f"test-hash:{secret}"

    def verify(self, secret, encoded_hash):
        self.verify_calls += 1
        return encoded_hash == f"test-hash:{secret}"


@pytest.fixture
def repository(tmp_path):
    return SubscriptionRepository(str(tmp_path / "subscriptions.db"))


@pytest.fixture
def service(repository):
    return SubscriptionIdentityService(
        repository,
        account_binding_key=bytes(range(32)),
        allowed_products={"lotti_sync": frozenset({"monthly", "annual"})},
    )


async def test_create_entitlement_returns_secret_once_and_persists_only_hash(
    service,
    repository,
):
    credentials = await service.create_entitlement(client_identifier="203.0.113.1", now=NOW)

    stored = await repository.get_entitlement(credentials.entitlement_id)

    assert credentials.auth_secret
    assert credentials.obfuscated_account_id == stored.obfuscated_account_id
    assert credentials.auth_secret not in stored.auth_secret_hash
    assert SecretHasher().verify(credentials.auth_secret, stored.auth_secret_hash)


async def test_entitlement_authentication_rejects_unknown_or_wrong_credentials(
    service,
):
    credentials = await service.create_entitlement(client_identifier="203.0.113.1", now=NOW)

    authenticated = await service.authenticate(
        credentials.entitlement_id,
        credentials.auth_secret,
    )
    assert authenticated.entitlement_id == credentials.entitlement_id

    with pytest.raises(EntitlementAuthenticationException):
        await service.authenticate(credentials.entitlement_id, "wrong-secret")
    with pytest.raises(EntitlementAuthenticationException):
        await service.authenticate("unknown-entitlement", credentials.auth_secret)


async def test_purchase_intent_is_short_lived_and_bound_to_entitlement_and_plan(
    service,
    repository,
):
    credentials = await service.create_entitlement(client_identifier="203.0.113.1", now=NOW)

    issued = await service.create_purchase_intent(
        entitlement_id=credentials.entitlement_id,
        auth_secret=credentials.auth_secret,
        product_id="lotti_sync",
        base_plan_id="annual",
        now=NOW,
    )
    stored = await repository.get_purchase_intent(issued.intent_id)

    assert issued.expires_at == NOW + timedelta(minutes=15)
    assert issued.obfuscated_account_id == credentials.obfuscated_account_id
    assert stored.entitlement_id == credentials.entitlement_id
    assert stored.product_id == "lotti_sync"
    assert stored.base_plan_id == "annual"
    assert issued.intent_secret not in stored.intent_secret_hash
    assert SecretHasher().verify(issued.intent_secret, stored.intent_secret_hash)


async def test_purchase_intent_issuance_is_bounded_and_prunes_expired_replay_state(
    repository,
):
    service = SubscriptionIdentityService(
        repository,
        account_binding_key=bytes(range(32)),
        allowed_products={"lotti_sync": frozenset({"monthly"})},
        purchase_intent_issuance_limit=2,
        purchase_intent_issuance_window=timedelta(minutes=15),
    )
    credentials = await service.create_entitlement(
        client_identifier="203.0.113.1",
        now=NOW,
    )
    values = {
        "entitlement_id": credentials.entitlement_id,
        "auth_secret": credentials.auth_secret,
        "product_id": "lotti_sync",
        "base_plan_id": "monthly",
    }
    first = await service.create_purchase_intent(**values, now=NOW)
    await service.create_purchase_intent(**values, now=NOW + timedelta(seconds=1))
    await repository.consume_purchase_intent(
        intent_id=first.intent_id,
        entitlement_id=credentials.entitlement_id,
        expected_request_hash="request-hash",
        token_fingerprint="token-fingerprint",  # noqa: S106 - fixture fingerprint
        integrity_token_fingerprint="integrity-fingerprint",  # noqa: S106 - fixture
        now=NOW + timedelta(minutes=1),
    )

    with pytest.raises(PurchaseIntentRateLimitException) as error:
        await service.create_purchase_intent(**values, now=NOW + timedelta(minutes=1))

    assert error.value.retry_after_seconds == 840
    after_window = await service.create_purchase_intent(
        **values,
        now=NOW + timedelta(minutes=15),
    )
    assert after_window.intent_id != first.intent_id
    assert await repository.get_purchase_intent(first.intent_id) is None
    connection = sqlite3.connect(repository.db_path)
    try:
        replay_count = connection.execute("SELECT COUNT(*) FROM play_integrity_replays").fetchone()[
            0
        ]
    finally:
        connection.close()
    assert replay_count == 0


async def test_purchase_intent_attempt_limit_rejects_before_secret_verification(
    repository,
):
    hasher = CountingHasher()
    service = SubscriptionIdentityService(
        repository,
        account_binding_key=bytes(range(32)),
        allowed_products={"lotti_sync": frozenset({"monthly"})},
        purchase_intent_attempt_limit=2,
        purchase_intent_attempt_window=timedelta(minutes=15),
        purchase_intent_issuance_limit=10,
        secret_hasher=hasher,
    )
    credentials = await service.create_entitlement(
        client_identifier="203.0.113.1",
        now=NOW,
    )
    values = {
        "entitlement_id": credentials.entitlement_id,
        "auth_secret": credentials.auth_secret,
        "product_id": "lotti_sync",
        "base_plan_id": "monthly",
    }

    await service.create_purchase_intent(**values, now=NOW)
    await service.create_purchase_intent(**values, now=NOW + timedelta(seconds=1))
    with pytest.raises(PurchaseIntentRateLimitException) as error:
        await service.create_purchase_intent(**values, now=NOW + timedelta(seconds=2))

    assert error.value.retry_after_seconds == 898
    assert hasher.verify_calls == 2

    await service.create_purchase_intent(
        **values,
        now=NOW + timedelta(minutes=15),
    )
    assert hasher.verify_calls == 3


async def test_purchase_intent_attempt_limit_does_not_track_unknown_entitlements(
    repository,
):
    hasher = CountingHasher()
    service = SubscriptionIdentityService(
        repository,
        account_binding_key=bytes(range(32)),
        allowed_products={"lotti_sync": frozenset({"monthly"})},
        secret_hasher=hasher,
    )

    with pytest.raises(EntitlementAuthenticationException):
        await service.create_purchase_intent(
            entitlement_id="unknown-entitlement",
            auth_secret="unknown-secret",  # noqa: S106 - invalid test credential
            product_id="lotti_sync",
            base_plan_id="monthly",
            now=NOW,
        )

    assert hasher.verify_calls == 0
    connection = sqlite3.connect(repository.db_path)
    try:
        attempt_count = connection.execute(
            "SELECT COUNT(*) FROM subscription_attempt_limits"
        ).fetchone()[0]
    finally:
        connection.close()
    assert attempt_count == 0


async def test_purchase_intent_wrong_secret_consumes_attempt_without_issuing(
    repository,
):
    hasher = CountingHasher()
    service = SubscriptionIdentityService(
        repository,
        account_binding_key=bytes(range(32)),
        allowed_products={"lotti_sync": frozenset({"monthly"})},
        secret_hasher=hasher,
    )
    credentials = await service.create_entitlement(
        client_identifier="203.0.113.1",
        now=NOW,
    )

    with pytest.raises(EntitlementAuthenticationException):
        await service.create_purchase_intent(
            entitlement_id=credentials.entitlement_id,
            auth_secret="wrong-secret",  # noqa: S106 - invalid test credential
            product_id="lotti_sync",
            base_plan_id="monthly",
            now=NOW,
        )

    assert hasher.verify_calls == 1
    connection = sqlite3.connect(repository.db_path)
    try:
        attempt_query = (
            "SELECT request_count FROM subscription_attempt_limits "
            "WHERE entitlement_id = ? AND operation_kind = 'purchase_intent'"
        )
        attempt_count = connection.execute(
            attempt_query,
            (credentials.entitlement_id,),
        ).fetchone()[0]
        issuance_count = connection.execute(
            "SELECT COUNT(*) FROM purchase_intent_issuance_limits"
        ).fetchone()[0]
    finally:
        connection.close()
    assert attempt_count == 1
    assert issuance_count == 0


async def test_bundle_claim_attempt_limit_rejects_before_secret_verification(
    repository,
):
    hasher = CountingHasher()
    service = SubscriptionIdentityService(
        repository,
        account_binding_key=bytes(range(32)),
        allowed_products={"lotti_sync": frozenset({"monthly"})},
        bundle_claim_attempt_limit=2,
        bundle_claim_attempt_window=timedelta(minutes=15),
        secret_hasher=hasher,
    )
    credentials = await service.create_entitlement(
        client_identifier="203.0.113.1",
        now=NOW,
    )

    await service.authenticate_bundle_claim_operation(
        credentials.entitlement_id,
        credentials.auth_secret,
        now=NOW,
    )
    await service.authenticate_bundle_claim_operation(
        credentials.entitlement_id,
        credentials.auth_secret,
        now=NOW + timedelta(seconds=1),
    )
    with pytest.raises(BundleClaimRateLimitException) as error:
        await service.authenticate_bundle_claim_operation(
            credentials.entitlement_id,
            credentials.auth_secret,
            now=NOW + timedelta(seconds=2),
        )

    assert error.value.retry_after_seconds == 898
    assert hasher.verify_calls == 2
    connection = sqlite3.connect(repository.db_path)
    try:
        operation_kind, request_count = connection.execute(
            "SELECT operation_kind, request_count FROM subscription_attempt_limits "
            "WHERE entitlement_id = ?",
            (credentials.entitlement_id,),
        ).fetchone()
    finally:
        connection.close()
    assert operation_kind == "bundle_claim"
    assert request_count == 2

    await service.authenticate_bundle_claim_operation(
        credentials.entitlement_id,
        credentials.auth_secret,
        now=NOW + timedelta(minutes=15),
    )
    assert hasher.verify_calls == 3


async def test_bundle_claim_attempt_limit_does_not_track_unknown_entitlements(
    repository,
):
    hasher = CountingHasher()
    service = SubscriptionIdentityService(
        repository,
        account_binding_key=bytes(range(32)),
        allowed_products={},
        secret_hasher=hasher,
    )

    with pytest.raises(EntitlementAuthenticationException):
        await service.authenticate_bundle_claim_operation(
            "unknown-entitlement",
            "unknown-secret",  # noqa: S106 - invalid test credential
            now=NOW,
        )

    assert hasher.verify_calls == 0
    connection = sqlite3.connect(repository.db_path)
    try:
        attempt_count = connection.execute(
            "SELECT COUNT(*) FROM subscription_attempt_limits"
        ).fetchone()[0]
    finally:
        connection.close()
    assert attempt_count == 0


@pytest.mark.parametrize(
    ("product_id", "base_plan_id"),
    [("other_product", "monthly"), ("lotti_sync", "weekly")],
)
async def test_purchase_intent_rejects_unconfigured_products(
    service,
    product_id,
    base_plan_id,
):
    credentials = await service.create_entitlement(client_identifier="203.0.113.1", now=NOW)

    with pytest.raises(InvalidSubscriptionProductException):
        await service.create_purchase_intent(
            entitlement_id=credentials.entitlement_id,
            auth_secret=credentials.auth_secret,
            product_id=product_id,
            base_plan_id=base_plan_id,
            now=NOW,
        )


def test_purchase_intent_ttl_must_be_positive(repository):
    with pytest.raises(ValueError, match="must be positive"):
        SubscriptionIdentityService(
            repository,
            account_binding_key=bytes(range(32)),
            allowed_products={},
            intent_ttl=timedelta(0),
        )


async def test_entitlement_issuance_is_rate_limited_per_client(repository):
    service = SubscriptionIdentityService(
        repository,
        account_binding_key=bytes(range(32)),
        allowed_products={},
        entitlement_issuance_limit=2,
        entitlement_issuance_window=timedelta(hours=1),
    )

    await service.create_entitlement(client_identifier="203.0.113.1", now=NOW)
    await service.create_entitlement(client_identifier="203.0.113.1", now=NOW)

    with pytest.raises(EntitlementRateLimitException) as error:
        await service.create_entitlement(client_identifier="203.0.113.1", now=NOW)

    assert error.value.retry_after_seconds == 3600
    other_client = await service.create_entitlement(
        client_identifier="203.0.113.2",
        now=NOW,
    )
    after_window = await service.create_entitlement(
        client_identifier="203.0.113.1",
        now=NOW + timedelta(hours=1),
    )
    assert other_client.entitlement_id != after_window.entitlement_id


async def test_entitlement_issuance_requires_a_client_identifier(service):
    with pytest.raises(ValueError, match="Client identifier"):
        await service.create_entitlement(client_identifier="", now=NOW)


@pytest.mark.parametrize(
    ("limit", "window", "message"),
    [
        (0, timedelta(hours=1), "issuance limit"),
        (1, timedelta(0), "issuance window"),
    ],
)
def test_entitlement_rate_limit_configuration_must_be_positive(
    repository,
    limit,
    window,
    message,
):
    with pytest.raises(ValueError, match=message):
        SubscriptionIdentityService(
            repository,
            account_binding_key=bytes(range(32)),
            allowed_products={},
            entitlement_issuance_limit=limit,
            entitlement_issuance_window=window,
        )


@pytest.mark.parametrize(
    ("limit", "window", "message"),
    [
        (0, timedelta(minutes=15), "Purchase intent issuance limit"),
        (1, timedelta(0), "Purchase intent issuance window"),
    ],
)
def test_purchase_intent_rate_limit_configuration_must_be_positive(
    repository,
    limit,
    window,
    message,
):
    with pytest.raises(ValueError, match=message):
        SubscriptionIdentityService(
            repository,
            account_binding_key=bytes(range(32)),
            allowed_products={},
            purchase_intent_issuance_limit=limit,
            purchase_intent_issuance_window=window,
        )


@pytest.mark.parametrize(
    ("limit", "window", "message"),
    [
        (0, timedelta(minutes=15), "Purchase intent attempt limit"),
        (1, timedelta(0), "Purchase intent attempt window"),
    ],
)
def test_purchase_intent_attempt_limit_configuration_must_be_positive(
    repository,
    limit,
    window,
    message,
):
    with pytest.raises(ValueError, match=message):
        SubscriptionIdentityService(
            repository,
            account_binding_key=bytes(range(32)),
            allowed_products={},
            purchase_intent_attempt_limit=limit,
            purchase_intent_attempt_window=window,
        )


@pytest.mark.parametrize(
    ("limit", "window", "message"),
    [
        (0, timedelta(minutes=15), "Bundle claim attempt limit"),
        (1, timedelta(0), "Bundle claim attempt window"),
    ],
)
def test_bundle_claim_attempt_limit_configuration_must_be_positive(
    repository,
    limit,
    window,
    message,
):
    with pytest.raises(ValueError, match=message):
        SubscriptionIdentityService(
            repository,
            account_binding_key=bytes(range(32)),
            allowed_products={},
            bundle_claim_attempt_limit=limit,
            bundle_claim_attempt_window=window,
        )
