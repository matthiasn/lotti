"""Reusable Synapse provisioning flow.

This is the shared core behind both the ``matrix_provisioner`` CLI and the
matrix-provisioning-service web API. It creates a Matrix user and an encrypted
Lotti sync room, and returns the provisioning bundle.

The flow is deliberately identical to the original CLI implementation, including
its rollback behaviour: if anything fails after the user has been created, the
orphan account is deactivated on a best-effort basis before the error surfaces.
"""

from __future__ import annotations

import logging
import secrets
import time
from dataclasses import dataclass
from typing import Callable
from urllib.parse import quote

import httpx

from .bundle import BundleKind, SyncBundle

logger = logging.getLogger(__name__)

#: Length in bytes of the generated password entropy; token_urlsafe(32) yields
#: a 43-character string.
PASSWORD_ENTROPY_BYTES = 32

#: Lifetime of the short-lived user token minted to create the sync room.
USER_TOKEN_LIFETIME_MS = 10 * 60 * 1000

#: State event marking a room as a Lotti sync room, used for room discovery.
SYNC_ROOM_STATE_TYPE = "m.lotti.sync_room"
SYNC_ROOM_STATE_VERSION = 1

MEGOLM_ALGORITHM = "m.megolm.v1.aes-sha2"


def encode_mxid_for_path(mxid: str) -> str:
    """URL-encode a Matrix user ID for use in a URL path segment.

    MXIDs can contain characters like ``/`` that are significant in URL paths,
    so the entire MXID is percent-encoded (with ``safe=""``) before
    interpolation. This prevents path traversal via crafted localparts.
    """
    return quote(mxid, safe="")


def encode_room_id_for_path(room_id: str) -> str:
    """URL-encode a Matrix room ID for use in a URL path segment."""
    return quote(room_id, safe="")


class ProvisioningError(ValueError):
    """Raised when the homeserver returns a malformed or unusable response.

    Subclasses ``ValueError`` because every case is a bad value coming back from
    Synapse — a login response without a parseable MXID, a purge without an ID.
    """


@dataclass(frozen=True)
class AdminCredentials:
    """How to authenticate against the Synapse admin API.

    A long-lived ``admin_token`` is preferred: it avoids keeping a password at
    rest and can be revoked independently. When no token is set, the flow falls
    back to password login, which is what the interactive CLI uses.
    """

    homeserver: str
    admin_token: str | None = None
    admin_user: str | None = None
    admin_password: str | None = None

    def __post_init__(self) -> None:
        if not self.homeserver:
            raise ValueError("homeserver is required")
        if not self.admin_token and not (self.admin_user and self.admin_password):
            raise ValueError(
                "Provide either admin_token, or both admin_user and admin_password"
            )

    @property
    def base_url(self) -> str:
        """The homeserver URL without a trailing slash."""
        return self.homeserver.rstrip("/")


@dataclass(frozen=True)
class ProvisionResult:
    """Everything the caller needs to record about a successful provision."""

    bundle: SyncBundle
    user_mxid: str
    room_id: str
    server_name: str

    @property
    def encoded_bundle(self) -> str:
        """The Base64url bundle string to hand to the user."""
        return self.bundle.encode()


class SynapseProvisioner:
    """Creates Lotti sync accounts and rooms on a Synapse homeserver."""

    def __init__(
        self,
        credentials: AdminCredentials,
        *,
        transport: httpx.AsyncBaseTransport | None = None,
        timeout: float = 30.0,
        log: Callable[[str], None] | None = None,
    ) -> None:
        """Initialise the provisioner.

        Args:
            credentials: Admin authentication details.
            transport: Optional HTTP transport, for tests.
            timeout: Per-request timeout in seconds.
            log: Optional progress sink. Defaults to module-level logging; the
                CLI passes a callable that writes to stderr.
        """
        self._credentials = credentials
        self._transport = transport
        self._timeout = timeout
        self._log = log or logger.info

    def _client(self) -> httpx.AsyncClient:
        kwargs: dict = {"base_url": self._credentials.base_url, "timeout": self._timeout}
        if self._transport is not None:
            kwargs["transport"] = self._transport
        return httpx.AsyncClient(**kwargs)

    @staticmethod
    def _server_name_from_mxid(mxid: str) -> str:
        """Extract the domain part from an MXID (``@user:server`` → ``server``)."""
        if ":" not in mxid:
            raise ProvisioningError(f"Invalid MXID (no ':' separator): {mxid!r}")
        server_name = mxid.split(":", 1)[1]
        if not server_name:
            raise ProvisioningError(f"MXID has an empty domain part: {mxid!r}")
        return server_name

    async def _authenticate(self, client: httpx.AsyncClient) -> tuple[dict, str]:
        """Resolve admin auth headers and the homeserver's server name.

        Prefers the configured admin token, falling back to password login.

        Returns:
            A ``(headers, server_name)`` tuple.
        """
        creds = self._credentials

        if creds.admin_token:
            self._log("Authenticating with admin token...")
            headers = {"Authorization": f"Bearer {creds.admin_token}"}
            resp = await client.get("/_matrix/client/v3/account/whoami", headers=headers)
            resp.raise_for_status()
            admin_mxid = resp.json().get("user_id", "")
            if not admin_mxid:
                raise ProvisioningError("whoami did not return a user_id for the admin token")
        else:
            self._log(f"Logging in as admin '{creds.admin_user}'...")
            resp = await client.post(
                "/_matrix/client/v3/login",
                json={
                    "type": "m.login.password",
                    "user": creds.admin_user,
                    "password": creds.admin_password,
                },
            )
            resp.raise_for_status()
            login_data = resp.json()
            headers = {"Authorization": f"Bearer {login_data['access_token']}"}
            admin_mxid = login_data["user_id"]

        server_name = self._server_name_from_mxid(admin_mxid)
        self._log(f"Server name: {server_name}")
        return headers, server_name

    async def _deactivate_user(
        self,
        client: httpx.AsyncClient,
        admin_headers: dict,
        user_mxid: str,
    ) -> None:
        """Best-effort deactivation of an orphan user after a partial failure."""
        encoded = encode_mxid_for_path(user_mxid)
        try:
            resp = await client.put(
                f"/_synapse/admin/v2/users/{encoded}",
                headers=admin_headers,
                json={"deactivated": True},
            )
            if resp.is_success:
                self._log(f"Rolled back: deactivated orphan user {user_mxid}")
            else:
                self._log(
                    f"Warning: failed to deactivate orphan user {user_mxid} "
                    f"(HTTP {resp.status_code})"
                )
        except httpx.RequestError as exc:
            self._log(f"Warning: could not deactivate orphan user {user_mxid}: {exc}")

    async def provision(
        self,
        username: str,
        display_name: str | None = None,
    ) -> ProvisionResult:
        """Create a Lotti sync user and their encrypted sync room.

        Args:
            username: Localpart for the new user (e.g. ``lotti_sync_user42``).
            display_name: Optional display name. Defaults to
                ``Lotti Sync (<username>)``.

        Returns:
            The provisioning result, including the bundle to hand to the user.

        Raises:
            httpx.HTTPStatusError: If any Synapse call returns an error status.
            ProvisioningError: If Synapse returns a malformed response.
        """
        if not username:
            raise ValueError("username is required")

        async with self._client() as client:
            admin_headers, server_name = await self._authenticate(client)

            password = secrets.token_urlsafe(PASSWORD_ENTROPY_BYTES)

            user_mxid = f"@{username}:{server_name}"
            encoded_mxid = encode_mxid_for_path(user_mxid)
            resolved_display_name = display_name or f"Lotti Sync ({username})"
            room_name = f"Lotti Sync ({username})"

            self._log(f"Creating user {user_mxid}...")
            resp = await client.put(
                f"/_synapse/admin/v2/users/{encoded_mxid}",
                headers=admin_headers,
                json={
                    "password": password,
                    "admin": False,
                    "displayname": resolved_display_name,
                },
            )
            resp.raise_for_status()
            self._log(f"User created: {user_mxid}")

            # From here on, any failure leaves an orphan account behind unless
            # we roll it back.
            try:
                room_id = await self._create_sync_room(
                    client, admin_headers, encoded_mxid, room_name
                )
            except Exception:
                await self._deactivate_user(client, admin_headers, user_mxid)
                raise

            bundle = SyncBundle(
                home_server=self._credentials.base_url,
                user=user_mxid,
                password=password,
                room_id=room_id,
                kind=BundleKind.PROVISIONED,
            )

            return ProvisionResult(
                bundle=bundle,
                user_mxid=user_mxid,
                room_id=room_id,
                server_name=server_name,
            )

    async def _create_sync_room(
        self,
        client: httpx.AsyncClient,
        admin_headers: dict,
        encoded_mxid: str,
        room_name: str,
    ) -> str:
        """Mint a short-lived user token and create the encrypted sync room."""
        valid_until_ms = int(time.time() * 1000) + USER_TOKEN_LIFETIME_MS

        self._log("Obtaining user token...")
        resp = await client.post(
            f"/_synapse/admin/v1/users/{encoded_mxid}/login",
            headers=admin_headers,
            json={"valid_until_ms": valid_until_ms},
        )
        resp.raise_for_status()
        user_token = resp.json()["access_token"]
        user_headers = {"Authorization": f"Bearer {user_token}"}

        self._log("Creating sync room...")
        resp = await client.post(
            "/_matrix/client/v3/createRoom",
            headers=user_headers,
            json={
                "visibility": "private",
                "name": room_name,
                "preset": "trusted_private_chat",
                "creation_content": {"m.federate": False},
                "initial_state": [
                    {
                        "type": "m.room.encryption",
                        "state_key": "",
                        "content": {"algorithm": MEGOLM_ALGORITHM},
                    },
                    {
                        "type": SYNC_ROOM_STATE_TYPE,
                        "state_key": "",
                        "content": {"version": SYNC_ROOM_STATE_VERSION},
                    },
                ],
            },
        )
        resp.raise_for_status()
        room_id = resp.json()["room_id"]
        self._log(f"Room created: {room_id}")

        # Some homeserver versions/setups ignore parts of initial_state, so the
        # critical state is re-enforced explicitly.
        encoded_room_id = encode_room_id_for_path(room_id)

        self._log("Enforcing room encryption state...")
        resp = await client.put(
            f"/_matrix/client/v3/rooms/{encoded_room_id}/state/m.room.encryption",
            headers=user_headers,
            json={"algorithm": MEGOLM_ALGORITHM},
        )
        resp.raise_for_status()

        self._log("Setting room name...")
        resp = await client.put(
            f"/_matrix/client/v3/rooms/{encoded_room_id}/state/m.room.name",
            headers=user_headers,
            json={"name": room_name},
        )
        resp.raise_for_status()

        self._log("Setting Lotti sync marker state...")
        resp = await client.put(
            f"/_matrix/client/v3/rooms/{encoded_room_id}/state/{SYNC_ROOM_STATE_TYPE}",
            headers=user_headers,
            json={"version": SYNC_ROOM_STATE_VERSION},
        )
        resp.raise_for_status()

        return room_id
