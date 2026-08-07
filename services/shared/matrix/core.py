"""Primitives shared by every Synapse client in this package.

The provisioner and the admin client both need the same three things: admin
credentials, URL-safe path encoding, and an httpx client pointed at the
homeserver. They live here so neither module has to import the other.
"""

from __future__ import annotations

import logging
from dataclasses import dataclass
from typing import Callable
from urllib.parse import quote

import httpx

logger = logging.getLogger(__name__)


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


class UserAlreadyExistsError(ProvisioningError):
    """Raised when the requested localpart already has an account on Synapse.

    Distinct from the other provisioning failures because it is the one case a
    caller must *not* push through: ``PUT /_synapse/admin/v2/users/{mxid}`` is an
    upsert, so continuing would reset a live account's password rather than
    create a new one.
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


class SynapseClientBase:
    """Shared construction and httpx wiring for Synapse API clients."""

    def __init__(
        self,
        credentials: AdminCredentials,
        *,
        transport: httpx.AsyncBaseTransport | None = None,
        timeout: float = 30.0,
        log: Callable[[str], None] | None = None,
    ) -> None:
        """Initialise the client.

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
        self._log = log or logger.debug

    def _new_client(self) -> httpx.AsyncClient:
        """Build a fresh client. Callers own closing it."""
        kwargs: dict = {
            "base_url": self._credentials.base_url,
            "timeout": self._timeout,
        }
        if self._transport is not None:
            kwargs["transport"] = self._transport
        return httpx.AsyncClient(**kwargs)
