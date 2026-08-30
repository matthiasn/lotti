"""Periodic Google refresh and Matrix access convergence for subscriptions."""

from __future__ import annotations

import logging
from collections.abc import Callable
from datetime import datetime, timedelta, timezone

from ..core.constants import (
    DEFAULT_SUBSCRIPTION_RECONCILE_BATCH_SIZE,
    DEFAULT_SUBSCRIPTION_RECONCILE_INTERVAL_SECONDS,
)
from .periodic_task import PeriodicTask
from .secret_cipher import SecretCipher
from .subscription_access_service import SubscriptionAccessService
from .subscription_repository import SubscriptionRepository
from .subscription_service import SubscriptionService

logger = logging.getLogger(__name__)


class SubscriptionReconciler(PeriodicTask):
    """Re-query due tokens so missed notifications cannot leave access stale."""

    def __init__(
        self,
        repository: SubscriptionRepository,
        subscription_service: SubscriptionService,
        access_service: SubscriptionAccessService,
        secret_cipher: SecretCipher,
        *,
        interval_seconds: float = DEFAULT_SUBSCRIPTION_RECONCILE_INTERVAL_SECONDS,
        batch_size: int = DEFAULT_SUBSCRIPTION_RECONCILE_BATCH_SIZE,
        now_provider: Callable[[], datetime] | None = None,
        failure_retry_delay: timedelta = timedelta(minutes=5),
    ):
        super().__init__(
            name="Google Play subscription reconciler",
            interval_seconds=interval_seconds,
        )
        self._repository = repository
        self._subscription_service = subscription_service
        self._access_service = access_service
        self._secret_cipher = secret_cipher
        self._batch_size = batch_size
        self._now_provider = now_provider or (lambda: datetime.now(timezone.utc))
        self._failure_retry_delay = failure_retry_delay

    async def run_once(self) -> None:
        """Run one reconciliation batch for the periodic loop."""
        await self.reconcile_once()

    async def reconcile_once(self) -> int:
        """Refresh and enforce due current subscriptions, isolating failures."""
        now = self._now_provider()
        subscriptions = await self._repository.list_due_reconciliation(
            now,
            limit=self._batch_size,
        )
        reconciled = 0
        for stored in subscriptions:
            try:
                token = self._secret_cipher.decrypt(
                    stored.encrypted_purchase_token,
                    purpose="purchase-token",
                    record_id=stored.token_fingerprint,
                    key_id=stored.encryption_key_id,
                ).decode()
                await self._subscription_service.refresh_known_purchase(
                    token,
                    now=now,
                )
                current = await self._repository.get_current_subscription(stored.entitlement_id)
                if current is not None:
                    await self._access_service.enforce(
                        current,
                        now=max(now, self._now_provider()),
                    )
                reconciled += 1
            except Exception as exc:  # noqa: BLE001 - one token must not stop the batch
                error = str(exc)
                enforcement_now = max(now, self._now_provider())
                try:
                    # A Google outage must not extend a previously verified
                    # expiry/grace deadline. Converge from the durable snapshot
                    # and reschedule the authoritative refresh below.
                    current = await self._repository.get_current_subscription(stored.entitlement_id)
                    if current is not None:
                        await self._access_service.enforce(current, now=enforcement_now)
                except Exception as enforcement_exc:  # noqa: BLE001 - record both failures
                    error = f"{error}; stored-state enforcement failed: {enforcement_exc}"
                logger.warning(
                    "Subscription reconciliation failed for fingerprint %s: %s",
                    stored.token_fingerprint,
                    error,
                )
                retry_now = max(enforcement_now, self._now_provider())
                await self._repository.record_subscription_error(
                    stored.token_fingerprint,
                    last_error=error,
                    now=retry_now,
                    next_reconciliation_at=retry_now + self._failure_retry_delay,
                )
        return reconciled
