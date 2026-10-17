"""The app-facing half of web checkout: sessions, status, claim, portal.

The app never sees Paddle credentials and Paddle never sees the app's
entitlement secret. A checkout session is the only thing that crosses: the app
creates it with its entitlement credential, the checkout page passes its id to
Paddle as ``custom_data``, and the webhook uses it to attribute the resulting
subscription.
"""

from __future__ import annotations

import asyncio
import secrets
from collections.abc import Callable
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from enum import Enum
from urllib.parse import urlencode

from ..core.exceptions import (
    BundleClaimConflictException,
    CheckoutSessionException,
    EntitlementAuthenticationException,
    GooglePlayVerificationException,
    InvalidSubscriptionProductException,
    PaymentPendingException,
    WebCheckoutRateLimitException,
)
from ..core.subscriptions import (
    CheckoutSession,
    PaidBundleDelivery,
    StoredSubscription,
    SubscriptionProvider,
    VerifiedPurchaseResult,
    grants_access,
)
from .paddle_subscription_service import PaddleSubscriptionService
from .paid_bundle_service import PaidBundleService
from .subscription_access_service import SubscriptionAccessService
from .subscription_identity_service import SubscriptionIdentityService
from .subscription_security import SecretHasher
from .web_subscription_repository import (
    ATTEMPT_KIND_WEB_CHECKOUT,
    WebSubscriptionRepository,
)


class CheckoutSessionState(str, Enum):
    """What the app's waiting screen shows."""

    PENDING = "pending"
    PAID = "paid"
    EXPIRED = "expired"


@dataclass(frozen=True)
class CreatedCheckoutSession:
    """Returned once to the app; the URL carries the id in its fragment."""

    session_id: str
    checkout_url: str
    expires_at: datetime


@dataclass(frozen=True)
class WebClaimResult:
    """A paid delivery plus the entitlement state it was granted under."""

    delivery: PaidBundleDelivery
    subscription: StoredSubscription


class WebCheckoutService:
    """Entitlement-authenticated operations behind the subscribe screen."""

    def __init__(
        self,
        repository: WebSubscriptionRepository,
        identity_service: SubscriptionIdentityService,
        paid_bundle_service: PaidBundleService,
        access_service: SubscriptionAccessService,
        paddle_subscriptions: PaddleSubscriptionService,
        *,
        checkout_page_url: str,
        allowed_price_ids: frozenset[str],
        session_ttl: timedelta = timedelta(minutes=30),
        attempt_limit: int = 10,
        attempt_window: timedelta = timedelta(minutes=15),
        secret_hasher: SecretHasher | None = None,
        now_provider: Callable[[], datetime] | None = None,
    ):
        if not checkout_page_url.startswith("https://"):
            raise ValueError("WEB_CHECKOUT_PAGE_URL must be an https:// URL")
        if not allowed_price_ids:
            raise ValueError("At least one Paddle price id must be enabled")
        self._repository = repository
        self._identity_service = identity_service
        self._paid_bundle_service = paid_bundle_service
        self._access_service = access_service
        self._paddle_subscriptions = paddle_subscriptions
        self._checkout_page_url = checkout_page_url
        self._allowed_price_ids = allowed_price_ids
        self._session_ttl = session_ttl
        self._attempt_limit = attempt_limit
        self._attempt_window = attempt_window
        self._secret_hasher = secret_hasher or SecretHasher()
        self._now_provider = now_provider or (lambda: datetime.now(timezone.utc))

    async def create_session(
        self,
        *,
        entitlement_id: str,
        auth_secret: str,
        price_id: str,
        claim_secret: str,
    ) -> CreatedCheckoutSession:
        """Authorize one checkout launch and remember which claim secret it pays for."""
        now = self._now_provider()
        await self._authenticate(entitlement_id, auth_secret, now=now)
        if price_id not in self._allowed_price_ids:
            raise InvalidSubscriptionProductException("Price is not enabled for SYNC")
        if len(claim_secret) < 32:
            raise BundleClaimConflictException("Claim secret is too short")
        session = CheckoutSession(
            session_id=secrets.token_urlsafe(24),
            entitlement_id=entitlement_id,
            claim_secret_hash=await asyncio.to_thread(self._secret_hasher.hash, claim_secret),
            price_id=price_id,
            expires_at=now + self._session_ttl,
            bound_token_fingerprint=None,
            bound_at=None,
            created_at=now,
        )
        await self._repository.create_checkout_session(session)
        # A fragment never reaches a server log, so the session id stays
        # between the app, the browser and Paddle's custom_data.
        fragment = urlencode({"session": session.session_id, "price": price_id})
        return CreatedCheckoutSession(
            session_id=session.session_id,
            checkout_url=f"{self._checkout_page_url}#{fragment}",
            expires_at=session.expires_at,
        )

    async def session_state(self, session_id: str) -> CheckoutSessionState:
        """Cheap poll target: no secret hashing, the unguessable id is the capability."""
        session = await self._repository.get_checkout_session(session_id)
        if session is None:
            raise CheckoutSessionException("Unknown checkout session")
        if session.bound_token_fingerprint is not None:
            current = await self._repository.get_current_subscription(session.entitlement_id)
            if (
                current is not None
                and current.token_fingerprint == session.bound_token_fingerprint
                and grants_access(current, now=self._now_provider())
            ):
                return CheckoutSessionState.PAID
            return CheckoutSessionState.PENDING
        if self._now_provider() >= session.expires_at:
            return CheckoutSessionState.EXPIRED
        return CheckoutSessionState.PENDING

    async def claim(
        self,
        *,
        entitlement_id: str,
        auth_secret: str,
        claim_secret: str,
    ) -> WebClaimResult:
        """Provision on first call, redeliver the same escrow on retries."""
        await self._identity_service.authenticate_bundle_claim_operation(
            entitlement_id,
            auth_secret,
            now=self._now_provider(),
        )
        current = await self._require_paid_subscription(entitlement_id)
        session = await self._repository.get_bound_checkout_session(
            entitlement_id,
            token_fingerprint=current.token_fingerprint,
        )
        if session is None:
            raise PaymentPendingException("No checkout produced the current subscription")
        await self._require_unsuspended(current)
        delivery = await self._paid_bundle_service.provision_or_deliver_web(
            VerifiedPurchaseResult(
                subscription=current,
                request_hash="",
                claim_secret_hash=session.claim_secret_hash,
            ),
            claim_secret=claim_secret,
            now=self._now_provider(),
        )
        current = await self._require_paid_subscription(entitlement_id)
        await self._require_unsuspended(current)
        subscription = await self._paid_bundle_service.require_returnable_delivery(
            delivery,
            entitlement_id=entitlement_id,
            now=self._now_provider(),
        )
        return WebClaimResult(delivery=delivery, subscription=subscription)

    async def portal_url(self, *, entitlement_id: str, auth_secret: str) -> str:
        """A Paddle customer-portal link for cancelling or changing payment."""
        now = self._now_provider()
        await self._authenticate(entitlement_id, auth_secret, now=now)
        current = await self._repository.get_current_subscription(entitlement_id)
        if current is None or current.provider is not SubscriptionProvider.PADDLE:
            raise PaymentPendingException("No web subscription for this entitlement")
        return await self._paddle_subscriptions.portal_url(current)

    async def _authenticate(self, entitlement_id: str, auth_secret: str, *, now: datetime) -> None:
        # The quota row references the entitlement, so an unknown id is
        # rejected before it can be counted.
        if await self._repository.get_entitlement(entitlement_id) is None:
            raise EntitlementAuthenticationException("Invalid entitlement credentials")
        retry_after = await self._repository.consume_subscription_attempt_quota(
            entitlement_id,
            ATTEMPT_KIND_WEB_CHECKOUT,
            now=now,
            window=self._attempt_window,
            max_requests=self._attempt_limit,
        )
        if retry_after is not None:
            raise WebCheckoutRateLimitException(retry_after_seconds=retry_after)
        await self._identity_service.authenticate(entitlement_id, auth_secret)

    async def _require_paid_subscription(self, entitlement_id: str) -> StoredSubscription:
        current = await self._repository.get_current_subscription(entitlement_id)
        if (
            current is None
            or current.provider is not SubscriptionProvider.PADDLE
            or not grants_access(current, now=self._now_provider())
        ):
            raise PaymentPendingException("No paid web subscription yet")
        return current

    async def _require_unsuspended(self, current: StoredSubscription) -> None:
        if await self._access_service.enforce(current, now=self._now_provider()) is True:
            raise GooglePlayVerificationException(
                "Subscription does not currently grant SYNC access"
            )
