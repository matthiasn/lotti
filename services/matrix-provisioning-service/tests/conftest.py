"""Pytest configuration and shared fixtures."""

from __future__ import annotations

import os
import sys
from pathlib import Path
from urllib.parse import unquote

import httpx
import pytest

# The auth middleware reads its keys when the app module is imported, so these
# must be set before any test imports `src.main`.
os.environ.setdefault("API_KEYS", "test-key")
os.environ.setdefault("ADMIN_API_KEYS", "test-admin-key")
os.environ.setdefault("MATRIX_HOMESERVER", "https://matrix.example.com")
os.environ.setdefault("MATRIX_ADMIN_USER", "admin")
os.environ.setdefault("MATRIX_ADMIN_PASSWORD", "secret")
os.environ.setdefault("ENABLE_REDEMPTION_POLLING", "false")

# The service imports `shared.*` the same way it does in Docker, where
# services/ is the build context root.
_SERVICES_DIR = Path(__file__).resolve().parents[2]
if str(_SERVICES_DIR) not in sys.path:
    sys.path.insert(0, str(_SERVICES_DIR))

_SERVICE_DIR = Path(__file__).resolve().parents[1]
if str(_SERVICE_DIR) not in sys.path:
    sys.path.insert(0, str(_SERVICE_DIR))

from shared.matrix import AdminCredentials  # noqa: E402
from src.services.provisioning_repository import ProvisioningRepository  # noqa: E402

pytest_plugins = ["pytest_asyncio"]

ADMIN_MXID = "@admin:example.com"
SERVER_NAME = "example.com"
HOMESERVER = "https://matrix.example.com"
ROOM_ID = "!syncroom:example.com"


@pytest.fixture
def anyio_backend():
    """Restrict anyio to asyncio; the service has no trio support."""
    return "asyncio"


def synapse_handler(request: httpx.Request) -> httpx.Response:
    """Mock the Synapse endpoints the service depends on.

    Paths are URL-decoded before matching so percent-encoded MXIDs resolve.
    """
    path = unquote(request.url.path)

    if path == "/_matrix/client/v3/login":
        return httpx.Response(
            200, json={"access_token": "admin_tok", "user_id": ADMIN_MXID}
        )

    if path == "/_matrix/client/v3/account/whoami":
        return httpx.Response(200, json={"user_id": ADMIN_MXID})

    if path.startswith("/_synapse/admin/v1/users/") and path.endswith("/login"):
        return httpx.Response(200, json={"access_token": "user_tok"})

    if path.startswith("/_synapse/admin/v1/users/") and path.endswith("/media"):
        return httpx.Response(
            200,
            json={
                "total": 2,
                "media": [{"media_length": 1000}, {"media_length": 2500}],
            },
        )

    if path.startswith("/_synapse/admin/v2/users/") and path.endswith("/devices"):
        return httpx.Response(
            200, json={"devices": [{"device_id": "AAA", "last_seen_ts": 1700000000000}]}
        )

    if path.startswith("/_synapse/admin/v2/users/"):
        return httpx.Response(200, json={"deactivated": False})

    if path == "/_matrix/client/v3/createRoom":
        return httpx.Response(200, json={"room_id": ROOM_ID})

    if path.startswith("/_matrix/client/v3/rooms/"):
        return httpx.Response(200, json={"event_id": "$evt"})

    if path.startswith("/_synapse/admin/v1/purge_history_status/"):
        return httpx.Response(200, json={"status": "complete"})

    if path.startswith("/_synapse/admin/v1/purge_history/"):
        return httpx.Response(200, json={"purge_id": "purge_abc"})

    return httpx.Response(404, json={"errcode": "M_NOT_FOUND", "path": path})


@pytest.fixture
def mock_transport() -> httpx.MockTransport:
    """A transport serving the mock Synapse."""
    return httpx.MockTransport(synapse_handler)


@pytest.fixture
def tracking_transport():
    """A transport that records every request it serves.

    Returns:
        A ``(transport, requests_seen)`` tuple.
    """
    requests_seen: list[httpx.Request] = []

    def handler(request: httpx.Request) -> httpx.Response:
        requests_seen.append(request)
        return synapse_handler(request)

    return httpx.MockTransport(handler), requests_seen


@pytest.fixture
def credentials() -> AdminCredentials:
    """Password-login admin credentials pointed at the mock homeserver."""
    return AdminCredentials(
        homeserver=HOMESERVER, admin_user="admin", admin_password="secret"
    )


@pytest.fixture
def repository(tmp_path) -> ProvisioningRepository:
    """A repository backed by a throwaway SQLite file."""
    return ProvisioningRepository(str(tmp_path / "provisioning.db"))


async def seed_user(
    repository: ProvisioningRepository, username: str = "lotti_user", **overrides
):
    """Insert a provisioned-user record with sensible defaults."""
    payload = {
        "username": username,
        "user_mxid": f"@{username}:{SERVER_NAME}",
        "home_server": HOMESERVER,
        "server_name": SERVER_NAME,
        "room_id": ROOM_ID,
        "display_name": f"Lotti Sync ({username})",
        "bundle_fingerprint": "f" * 64,
        "notes": "",
    }
    payload.update(overrides)
    return await repository.create(**payload)
