"""Read-only Synapse admin API queries.

Used by the redemption poller (Phase 2) to infer whether a provisioned account
has been signed into, and by the stats endpoints (Phase 3) to report per-user
activity and media usage.
"""

from __future__ import annotations

import logging
from dataclasses import dataclass
from typing import Callable
from urllib.parse import quote

import httpx

from .provisioner import AdminCredentials, ProvisioningError, encode_mxid_for_path

logger = logging.getLogger(__name__)


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


class SynapseAdminClient:
    """Queries the Synapse admin API for user activity and usage stats."""

    def __init__(
        self,
        credentials: AdminCredentials,
        *,
        transport: httpx.AsyncBaseTransport | None = None,
        timeout: float = 30.0,
        log: Callable[[str], None] | None = None,
    ) -> None:
        self._credentials = credentials
        self._transport = transport
        self._timeout = timeout
        self._log = log or logger.debug
        self._cached_headers: dict | None = None

    def _client(self) -> httpx.AsyncClient:
        kwargs: dict = {"base_url": self._credentials.base_url, "timeout": self._timeout}
        if self._transport is not None:
            kwargs["transport"] = self._transport
        return httpx.AsyncClient(**kwargs)

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
        async with self._client() as client:
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
        """Fetch aggregate media count and byte usage for a user."""
        encoded = encode_mxid_for_path(user_mxid)
        async with self._client() as client:
            headers = await self._auth_headers(client)
            resp = await client.get(
                f"/_synapse/admin/v1/users/{encoded}/media", headers=headers
            )
            resp.raise_for_status()
            payload = resp.json()

        media = payload.get("media", [])
        total_bytes = sum(int(item.get("media_length", 0)) for item in media)
        return UserMediaUsage(
            user_mxid=user_mxid,
            media_count=int(payload.get("total", len(media))),
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
        encoded_room = quote(room_id, safe="")
        async with self._client() as client:
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

    async def get_purge_status(self, purge_id: str) -> PurgeStatus:
        """Poll the status of a previously started purge."""
        async with self._client() as client:
            headers = await self._auth_headers(client)
            resp = await client.get(
                f"/_synapse/admin/v1/purge_history_status/{quote(purge_id, safe='')}",
                headers=headers,
            )
            resp.raise_for_status()
            status = resp.json().get("status", "unknown")

        return PurgeStatus(purge_id=purge_id, status=status)

    async def deactivate_user(self, user_mxid: str) -> None:
        """Deactivate a user account.

        Raises:
            ProvisioningError: If Synapse rejects the deactivation.
        """
        encoded = encode_mxid_for_path(user_mxid)
        async with self._client() as client:
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
