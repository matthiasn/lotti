"""Tests for entitlement credentials and one-time Billing authorization."""

from __future__ import annotations

from datetime import datetime, timedelta, timezone

import pytest
from src.core.exceptions import (
    EntitlementAuthenticationException,
    InvalidSubscriptionProductException,
)
from src.services.subscription_identity_service import SubscriptionIdentityService
from src.services.subscription_repository import SubscriptionRepository
from src.services.subscription_security import SecretHasher

pytestmark = pytest.mark.anyio

NOW = datetime(2026, 8, 29, 12, tzinfo=timezone.utc)


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
    credentials = await service.create_entitlement(now=NOW)

    stored = await repository.get_entitlement(credentials.entitlement_id)

    assert credentials.auth_secret
    assert credentials.obfuscated_account_id == stored.obfuscated_account_id
    assert credentials.auth_secret not in stored.auth_secret_hash
    assert SecretHasher().verify(credentials.auth_secret, stored.auth_secret_hash)


async def test_entitlement_authentication_rejects_unknown_or_wrong_credentials(
    service,
):
    credentials = await service.create_entitlement(now=NOW)

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
    credentials = await service.create_entitlement(now=NOW)

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


@pytest.mark.parametrize(
    ("product_id", "base_plan_id"),
    [("other_product", "monthly"), ("lotti_sync", "weekly")],
)
async def test_purchase_intent_rejects_unconfigured_products(
    service,
    product_id,
    base_plan_id,
):
    credentials = await service.create_entitlement(now=NOW)

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
