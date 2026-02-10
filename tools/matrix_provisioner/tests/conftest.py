"""Pytest configuration and shared fixtures."""

import argparse
import base64
import json
import sys
from pathlib import Path
from urllib.parse import unquote

import httpx
import pytest

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent))

# Configure pytest-asyncio
pytest_plugins = ["pytest_asyncio"]


def synapse_handler(request: httpx.Request) -> httpx.Response:
    """Mock Synapse responses for the full provisioning flow.

    Path segments are URL-decoded before matching so that percent-encoded
    MXIDs (e.g. ``%40user%3Aserver``) are handled correctly.
    """
    path = unquote(request.url.path)

    if path == "/_matrix/client/v3/login":
        return httpx.Response(
            200,
            json={
                "access_token": "admin_tok_123",
                "user_id": "@admin:example.com",
            },
        )

    if path.startswith("/_synapse/admin/v2/users/"):
        return httpx.Response(200, json={})

    if path.startswith("/_synapse/admin/v1/users/") and path.endswith("/login"):
        return httpx.Response(
            200,
            json={"access_token": "user_tok_456"},
        )

    if path == "/_matrix/client/v3/createRoom":
        return httpx.Response(
            200,
            json={"room_id": "!test_room:example.com"},
        )

    return httpx.Response(404)


@pytest.fixture
def mock_transport():
    """Provide an httpx MockTransport backed by the Synapse handler."""
    return httpx.MockTransport(synapse_handler)


@pytest.fixture
def tracking_transport():
    """Provide a MockTransport that records all requests for inspection.

    Returns a (transport, requests_seen) tuple.
    """
    requests_seen: list[httpx.Request] = []

    def handler(request: httpx.Request) -> httpx.Response:
        requests_seen.append(request)
        return synapse_handler(request)

    return httpx.MockTransport(handler), requests_seen


def make_args(**overrides) -> argparse.Namespace:
    """Build a default CLI args namespace with optional overrides."""
    defaults = {
        "homeserver": "https://matrix.example.com",
        "admin_user": "admin",
        "admin_password": "admin_secret",
        "username": "lotti_user",
        "display_name": "Lotti Sync",
        "output_file": None,
        "verbose": False,
    }
    defaults.update(overrides)
    return argparse.Namespace(**defaults)


def decode_bundle(b64: str) -> dict:
    """Decode a Base64url provisioning bundle (with or without padding)."""
    padded = b64 + "=" * (-len(b64) % 4)
    return json.loads(base64.urlsafe_b64decode(padded))
