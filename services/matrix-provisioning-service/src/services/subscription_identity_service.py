"""Stable entitlement identity and one-time purchase-intent issuance."""

from __future__ import annotations

import asyncio
import secrets
import uuid
from datetime import datetime, timedelta

from ..core.exceptions import (
    EntitlementAuthenticationException,
    InvalidSubscriptionProductException,
)
from ..core.subscriptions import (
    EntitlementCredentials,
    PurchaseIntentCredentials,
    SyncEntitlement,
)
from .subscription_repository import SubscriptionRepository
from .subscription_security import SecretHasher, derive_obfuscated_account_id


class SubscriptionIdentityService:
    """Issues app-held credentials without relying on a shared embedded API key."""

    def __init__(
        self,
        repository: SubscriptionRepository,
        *,
        account_binding_key: bytes,
        allowed_products: dict[str, frozenset[str]],
        intent_ttl: timedelta = timedelta(minutes=15),
        secret_hasher: SecretHasher | None = None,
    ):
        if intent_ttl <= timedelta(0):
            raise ValueError("Purchase intent TTL must be positive")
        self._repository = repository
        self._account_binding_key = account_binding_key
        self._allowed_products = allowed_products
        self._intent_ttl = intent_ttl
        self._secret_hasher = secret_hasher or SecretHasher()

    async def create_entitlement(self, *, now: datetime) -> EntitlementCredentials:
        """Create a stable anonymous identity and return its secret exactly once."""
        entitlement_id = str(uuid.uuid4())
        auth_secret = secrets.token_urlsafe(32)
        obfuscated_account_id = derive_obfuscated_account_id(
            self._account_binding_key,
            entitlement_id,
        )
        await self._repository.create_entitlement(
            entitlement_id=entitlement_id,
            obfuscated_account_id=obfuscated_account_id,
            auth_secret_hash=await asyncio.to_thread(self._secret_hasher.hash, auth_secret),
            now=now,
        )
        return EntitlementCredentials(
            entitlement_id=entitlement_id,
            auth_secret=auth_secret,
            obfuscated_account_id=obfuscated_account_id,
        )

    async def authenticate(self, entitlement_id: str, auth_secret: str) -> SyncEntitlement:
        """Authenticate with the app-held high-entropy entitlement secret."""
        entitlement = await self._repository.get_entitlement(entitlement_id)
        valid_secret = (
            False
            if entitlement is None
            else await asyncio.to_thread(
                self._secret_hasher.verify,
                auth_secret,
                entitlement.auth_secret_hash,
            )
        )
        if entitlement is None or entitlement.disabled_at is not None or not valid_secret:
            raise EntitlementAuthenticationException("Invalid entitlement credentials")
        return entitlement

    async def create_purchase_intent(
        self,
        *,
        entitlement_id: str,
        auth_secret: str,
        product_id: str,
        base_plan_id: str,
        now: datetime,
    ) -> PurchaseIntentCredentials:
        """Authorize one Billing launch for an authenticated entitlement."""
        entitlement = await self.authenticate(entitlement_id, auth_secret)
        if base_plan_id not in self._allowed_products.get(product_id, frozenset()):
            raise InvalidSubscriptionProductException(
                "Subscription product or base plan is not enabled"
            )

        intent_id = str(uuid.uuid4())
        intent_secret = secrets.token_urlsafe(32)
        expires_at = now + self._intent_ttl
        await self._repository.create_purchase_intent(
            intent_id=intent_id,
            entitlement_id=entitlement.entitlement_id,
            intent_secret_hash=await asyncio.to_thread(self._secret_hasher.hash, intent_secret),
            product_id=product_id,
            base_plan_id=base_plan_id,
            obfuscated_account_id=entitlement.obfuscated_account_id,
            expires_at=expires_at,
            now=now,
        )
        return PurchaseIntentCredentials(
            intent_id=intent_id,
            intent_secret=intent_secret,
            product_id=product_id,
            base_plan_id=base_plan_id,
            obfuscated_account_id=entitlement.obfuscated_account_id,
            expires_at=expires_at,
        )
