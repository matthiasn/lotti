"""Read-only Synapse admin API queries.

Used by the redemption poller (Phase 2) to infer whether a provisioned account
has been signed into, and by the stats endpoints (Phase 3) to report per-user
activity and media usage.
"""

from __future__ import annotations

import logging
from dataclasses import dataclass

import httpx

from .core import (
    AdminCredentials,
    ProvisioningError,
    SynapseClientBase,
    encode_mxid_for_path,
    encode_room_id_for_path,
)

logger = logging.getLogger(__name__)

#: Synapse's own page size for the per-user media endpoints. Both the listing
#: and the delete cap out at this many rows per call regardless of what we ask
#: for, so the only way to cover a real account is to follow the pages.
MEDIA_PAGE_SIZE = 100

#: Hard stop on media paging. At the page size above this covers a million
#: files; past it something is wrong (a homeserver that never advances its
#: cursor would otherwise loop forever).
MAX_MEDIA_PAGES = 10_000


@dataclass(frozen=True)
class UserActivity:
    """Observed sign-in activity for a provisioned account."""

    user_mxid: str
    device_count: int
    last_seen_ts: int | None
    deactivated: bool

    @property
    def has_signed_in(self) -> bool:
        """Whether the account shows any evidence of a completed sign-in.

        A freshly provisioned account has exactly one device — the short-lived
        session the provisioner used to create the sync room — which is why
        device count alone is not sufficient. ``last_seen_ts`` being set on any
        device is the reliable signal that a real client has connected.
        """
        return self.last_seen_ts is not None


@dataclass(frozen=True)
class UserMediaUsage:
    """Aggregate media statistics for a user."""

    user_mxid: str
    media_count: int
    media_length_bytes: int


@dataclass(frozen=True)
class MediaDeletion:
    """Result of deleting a user's media from the homeserver."""

    user_mxid: str
    deleted_count: int


@dataclass(frozen=True)
class PurgeHandle:
    """A started history purge, to be polled for completion."""

    purge_id: str
    room_id: str


@dataclass(frozen=True)
class PurgeStatus:
    """The state Synapse reports for a purge job."""

    purge_id: str
    status: str

    @property
    def is_complete(self) -> bool:
        """Whether the purge finished successfully."""
        return self.status == "complete"

    @property
    def is_failed(self) -> bool:
        """Whether the purge failed."""
        return self.status == "failed"

    @property
    def is_running(self) -> bool:
        """Whether the purge is still in progress."""
        return self.status == "active"


class SynapseAdminClient(SynapseClientBase):
    """Queries the Synapse admin API for user activity and usage stats.

    Long-lived: the service holds one instance, and both the redemption poller
    and the retention sweep call it once per user in a loop. It therefore keeps
    a single httpx client open so those loops reuse connections rather than
    completing a fresh TLS handshake per user. Call :meth:`aclose` on shutdown.
    """

    _cached_headers: dict | None = None
    _shared_client: httpx.AsyncClient | None = None

    def _client(self) -> httpx.AsyncClient:
        """Return the shared client, opening it on first use."""
        if self._shared_client is None or self._shared_client.is_closed:
            self._shared_client = self._new_client()
        return self._shared_client

    async def aclose(self) -> None:
        """Close the shared client. Safe to call more than once."""
        if self._shared_client is not None and not self._shared_client.is_closed:
            await self._shared_client.aclose()
        self._shared_client = None

    async def _auth_headers(self, client: httpx.AsyncClient) -> dict:
        """Resolve admin auth headers, preferring a configured token.

        The password-login result is cached for the client's lifetime so a
        polling sweep does not re-login for every user.
        """
        if self._cached_headers is not None:
            return self._cached_headers

        creds = self._credentials
        if creds.admin_token:
            headers = {"Authorization": f"Bearer {creds.admin_token}"}
        else:
            resp = await client.post(
                "/_matrix/client/v3/login",
                json={
                    "type": "m.login.password",
                    "user": creds.admin_user,
                    "password": creds.admin_password,
                },
            )
            resp.raise_for_status()
            headers = {"Authorization": f"Bearer {resp.json()['access_token']}"}

        self._cached_headers = headers
        return headers

    async def get_user_activity(self, user_mxid: str) -> UserActivity:
        """Fetch device and last-seen information for a user.

        Args:
            user_mxid: Full MXID, e.g. ``@lotti_sync_user42:example.com``.

        Returns:
            The observed activity.

        Raises:
            httpx.HTTPStatusError: If Synapse returns an error status.
        """
        encoded = encode_mxid_for_path(user_mxid)
        client = self._client()
        headers = await self._auth_headers(client)

        resp = await client.get(f"/_synapse/admin/v2/users/{encoded}", headers=headers)
        resp.raise_for_status()
        deactivated = bool(resp.json().get("deactivated", False))

        resp = await client.get(
            f"/_synapse/admin/v2/users/{encoded}/devices", headers=headers
        )
        resp.raise_for_status()
        devices = resp.json().get("devices", [])

        seen = [d.get("last_seen_ts") for d in devices if d.get("last_seen_ts")]
        return UserActivity(
            user_mxid=user_mxid,
            device_count=len(devices),
            last_seen_ts=max(seen) if seen else None,
            deactivated=deactivated,
        )

    async def get_media_usage(self, user_mxid: str) -> UserMediaUsage:
        """Fetch aggregate media count and byte usage for a user.

        Follows Synapse's ``next_token`` pagination to the end. Summing only the
        first page would under-report the byte total for anyone with more than
        :data:`MEDIA_PAGE_SIZE` files while still reporting the true file count
        from ``total`` — and the retention report subtracts these figures, so a
        truncated total would make a large purge look like it reclaimed nothing.
        """
        encoded = encode_mxid_for_path(user_mxid)
        client = self._client()
        headers = await self._auth_headers(client)

        total_bytes = 0
        seen = 0
        reported_total: int | None = None
        params: dict = {"limit": MEDIA_PAGE_SIZE}

        for _ in range(MAX_MEDIA_PAGES):
            resp = await client.get(
                f"/_synapse/admin/v1/users/{encoded}/media",
                headers=headers,
                params=params,
            )
            resp.raise_for_status()
            payload = resp.json()

            media = payload.get("media", [])
            total_bytes += sum(int(item.get("media_length", 0)) for item in media)
            seen += len(media)
            if reported_total is None and "total" in payload:
                reported_total = int(payload["total"])

            next_token = payload.get("next_token")
            if next_token is None or not media:
                break
            params = {"limit": MEDIA_PAGE_SIZE, "from": next_token}
        else:
            logger.warning(
                "Stopped paging media for %s after %s pages; byte total may be "
                "short of the real figure",
                user_mxid,
                MAX_MEDIA_PAGES,
            )

        return UserMediaUsage(
            user_mxid=user_mxid,
            media_count=seen if reported_total is None else reported_total,
            media_length_bytes=total_bytes,
        )

    async def purge_room_history(self, room_id: str, purge_up_to_ts_ms: int) -> PurgeHandle:
        """Purge a sync room's history older than a timestamp.

        ``delete_local_events`` is always sent as ``True``. Lotti sync rooms are
        created with ``m.federate: False``, which makes every event in them a
        local event; with the API's default of ``False`` the purge would report
        success while reclaiming nothing.

        This deletes the homeserver's copy of the events only; devices keep
        their local data. Note that room history is the *primary* catch-up
        source for a reconnecting device (the anchored timeline walk), so the
        cutoff bounds how far back a device can resynchronise from the room.
        Gaps older than the cutoff fall through to peer-to-peer backfill.

        Args:
            room_id: The sync room to purge.
            purge_up_to_ts_ms: Unix epoch milliseconds; events strictly older
                than this are removed.

        Returns:
            A handle for polling completion.

        Raises:
            httpx.HTTPStatusError: If Synapse rejects the purge request.
            ProvisioningError: If Synapse does not return a purge ID.
        """
        encoded_room = encode_room_id_for_path(room_id)
        client = self._client()
        headers = await self._auth_headers(client)
        resp = await client.post(
            f"/_synapse/admin/v1/purge_history/{encoded_room}",
            headers=headers,
            json={
                "delete_local_events": True,
                "purge_up_to_ts": purge_up_to_ts_ms,
            },
        )
        resp.raise_for_status()
        purge_id = resp.json().get("purge_id")

        if not purge_id:
            raise ProvisioningError(f"Synapse did not return a purge_id for room {room_id}")
        return PurgeHandle(purge_id=purge_id, room_id=room_id)

    async def delete_user_media(
        self, user_mxid: str, before_ts_ms: int
    ) -> MediaDeletion:
        """Delete media uploaded by a user before a timestamp.

        This is what actually reclaims disk. ``purge_history`` removes events
        from the database; the uploaded files live in Synapse's separate media
        store and survive it, so trimming history alone frees very little on a
        server whose bulk is attachments.

        Safe for Lotti sync rooms specifically: each room is private,
        non-federated and has a single member, so that user's media is not
        referenced by anyone else. A device that has not downloaded a blob yet
        can still recover it peer-to-peer through media repair, on the same
        terms as event backfill — any peer still holding the file may answer.

        Synapse deletes at most :data:`MEDIA_PAGE_SIZE` files per call, so this
        repeats until a call reports nothing left to delete. A single call would
        cap the reclaim at 100 files however much the account is holding.

        Args:
            user_mxid: Owner of the media.
            before_ts_ms: Unix epoch milliseconds; media uploaded strictly
                before this is deleted.

        Returns:
            How many files were removed in total.

        Raises:
            httpx.HTTPStatusError: If Synapse rejects the request.
        """
        encoded = encode_mxid_for_path(user_mxid)
        client = self._client()
        headers = await self._auth_headers(client)

        deleted_total = 0
        for _ in range(MAX_MEDIA_PAGES):
            resp = await client.delete(
                f"/_synapse/admin/v1/users/{encoded}/media",
                headers=headers,
                params={"before_ts": before_ts_ms, "limit": MEDIA_PAGE_SIZE},
            )
            resp.raise_for_status()
            payload = resp.json()

            deleted = payload.get("deleted_media") or []
            batch = int(payload.get("total", len(deleted)))
            deleted_total += batch
            if batch == 0:
                break
        else:
            logger.warning(
                "Stopped deleting media for %s after %s batches; some files may "
                "remain",
                user_mxid,
                MAX_MEDIA_PAGES,
            )

        return MediaDeletion(user_mxid=user_mxid, deleted_count=deleted_total)

    async def get_purge_status(self, purge_id: str) -> PurgeStatus:
        """Poll the status of a previously started purge."""
        client = self._client()
        headers = await self._auth_headers(client)
        resp = await client.get(
            f"/_synapse/admin/v1/purge_history_status/"
            f"{encode_room_id_for_path(purge_id)}",
            headers=headers,
        )
        resp.raise_for_status()
        return PurgeStatus(purge_id=purge_id, status=resp.json().get("status", "unknown"))

    async def deactivate_user(self, user_mxid: str) -> None:
        """Deactivate a user account.

        Raises:
            ProvisioningError: If Synapse rejects the deactivation.
        """
        encoded = encode_mxid_for_path(user_mxid)
        client = self._client()
        headers = await self._auth_headers(client)
        resp = await client.put(
            f"/_synapse/admin/v2/users/{encoded}",
            headers=headers,
            json={"deactivated": True},
        )
        if not resp.is_success:
            raise ProvisioningError(
                f"Failed to deactivate {user_mxid} (HTTP {resp.status_code})"
            )
