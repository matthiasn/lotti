"""Revokes abandoned paid bootstrap accounts after their claim TTL."""

from __future__ import annotations

import logging
import uuid
from collections.abc import Callable
from datetime import datetime, timedelta, timezone

from shared.matrix import SynapseAdminClient

from .periodic_task import PeriodicTask
from .subscription_repository import SubscriptionRepository

logger = logging.getLogger(__name__)


class BundleClaimReaper(PeriodicTask):
    """Deactivate unrotated accounts and remove expired bundle ciphertext."""

    def __init__(
        self,
        repository: SubscriptionRepository,
        admin_client: SynapseAdminClient,
        *,
        interval_seconds: float = 300,
        batch_size: int = 50,
        now_provider: Callable[[], datetime] | None = None,
        failure_retry_delay: timedelta = timedelta(minutes=5),
        operation_timeout: timedelta = timedelta(minutes=5),
    ):
        super().__init__(name="Paid bundle claim reaper", interval_seconds=interval_seconds)
        self._repository = repository
        self._admin_client = admin_client
        self._batch_size = batch_size
        self._now_provider = now_provider or (lambda: datetime.now(timezone.utc))
        self._failure_retry_delay = failure_retry_delay
        self._operation_timeout = operation_timeout

    async def run_once(self) -> None:
        """Run one cleanup batch for the periodic loop."""
        await self.reap_once()

    async def reap_once(self) -> int:
        """Revoke expired unconfirmed accounts, isolating failures per claim."""
        now = self._now_provider()
        claims = await self._repository.list_expired_bundle_claims(
            now,
            stale_before=now - self._operation_timeout,
            limit=self._batch_size,
        )
        reaped = 0
        for claim in claims:
            operation_token = str(uuid.uuid4())
            reserved = await self._repository.reserve_bundle_reap(
                claim.bundle_id,
                operation_token=operation_token,
                now=now,
                stale_before=now - self._operation_timeout,
            )
            if not reserved:
                continue
            try:
                user = await self._repository.get(claim.bundle_id)
                if user is None:
                    await self._repository.abandon_bundle_claim(
                        claim.bundle_id,
                        now=now,
                        operation_token=operation_token,
                    )
                    reaped += 1
                    continue
                await self._admin_client.deactivate_user(user.user_mxid)
                await self._repository.revoke(
                    claim.bundle_id,
                    "Paid bundle claim expired before validated rotation",
                )
                await self._repository.abandon_bundle_claim(
                    claim.bundle_id,
                    now=now,
                    operation_token=operation_token,
                )
                reaped += 1
            except Exception:  # noqa: BLE001 - isolate and retry one claim later
                logger.exception("Could not reap expired paid bundle %s", claim.bundle_id)
                await self._repository.reschedule_bundle_claim_reap(
                    claim.bundle_id,
                    next_reap_at=now + self._failure_retry_delay,
                    operation_token=operation_token,
                )
        return reaped
