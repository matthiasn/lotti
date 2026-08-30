"""Converges Matrix account suspension with paid entitlement state."""

from __future__ import annotations

import asyncio
import hashlib
from collections.abc import Callable
from datetime import datetime, timedelta, timezone

from shared.matrix import SynapseAdminClient

from ..core.exceptions import BundleClaimConflictException
from ..core.subscriptions import ACCESS_ENTITLEMENT_STATES, StoredSubscription
from .subscription_repository import SubscriptionRepository


class SubscriptionAccessService:
    """Apply reversible suspension without destroying Matrix account state."""

    def __init__(
        self,
        repository: SubscriptionRepository,
        admin_client: SynapseAdminClient,
        *,
        failure_retry_delay: timedelta = timedelta(minutes=5),
        now_provider: Callable[[], datetime] | None = None,
    ):
        self._repository = repository
        self._admin_client = admin_client
        self._failure_retry_delay = failure_retry_delay
        self._now_provider = now_provider or (lambda: datetime.now(timezone.utc))
        self._enforcement_locks = tuple(asyncio.Lock() for _ in range(64))

    async def enforce(self, subscription: StoredSubscription, *, now: datetime) -> bool | None:
        """Converge one provisioned account and return its desired suspension.

        ``None`` means no Matrix account has been provisioned yet.
        """
        lock_index = int(
            hashlib.sha256(subscription.entitlement_id.encode()).hexdigest(),
            16,
        ) % len(self._enforcement_locks)
        async with self._enforcement_locks[lock_index]:
            current = await self._repository.get_current_subscription(subscription.entitlement_id)
            if current is None:
                return None
            return await self._enforce_current(current, now=now)

    async def _enforce_current(
        self,
        subscription: StoredSubscription,
        *,
        now: datetime,
    ) -> bool | None:
        """Converge the authoritative row while its entitlement stripe is held."""
        if subscription.bundle_id is None:
            return None
        user = await self._repository.get(subscription.bundle_id)
        if user is None:
            raise BundleClaimConflictException("Subscription references a missing Matrix bundle")

        error_token_fingerprint = subscription.token_fingerprint
        try:
            activity = await self._admin_client.get_user_activity(user.user_mxid)
            current = await self._repository.get_current_subscription(subscription.entitlement_id)
            if current is None or current.bundle_id is None:
                return None
            error_token_fingerprint = current.token_fingerprint
            current_user = await self._repository.get(current.bundle_id)
            if current_user is None:
                raise BundleClaimConflictException(
                    "Subscription references a missing Matrix bundle"
                )
            if current_user.user_mxid != user.user_mxid:
                activity = await self._admin_client.get_user_activity(current_user.user_mxid)
            enforcement_now = max(now, self._now_provider())
            desired_suspended = self._desired_suspension(current, now=enforcement_now)
            if activity.suspended != desired_suspended:
                await self._admin_client.set_user_suspended(
                    current_user.user_mxid,
                    suspended=desired_suspended,
                )
            await self._repository.record_subscription_enforcement(
                current.token_fingerprint,
                suspended=desired_suspended,
                now=enforcement_now,
            )
        except Exception as exc:
            failure_now = max(now, self._now_provider())
            await self._repository.record_subscription_error(
                error_token_fingerprint,
                last_error=str(exc),
                now=failure_now,
                next_reconciliation_at=failure_now + self._failure_retry_delay,
            )
            raise
        return desired_suspended

    @staticmethod
    def _desired_suspension(subscription: StoredSubscription, *, now: datetime) -> bool:
        """Return the Matrix suspension required by the verified snapshot."""
        access_granted = subscription.entitlement_state in ACCESS_ENTITLEMENT_STATES
        if (
            access_granted
            and subscription.current_period_end is not None
            and now >= subscription.current_period_end
        ):
            access_granted = False
        return not access_granted
