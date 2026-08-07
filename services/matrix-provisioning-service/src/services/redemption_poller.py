"""Background poller that detects bundle redemption.

The shipped Lotti client rotates the bundle password locally and tells no one,
so the server cannot observe redemption directly. This poller infers it from
Synapse device activity: a freshly provisioned account has one device (the
short-lived session the provisioner used to build the sync room) and no
``last_seen_ts``. Once a real client signs in, ``last_seen_ts`` appears.

This is deliberately the fallback path. When a client is new enough to call the
rotation-confirmed endpoint, that callback is exact and immediate, and moves the
record straight to ``ROTATED``. Polling exists so accounts redeemed by older
clients are still tracked.
"""

from __future__ import annotations

import logging
from datetime import datetime, timezone

import httpx

from shared.matrix import ProvisioningError, SynapseAdminClient

from ..core.constants import DEFAULT_POLL_BATCH_SIZE, DEFAULT_POLL_INTERVAL_SECONDS
from .periodic_task import PeriodicTask
from .provisioning_repository import ProvisioningRepository

logger = logging.getLogger(__name__)


class RedemptionPoller(PeriodicTask):
    """Periodically reconciles stored bundle status against Synapse."""

    def __init__(
        self,
        repository: ProvisioningRepository,
        admin_client: SynapseAdminClient,
        *,
        interval_seconds: int = DEFAULT_POLL_INTERVAL_SECONDS,
        batch_size: int = DEFAULT_POLL_BATCH_SIZE,
    ) -> None:
        super().__init__(name="Redemption poller", interval_seconds=interval_seconds)
        self._repository = repository
        self._admin_client = admin_client
        self._batch_size = batch_size

    async def run_once(self) -> None:
        """Run one sweep for the background loop."""
        await self.poll_once()

    async def poll_once(self) -> int:
        """Run a single reconciliation sweep.

        Returns:
            The number of bundles newly advanced to ``REDEEMED``.
        """
        candidates = await self._repository.list_pollable(self._batch_size)
        if not candidates:
            return 0

        advanced = 0
        for user in candidates:
            try:
                activity = await self._admin_client.get_user_activity(user.user_mxid)
            except (httpx.HTTPError, ProvisioningError) as exc:
                logger.warning("Poll failed for %s: %s", user.user_mxid, exc)
                await self._repository.touch_poll(user.bundle_id, str(exc))
                continue

            if not activity.has_signed_in:
                await self._repository.touch_poll(user.bundle_id)
                continue

            last_seen = datetime.fromtimestamp(
                activity.last_seen_ts / 1000, tz=timezone.utc
            )
            updated = await self._repository.mark_redeemed(user.bundle_id, last_seen)
            if user.first_login_at is None and updated.first_login_at is not None:
                advanced += 1
                logger.info(
                    "Bundle %s redeemed by %s", user.bundle_id, user.user_mxid
                )

        return advanced
