"""Converges Matrix account suspension with paid entitlement state."""

from __future__ import annotations

import asyncio
import hashlib
from datetime import datetime

from shared.matrix import SynapseAdminClient

from ..core.exceptions import BundleClaimConflictException
from ..core.subscriptions import EntitlementState, StoredSubscription
from .subscription_repository import SubscriptionRepository

_ACCESS_STATES = {
    EntitlementState.ACTIVE,
    EntitlementState.GRACE,
    EntitlementState.CANCELED_ACTIVE,
}


class SubscriptionAccessService:
    """Apply reversible suspension without destroying Matrix account state."""

    def __init__(
        self,
        repository: SubscriptionRepository,
        admin_client: SynapseAdminClient,
    ):
        self._repository = repository
        self._admin_client = admin_client
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

        access_granted = subscription.entitlement_state in _ACCESS_STATES
        if (
            access_granted
            and subscription.current_period_end is not None
            and now >= subscription.current_period_end
        ):
            access_granted = False
        desired_suspended = not access_granted

        try:
            activity = await self._admin_client.get_user_activity(user.user_mxid)
            if activity.suspended != desired_suspended:
                await self._admin_client.set_user_suspended(
                    user.user_mxid,
                    suspended=desired_suspended,
                )
            await self._repository.record_subscription_enforcement(
                subscription.token_fingerprint,
                suspended=desired_suspended,
                now=now,
            )
        except Exception as exc:
            await self._repository.record_subscription_error(
                subscription.token_fingerprint,
                last_error=str(exc),
                now=now,
            )
            raise
        return desired_suspended
