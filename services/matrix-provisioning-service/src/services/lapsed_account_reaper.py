"""Erases the accounts of subscribers who stayed lapsed past the grace window.

Suspension is reversible and keeps everything, so a renewal restores sync
exactly where it stopped. Kept forever, though, a lapsed account is personal
data with no purpose left. After ``erase_after`` of continuous suspension this
reaper claims the account in the erasure ledger — which revokes it and
detaches it from its subscription in one transaction, so a renewal can no
longer unsuspend it — then deletes the user's media, deletes and purges the
sync room, and erases the Matrix user. Each step is recorded; a run that fails
part way resumes at the first unfinished step.

The user's own devices still hold their memories; only the server copy goes.
"""

from __future__ import annotations

import logging
from collections.abc import Callable
from datetime import datetime, timedelta, timezone

from shared.matrix import SynapseAdminClient

from .account_erasure_repository import AccountErasure, AccountErasureRepository
from .periodic_task import PeriodicTask

logger = logging.getLogger(__name__)

DEFAULT_ERASE_AFTER = timedelta(days=30)


class LapsedAccountReaper(PeriodicTask):
    """Periodically erases accounts suspended for longer than ``erase_after``."""

    def __init__(
        self,
        repository: AccountErasureRepository,
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
        """Claim newly lapsed accounts, advance every open erasure; return how many finished."""
        now = self._now_provider()
        for user in await self._repository.list_lapsed_accounts(
            suspended_before=now - self._erase_after,
            limit=self._batch_size,
        ):
            try:
                await self._repository.claim_erasure(
                    user.bundle_id,
                    suspended_before=now - self._erase_after,
                    now=now,
                )
            except Exception as exc:  # noqa: BLE001 - claim the rest, advance the open ones
                logger.warning("Could not claim lapsed account %s: %s", user.user_mxid, exc)
        erased = 0
        for erasure in await self._repository.list_open_erasures(limit=self._batch_size):
            try:
                await self._advance(erasure)
            except Exception as exc:  # noqa: BLE001 - one account must not stop the batch
                logger.warning("Could not erase lapsed account %s: %s", erasure.user_mxid, exc)
                await self._repository.record_erasure_error(erasure.bundle_id, str(exc))
                continue
            erased += 1
        if erased:
            logger.info("Erased %s lapsed account(s)", erased)
        return erased

    async def _advance(self, erasure: AccountErasure) -> None:
        now = self._now_provider()
        if erasure.media_deleted_at is None:
            # Everything uploaded up to now: a suspended account sends nothing.
            await self._admin_client.delete_user_media(
                erasure.user_mxid,
                before_ts_ms=int(now.timestamp() * 1000),
            )
            await self._repository.record_erasure_step(
                erasure.bundle_id, "media_deleted_at", now=now
            )
        if erasure.room_deleted_at is None:
            await self._admin_client.delete_room(erasure.room_id)
            await self._repository.record_erasure_step(
                erasure.bundle_id, "room_deleted_at", now=self._now_provider()
            )
        if erasure.user_erased_at is None:
            await self._admin_client.erase_user(erasure.user_mxid)
            await self._repository.record_erasure_step(
                erasure.bundle_id, "user_erased_at", now=self._now_provider()
            )
        await self._repository.complete_erasure(erasure.bundle_id, now=self._now_provider())
