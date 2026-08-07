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
* Events and media are stored separately, so reclaiming disk needs both:
  ``purge_history`` for the database rows and a media deletion for the files.
  On a journalling app the files are the bulk, so history alone frees little.
  Media is recoverable on the same terms as events — peers still holding a blob
  answer a media-repair broadcast.

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

    async def purge_room(
        self,
        bundle_id: str,
        retention_days: int | None = None,
        include_media: bool = True,
    ) -> dict:
        """Reclaim storage for one user older than the retention window.

        Two distinct operations, because Synapse stores them separately:

        * ``purge_history`` removes room **events** from the database.
        * deleting the user's **media** removes the uploaded files.

        Media is where the disk actually goes on a journalling app, so this
        does both by default. Purging events alone frees very little.

        Args:
            bundle_id: Which provisioned user to reclaim.
            retention_days: Override for the default window.
            include_media: Set false to trim history only and leave files.

        Returns:
            A dict describing both operations, including bytes actually freed.

        Raises:
            BundleNotFoundException: If the bundle is unknown.
            ValueError: If the retention window is below the floor.
            SynapseUnavailableException: If Synapse rejects either operation.
        """
        resolved_days = self._validate_retention(retention_days)

        user = await self._repository.get(bundle_id)
        if user is None:
            raise BundleNotFoundException(bundle_id)

        cutoff_ms = self._cutoff_ms(resolved_days)

        # Measured before and after so the caller can report real reclaimed
        # bytes rather than a file count that means nothing to an operator.
        bytes_before = 0
        if include_media:
            try:
                bytes_before = (
                    await self._admin_client.get_media_usage(user.user_mxid)
                ).media_length_bytes
            except (httpx.HTTPError, ProvisioningError) as exc:
                logger.warning("Could not read media usage for %s: %s", user.user_mxid, exc)

        try:
            handle = await self._admin_client.purge_room_history(user.room_id, cutoff_ms)
        except (httpx.HTTPError, ProvisioningError) as exc:
            raise SynapseUnavailableException(
                f"Purge failed for room {user.room_id}: {exc}"
            ) from exc

        await self._repository.record_purge(
            handle.purge_id, bundle_id, user.room_id, cutoff_ms
        )

        media_deleted = 0
        bytes_freed = 0
        if include_media:
            try:
                deletion = await self._admin_client.delete_user_media(
                    user.user_mxid, cutoff_ms
                )
                media_deleted = deletion.deleted_count
                bytes_after = (
                    await self._admin_client.get_media_usage(user.user_mxid)
                ).media_length_bytes
                bytes_freed = max(0, bytes_before - bytes_after)
            except (httpx.HTTPError, ProvisioningError) as exc:
                # History is already purged at this point; surfacing the media
                # failure as a hard error would hide that partial success.
                raise SynapseUnavailableException(
                    f"History purged for {user.room_id}, but media deletion "
                    f"failed for {user.user_mxid}: {exc}"
                ) from exc

        logger.info(
            "Reclaimed for %s: purge %s, %s media file(s), %s bytes (%sd retention)",
            user.user_mxid,
            handle.purge_id,
            media_deleted,
            bytes_freed,
            resolved_days,
        )
        return {
            "purge_id": handle.purge_id,
            "room_id": user.room_id,
            "bundle_id": bundle_id,
            "purge_up_to_ts": cutoff_ms,
            "retention_days": resolved_days,
            "media_deleted": media_deleted,
            "bytes_freed": bytes_freed,
            "include_media": include_media,
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

    async def purge_all(
        self, retention_days: int | None = None, include_media: bool = True
    ) -> list[dict]:
        """Reclaim storage across every user the sweep is allowed to touch.

        Each user's own ``retention_days`` wins over the argument, which in turn
        wins over the service default — so pinning one user to a longer window
        survives a change to the global setting.

        Users are selected in SQL (redeemed, not revoked, not exempt) rather
        than filtered in Python after paging the whole roster.

        Args:
            retention_days: Window for users with no override of their own.
            include_media: Passed through; false trims history only.

        Returns:
            One result dict per user a purge was started for.
        """
        fallback_days = self._validate_retention(retention_days)

        started: list[dict] = []
        skipped = 0
        for user in await self._repository.list_purgeable():
            window = user.retention_days or fallback_days
            try:
                window = self._validate_retention(window)
            except ValueError as exc:
                logger.warning("Skipping %s: %s", user.user_mxid, exc)
                skipped += 1
                continue
            try:
                started.append(
                    await self.purge_room(user.bundle_id, window, include_media)
                )
            except SynapseUnavailableException as exc:
                logger.warning("Skipping purge for %s: %s", user.user_mxid, exc)
                skipped += 1

        freed = sum(result["bytes_freed"] for result in started)
        logger.info(
            "Retention sweep: %s purged, %s skipped, %s bytes reclaimed",
            len(started),
            skipped,
            freed,
        )
        return started
