"""Primitives shared by every Synapse client in this package.

The provisioner and the admin client both need the same three things: admin
credentials, URL-safe path encoding, and an httpx client pointed at the
homeserver. They live here so neither module has to import the other.
"""

from __future__ import annotations

import logging
from dataclasses import dataclass
from typing import Callable
from urllib.parse import quote, urlsplit

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

    ``homeserver`` is the public HTTPS URL clients use, and the one written into
    bundles. ``api_url`` optionally names a different address for the admin
    calls themselves — in production, Synapse's internal container address, so
    the admin API never has to be exposed through the public reverse proxy.
    """

    homeserver: str
    admin_token: str | None = None
    admin_user: str | None = None
    admin_password: str | None = None
    api_url: str | None = None

    def __post_init__(self) -> None:
        parsed = urlsplit(self.homeserver)
        if parsed.scheme.lower() != "https" or not parsed.netloc:
            raise ValueError("homeserver must be a non-empty HTTPS URL")
        if self.api_url is not None:
            api = urlsplit(self.api_url)
            if api.scheme.lower() not in ("http", "https") or not api.netloc:
                raise ValueError("api_url must be an HTTP(S) URL")
        if not self.admin_token and not (self.admin_user and self.admin_password):
            raise ValueError("Provide either admin_token, or both admin_user and admin_password")

    @property
    def base_url(self) -> str:
        """The public homeserver URL without a trailing slash."""
        return self.homeserver.rstrip("/")

    @property
    def request_url(self) -> str:
        """Where admin requests are sent: ``api_url`` if set, else the public URL."""
        return (self.api_url or self.homeserver).rstrip("/")


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
            "base_url": self._credentials.request_url,
            "timeout": self._timeout,
            "follow_redirects": False,
        }
        if self._transport is not None:
            kwargs["transport"] = self._transport
        return httpx.AsyncClient(**kwargs)
