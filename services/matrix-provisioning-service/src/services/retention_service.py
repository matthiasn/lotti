"""Sync-room history retention via the Synapse purge API.

Lotti sync rooms accumulate every replicated event forever, which is the bulk of
per-user storage on a small community server. Trimming them is safe, but the
reason is more specific than "devices have their own copy".

**Room history is the primary catch-up path, not a fallback.** When a device
reconnects, ``BridgeCoordinator`` runs a catch-up walk anchored on its
``last_applied_event_id`` marker — an anchored forward walk over
``/context/{eventId}`` then ``/messages?dir=f``, or a timestamp-bounded backward
walk for fresh or unsafe anchors. That walk reads room history directly.

Only counters still missing *after* that walk are marked ``missing`` in the
sequence log and escalated to peer-to-peer repair via
``BackfillRequestService.nudge()`` (``SyncBackfillRequest`` /
``SyncBackfillResponse``). Backfill is the gap-repair fallback.

So the retention window is exactly the bound on how long a device can be offline
and still catch up from the room alone. Past it, the walk cannot cover the gap
and repair depends on a peer that still holds the payload. That is usually fine
— peers keep their own local database — but it is a real dependency, not a free
one, and it is why the window has a floor rather than being freely shrinkable.

Two further facts make the purge itself correct:

* Sync rooms are created with ``m.federate: False``, so every event in them is a
  *local* event. Synapse's purge API defaults to ``delete_local_events: false``,
  under which a purge of these rooms would report success and free nothing. The
  admin client always sends the flag as true.
* Synapse never purges the most recent events or the current room state, so a
  purge cannot leave a room unusable even at an aggressive cutoff.

When repair does fail, it fails visibly: the entry retires to ``unresolvable``
(reopenable by a later hint or an explicit "ask peers again") or to ``deleted``
when a responder confirms the payload is gone. It does not silently corrupt.
"""

from __future__ import annotations

import logging
from datetime import datetime, timedelta, timezone

import httpx

from shared.matrix import ProvisioningError, SynapseAdminClient

from ..core.constants import DEFAULT_RETENTION_DAYS, MIN_RETENTION_DAYS
from ..core.exceptions import BundleNotFoundException, SynapseUnavailableException
from .provisioning_repository import ProvisioningRepository

logger = logging.getLogger(__name__)


class RetentionService:
    """Purges sync-room history older than a retention window."""

    def __init__(
        self,
        repository: ProvisioningRepository,
        admin_client: SynapseAdminClient,
        *,
        default_retention_days: int = DEFAULT_RETENTION_DAYS,
    ) -> None:
        self._repository = repository
        self._admin_client = admin_client
        self._default_retention_days = default_retention_days

    @staticmethod
    def _cutoff_ms(retention_days: int) -> int:
        """Return the epoch-millisecond cutoff for a retention window."""
        cutoff = datetime.now(timezone.utc) - timedelta(days=retention_days)
        return int(cutoff.timestamp() * 1000)

    def _validate_retention(self, retention_days: int | None) -> int:
        # Explicitly `is None`, not falsy: a caller passing 0 means "purge
        # everything", which must hit the floor check rather than silently
        # falling back to the default window.
        resolved = (
            self._default_retention_days if retention_days is None else retention_days
        )
        if resolved < MIN_RETENTION_DAYS:
            raise ValueError(
                f"Retention must be at least {MIN_RETENTION_DAYS} days "
                f"so devices with a normal offline window can still catch up "
                f"from room history (requested {resolved})"
            )
        return resolved

    async def purge_room(self, bundle_id: str, retention_days: int | None = None) -> dict:
        """Purge one user's sync-room history older than the retention window.

        Args:
            bundle_id: Which provisioned user's room to purge.
            retention_days: Override for the default window.

        Returns:
            A dict with the purge ID, room ID and cutoff timestamp.

        Raises:
            BundleNotFoundException: If the bundle is unknown.
            ValueError: If the retention window is below the floor.
            SynapseUnavailableException: If Synapse rejects the purge.
        """
        resolved_days = self._validate_retention(retention_days)

        user = await self._repository.get(bundle_id)
        if user is None:
            raise BundleNotFoundException(bundle_id)

        cutoff_ms = self._cutoff_ms(resolved_days)
        try:
            handle = await self._admin_client.purge_room_history(user.room_id, cutoff_ms)
        except (httpx.HTTPError, ProvisioningError) as exc:
            raise SynapseUnavailableException(
                f"Purge failed for room {user.room_id}: {exc}"
            ) from exc

        await self._repository.record_purge(
            handle.purge_id, bundle_id, user.room_id, cutoff_ms
        )
        logger.info(
            "Started purge %s for room %s (cutoff %s, %sd retention)",
            handle.purge_id,
            user.room_id,
            cutoff_ms,
            resolved_days,
        )
        return {
            "purge_id": handle.purge_id,
            "room_id": user.room_id,
            "bundle_id": bundle_id,
            "purge_up_to_ts": cutoff_ms,
            "retention_days": resolved_days,
        }

    async def refresh_purge_status(self, purge_id: str) -> str:
        """Poll Synapse for a purge's status and persist it.

        Returns:
            The current status string reported by Synapse.
        """
        try:
            status = await self._admin_client.get_purge_status(purge_id)
        except (httpx.HTTPError, ProvisioningError) as exc:
            raise SynapseUnavailableException(
                f"Could not read purge status for {purge_id}: {exc}"
            ) from exc

        await self._repository.update_purge_status(purge_id, status.status)
        return status.status

    async def purge_all(self, retention_days: int | None = None) -> list[dict]:
        """Purge every tracked sync room that has actually been used.

        Unredeemed and revoked bundles are skipped: an unredeemed room holds
        nothing worth purging, and a revoked one may be pending investigation.

        Returns:
            One result dict per room a purge was started for.
        """
        resolved_days = self._validate_retention(retention_days)

        started: list[dict] = []
        page = 1
        while True:
            users, total = await self._repository.list_users(page=page, page_size=100)
            if not users:
                break
            for user in users:
                if user.first_login_at is None or user.revoked_at is not None:
                    continue
                try:
                    started.append(await self.purge_room(user.bundle_id, resolved_days))
                except SynapseUnavailableException as exc:
                    logger.warning(
                        "Skipping purge for %s: %s", user.user_mxid, exc
                    )
            if page * 100 >= total:
                break
            page += 1

        logger.info("Started %s purge(s) at %sd retention", len(started), resolved_days)
        return started
