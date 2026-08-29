"""Stable entitlement identity and one-time purchase-intent issuance."""

from __future__ import annotations

import asyncio
import secrets
import uuid
from datetime import datetime, timedelta

from ..core.exceptions import (
    EntitlementAuthenticationException,
    EntitlementRateLimitException,
    InvalidSubscriptionProductException,
    PurchaseIntentRateLimitException,
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
        entitlement_issuance_limit: int = 5,
        entitlement_issuance_window: timedelta = timedelta(hours=1),
        purchase_intent_attempt_limit: int = 10,
        purchase_intent_attempt_window: timedelta = timedelta(minutes=15),
        purchase_intent_issuance_limit: int = 10,
        purchase_intent_issuance_window: timedelta = timedelta(minutes=15),
        secret_hasher: SecretHasher | None = None,
    ):
        if intent_ttl <= timedelta(0):
            raise ValueError("Purchase intent TTL must be positive")
        if entitlement_issuance_limit <= 0:
            raise ValueError("Entitlement issuance limit must be positive")
        if entitlement_issuance_window <= timedelta(0):
            raise ValueError("Entitlement issuance window must be positive")
        if purchase_intent_attempt_limit <= 0:
            raise ValueError("Purchase intent attempt limit must be positive")
        if purchase_intent_attempt_window <= timedelta(0):
            raise ValueError("Purchase intent attempt window must be positive")
        if purchase_intent_issuance_limit <= 0:
            raise ValueError("Purchase intent issuance limit must be positive")
        if purchase_intent_issuance_window <= timedelta(0):
            raise ValueError("Purchase intent issuance window must be positive")
        self._repository = repository
        self._account_binding_key = account_binding_key
        self._allowed_products = allowed_products
        self._intent_ttl = intent_ttl
        self._entitlement_issuance_limit = entitlement_issuance_limit
        self._entitlement_issuance_window = entitlement_issuance_window
        self._purchase_intent_attempt_limit = purchase_intent_attempt_limit
        self._purchase_intent_attempt_window = purchase_intent_attempt_window
        self._purchase_intent_issuance_limit = purchase_intent_issuance_limit
        self._purchase_intent_issuance_window = purchase_intent_issuance_window
        self._secret_hasher = secret_hasher or SecretHasher()

    async def create_entitlement(
        self,
        *,
        client_identifier: str,
        now: datetime,
    ) -> EntitlementCredentials:
        """Create a stable anonymous identity and return its secret exactly once."""
        if not client_identifier:
            raise ValueError("Client identifier must not be empty")
        client_key_hash = derive_obfuscated_account_id(
            self._account_binding_key,
            f"entitlement-rate-v1\0{client_identifier}",
        )
        retry_after = await self._repository.consume_entitlement_issuance_quota(
            client_key_hash,
            now=now,
            window=self._entitlement_issuance_window,
            max_requests=self._entitlement_issuance_limit,
        )
        if retry_after is not None:
            raise EntitlementRateLimitException(retry_after_seconds=retry_after)
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
        if entitlement is None or entitlement.disabled_at is not None:
            raise EntitlementAuthenticationException("Invalid entitlement credentials")
        await self._verify_entitlement_secret(entitlement, auth_secret)
        return entitlement

    async def _verify_entitlement_secret(
        self,
        entitlement: SyncEntitlement,
        auth_secret: str,
    ) -> None:
        valid_secret = await asyncio.to_thread(
            self._secret_hasher.verify,
            auth_secret,
            entitlement.auth_secret_hash,
        )
        if not valid_secret:
            raise EntitlementAuthenticationException("Invalid entitlement credentials")

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
        entitlement = await self._repository.get_entitlement(entitlement_id)
        if entitlement is None or entitlement.disabled_at is not None:
            raise EntitlementAuthenticationException("Invalid entitlement credentials")
        retry_after = await self._repository.consume_purchase_intent_attempt_quota(
            entitlement.entitlement_id,
            now=now,
            window=self._purchase_intent_attempt_window,
            max_requests=self._purchase_intent_attempt_limit,
        )
        if retry_after is not None:
            raise PurchaseIntentRateLimitException(retry_after_seconds=retry_after)
        await self._verify_entitlement_secret(entitlement, auth_secret)
        if base_plan_id not in self._allowed_products.get(product_id, frozenset()):
            raise InvalidSubscriptionProductException(
                "Subscription product or base plan is not enabled"
            )
        retry_after = await self._repository.consume_purchase_intent_issuance_quota(
            entitlement.entitlement_id,
            now=now,
            window=self._purchase_intent_issuance_window,
            max_requests=self._purchase_intent_issuance_limit,
        )
        if retry_after is not None:
            raise PurchaseIntentRateLimitException(retry_after_seconds=retry_after)

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
