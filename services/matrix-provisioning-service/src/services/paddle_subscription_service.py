"""Applies Paddle subscription state to the shared entitlement store.

Two inputs feed it: signed webhooks (the fast path) and the reconciler's API
refresh (the repair path for anything Paddle failed to deliver). Both end in
the same ``store_verified_subscription`` upsert the Play path uses, so escrow,
suspension and the claim reaper need no Paddle-specific code.
"""

from __future__ import annotations

import json
import logging
from collections.abc import Callable
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from typing import Any

from ..core.exceptions import PaddleWebhookException
from ..core.paddle import (
    PaddleSubscription,
    interpret,
    parse_event,
    verify_signature,
)
from ..core.subscriptions import (
    AcknowledgementState,
    GoogleSubscriptionState,
    StoredSubscription,
    SubscriptionProvider,
    VerifiedSubscription,
    normalize_entitlement,
)
from .paddle_client import PaddleClient
from .secret_cipher import SecretCipher
from .subscription_access_service import SubscriptionAccessService
from .subscription_security import fingerprint
from .web_subscription_repository import WebSubscriptionRepository

logger = logging.getLogger(__name__)

PADDLE_PACKAGE_NAME = "paddle"
PURCHASE_TOKEN_PURPOSE = "purchase-token"  # noqa: S105 - cipher purpose label


@dataclass(frozen=True)
class PaddleReference:
    """The Paddle ids sealed in a row's ``encrypted_purchase_token``."""

    subscription_id: str
    customer_id: str


def paddle_token_fingerprint(subscription_id: str) -> str:
    """Correlation key for a Paddle subscription in the shared table."""
    return fingerprint(f"paddle:{subscription_id}")


class PaddleSubscriptionService:
    """Turns Paddle subscription entities into stored entitlement rows."""

    def __init__(
        self,
        repository: WebSubscriptionRepository,
        access_service: SubscriptionAccessService,
        secret_cipher: SecretCipher,
        paddle_client: PaddleClient,
        *,
        webhook_secret: str,
        allowed_price_ids: frozenset[str],
        grace_period: timedelta = timedelta(days=7),
        reconciliation_interval: timedelta = timedelta(hours=6),
        now_provider: Callable[[], datetime] | None = None,
    ):
        if not allowed_price_ids:
            raise ValueError("At least one Paddle price id must be enabled")
        self._repository = repository
        self._access_service = access_service
        self._secret_cipher = secret_cipher
        self._paddle_client = paddle_client
        self._webhook_secret = webhook_secret
        self._allowed_price_ids = allowed_price_ids
        self._grace_period = grace_period
        self._reconciliation_interval = reconciliation_interval
        self._now_provider = now_provider or (lambda: datetime.now(timezone.utc))

    async def handle_webhook(self, raw_body: bytes, signature_header: str) -> str:
        """Verify and apply one notification; return what was done, for logs.

        Raises ``PaddleWebhookException`` only for deliveries that must not be
        trusted. Well-signed events this service has no use for are
        acknowledged so Paddle stops retrying them.
        """
        now = self._now_provider()
        verify_signature(raw_body, signature_header, self._webhook_secret, now=now)
        try:
            payload: Any = json.loads(raw_body)
        except ValueError as exc:
            raise PaddleWebhookException("Paddle webhook body is not JSON") from exc
        if not isinstance(payload, dict):
            raise PaddleWebhookException("Paddle webhook body is not an object")
        event = parse_event(payload)
        if await self._repository.webhook_event_processed(event.event_id):
            return "duplicate"
        outcome = "ignored"
        if event.subscription is not None:
            outcome = await self._apply_event_subscription(
                event.subscription,
                observed_at=event.occurred_at,
                now=now,
            )
        await self._repository.record_webhook_event(
            event.event_id,
            event_type=event.event_type,
            occurred_at=event.occurred_at,
            now=now,
        )
        return outcome

    async def _apply_event_subscription(
        self,
        subscription: PaddleSubscription,
        *,
        observed_at: datetime,
        now: datetime,
    ) -> str:
        if subscription.price_id not in self._allowed_price_ids:
            logger.warning("Ignoring Paddle subscription on an unknown price")
            return "ignored-price"
        token_fingerprint = paddle_token_fingerprint(subscription.subscription_id)
        existing = await self._repository.get_subscription_by_token(token_fingerprint)
        # Paddle keeps custom_data on the subscription, so every event names
        # the session. Resolving it even for a known subscription lets a later
        # delivery finish a binding that a crash interrupted.
        session = (
            await self._repository.get_checkout_session(subscription.checkout_session_id)
            if subscription.checkout_session_id is not None
            else None
        )
        if existing is not None:
            entitlement_id = existing.entitlement_id
            if session is not None and session.entitlement_id != entitlement_id:
                logger.warning("Paddle subscription names another entitlement's session")
                session = None
        elif session is not None:
            entitlement_id = session.entitlement_id
        elif subscription.checkout_session_id is not None:
            logger.warning("Paddle subscription names an unknown checkout session")
            return "ignored-session"
        else:
            # Created outside the app's checkout (e.g. in the Paddle
            # dashboard): there is no entitlement to attribute it to.
            logger.warning("Paddle subscription carries no checkout session")
            return "ignored-unbound"

        stored = await self._store(
            subscription,
            entitlement_id=entitlement_id,
            observed_at=observed_at,
            now=now,
        )
        if session is not None and session.bound_token_fingerprint is None:
            await self._repository.bind_checkout_session(
                session.session_id,
                token_fingerprint=token_fingerprint,
                now=now,
            )
        current = await self._repository.get_current_subscription(entitlement_id)
        if current is not None and current.token_fingerprint == stored.token_fingerprint:
            await self._access_service.enforce(current, now=self._now_provider())
        return "applied"

    async def refresh(self, stored: StoredSubscription) -> None:
        """Re-apply Paddle's current view of a known subscription (reconciler path)."""
        reference = self.reference(stored)
        subscription = await self._paddle_client.get_subscription(reference.subscription_id)
        if subscription.price_id not in self._allowed_price_ids:
            # Moved to a price this service does not sell (a portal or catalog
            # change): leave the stored row alone, so its deadline still
            # fails closed, rather than grant access on an unknown plan.
            logger.warning("Paddle subscription moved to an unknown price; not refreshed")
            return
        now = self._now_provider()
        await self._store(
            subscription,
            entitlement_id=stored.entitlement_id,
            observed_at=now,
            now=now,
        )

    async def portal_url(self, stored: StoredSubscription) -> str:
        """A customer-portal link for the subscription behind ``stored``."""
        reference = self.reference(stored)
        return await self._paddle_client.create_portal_url(
            reference.customer_id,
            reference.subscription_id,
        )

    def reference(self, stored: StoredSubscription) -> PaddleReference:
        """Unseal the Paddle ids of a stored web subscription."""
        if stored.provider is not SubscriptionProvider.PADDLE:
            raise ValueError("Not a Paddle subscription")
        sealed = self._secret_cipher.decrypt(
            stored.encrypted_purchase_token,
            purpose=PURCHASE_TOKEN_PURPOSE,
            record_id=stored.token_fingerprint,
            key_id=stored.encryption_key_id,
        )
        values = json.loads(sealed)
        return PaddleReference(
            subscription_id=values["subscription_id"],
            customer_id=values["customer_id"],
        )

    async def _store(
        self,
        subscription: PaddleSubscription,
        *,
        entitlement_id: str,
        observed_at: datetime,
        now: datetime,
    ) -> StoredSubscription:
        token_fingerprint = paddle_token_fingerprint(subscription.subscription_id)
        access = interpret(subscription, observed_at=observed_at, grace_period=self._grace_period)
        entitlement = normalize_entitlement(
            access.play_state,
            expiry_time=access.access_deadline,
            now=now,
        )
        next_check = now + self._reconciliation_interval
        if access.access_deadline is not None:
            next_check = min(next_check, max(now, access.access_deadline))
        existing = await self._repository.get_subscription_by_token(token_fingerprint)
        linked = None
        if existing is None:
            current = await self._repository.get_current_subscription(entitlement_id)
            if current is not None and current.token_fingerprint != token_fingerprint:
                # A second checkout for the same entitlement replaces the first
                # as the source of access; the store requires the lineage.
                linked = current.token_fingerprint
        sealed = self._secret_cipher.encrypt(
            json.dumps(
                {
                    "subscription_id": subscription.subscription_id,
                    "customer_id": subscription.customer_id,
                }
            ).encode(),
            purpose=PURCHASE_TOKEN_PURPOSE,
            record_id=token_fingerprint,
        )
        return await self._repository.store_verified_subscription(
            VerifiedSubscription(
                entitlement_id=entitlement_id,
                token_fingerprint=token_fingerprint,
                encrypted_purchase_token=sealed,
                encryption_key_id=self._secret_cipher.key_id,
                package_name=PADDLE_PACKAGE_NAME,
                product_id=subscription.product_id,
                base_plan_id=subscription.price_id,
                latest_order_id=None,
                google_state=access.play_state,
                entitlement_state=entitlement.state,
                start_time=subscription.started_at,
                current_period_end=access.access_deadline,
                grace_deadline=(
                    access.access_deadline
                    if access.play_state is GoogleSubscriptionState.IN_GRACE_PERIOD
                    else None
                ),
                acknowledgement_state=AcknowledgementState.ACKNOWLEDGED,
                binding_verified=True,
                last_verified_at=observed_at,
                next_reconciliation_at=next_check,
                linked_token_fingerprint=linked,
                # Enforcement bookkeeping belongs to the access service; an
                # upsert must carry it over rather than reset it.
                bundle_id=existing.bundle_id if existing else None,
                acknowledged_at=existing.acknowledged_at if existing else now,
                suspended_at=existing.suspended_at if existing else None,
                unsuspended_at=existing.unsuspended_at if existing else None,
                provider=SubscriptionProvider.PADDLE,
            ),
            now=now,
        )
