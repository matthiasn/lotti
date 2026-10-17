"""Erases the accounts of subscribers who stayed lapsed past the grace window.

Suspension is reversible and keeps everything, so a renewal restores sync
exactly where it stopped. Kept forever, though, a lapsed account is personal
data with no purpose left. After ``erase_after`` of continuous suspension this
reaper deletes the user's media, deletes and purges their sync room, erases
the Matrix account and revokes the record — in that order, so a failure part
way leaves the account suspended and the next run finishes the job.

The user's own devices still hold their memories; only the server copy goes.
"""

from __future__ import annotations

import logging
from collections.abc import Callable
from datetime import datetime, timedelta, timezone

from shared.matrix import SynapseAdminClient

from .periodic_task import PeriodicTask
from .subscription_repository import SubscriptionRepository

logger = logging.getLogger(__name__)

DEFAULT_ERASE_AFTER = timedelta(days=30)


class LapsedAccountReaper(PeriodicTask):
    """Periodically erases accounts suspended for longer than ``erase_after``."""

    def __init__(
        self,
        repository: SubscriptionRepository,
        admin_client: SynapseAdminClient,
        *,
        erase_after: timedelta = DEFAULT_ERASE_AFTER,
        interval_seconds: float = 3600,
        startup_delay_seconds: float = 300,
        batch_size: int = 20,
        now_provider: Callable[[], datetime] | None = None,
    ):
        if erase_after < timedelta(days=7):
            # Shorter than a payment provider's own retry schedule, a card
            # that recovers on its last retry would find its journal gone.
            raise ValueError("Lapsed accounts must be kept at least 7 days")
        super().__init__(
            name="Lapsed account reaper",
            interval_seconds=interval_seconds,
            startup_delay_seconds=startup_delay_seconds,
        )
        self._repository = repository
        self._admin_client = admin_client
        self._erase_after = erase_after
        self._batch_size = batch_size
        self._now_provider = now_provider or (lambda: datetime.now(timezone.utc))

    async def run_once(self) -> None:
        """Run one batch for the periodic loop."""
        await self.reap_once()

    async def reap_once(self) -> int:
        """Erase one batch of lapsed accounts; return how many were erased."""
        now = self._now_provider()
        erased = 0
        for user in await self._repository.list_lapsed_accounts(
            suspended_before=now - self._erase_after,
            limit=self._batch_size,
        ):
            try:
                # Everything uploaded up to now: the account can send nothing
                # more while suspended.
                await self._admin_client.delete_user_media(
                    user.user_mxid,
                    before_ts_ms=int(now.timestamp() * 1000),
                )
                await self._admin_client.delete_room(user.room_id)
                await self._admin_client.erase_user(user.user_mxid)
            except Exception as exc:  # noqa: BLE001 - one account must not stop the batch
                logger.warning("Could not erase lapsed account %s: %s", user.user_mxid, exc)
                continue
            await self._repository.revoke(
                user.bundle_id,
                f"Erased after {self._erase_after.days} days of lapsed subscription",
            )
            erased += 1
        if erased:
            logger.info("Erased %s lapsed account(s)", erased)
        return erased
