"""Tests for the Matrix provisioning tool."""

import base64
import json

import httpx
import pytest

from provision import provision
from tests.conftest import decode_bundle, make_args, synapse_handler

# ---------------------------------------------------------------------------
# Happy-path tests
# ---------------------------------------------------------------------------


@pytest.mark.anyio
async def test_provision_success(mock_transport):
    """Full provisioning flow produces a valid Base64 bundle."""
    result = await provision(make_args(), transport=mock_transport)
    bundle = decode_bundle(result)

    assert bundle["v"] == 1
    assert bundle["homeServer"] == "https://matrix.example.com"
    assert bundle["user"] == "@lotti_user:example.com"
    assert bundle["roomId"] == "!test_room:example.com"
    assert len(bundle["password"]) > 0


@pytest.mark.anyio
async def test_provision_strips_trailing_slash(mock_transport):
    """Homeserver URL trailing slash is stripped."""
    args = make_args(homeserver="https://matrix.example.com/")
    result = await provision(args, transport=mock_transport)

    bundle = decode_bundle(result)
    assert bundle["homeServer"] == "https://matrix.example.com"


@pytest.mark.anyio
async def test_provision_password_is_random(mock_transport):
    """Each invocation generates a different password."""
    r1 = await provision(make_args(), transport=mock_transport)
    r2 = await provision(make_args(), transport=mock_transport)

    assert decode_bundle(r1)["password"] != decode_bundle(r2)["password"]


# ---------------------------------------------------------------------------
# Request inspection tests
# ---------------------------------------------------------------------------


@pytest.mark.anyio
async def test_provision_custom_display_name(tracking_transport):
    """Custom display name is passed to user creation."""
    transport, requests_seen = tracking_transport
    await provision(make_args(display_name="My Custom Name"), transport=transport)

    create_user_reqs = [r for r in requests_seen if "/_synapse/admin/v2/users/" in r.url.path]
    assert len(create_user_reqs) == 1
    body = json.loads(create_user_reqs[0].content)
    assert body["displayname"] == "My Custom Name"


@pytest.mark.anyio
async def test_provision_creates_non_admin_user(tracking_transport):
    """The created user must have admin: false."""
    transport, requests_seen = tracking_transport
    await provision(make_args(), transport=transport)

    create_user_reqs = [r for r in requests_seen if "/_synapse/admin/v2/users/" in r.url.path]
    assert len(create_user_reqs) == 1
    body = json.loads(create_user_reqs[0].content)
    assert body["admin"] is False


@pytest.mark.anyio
async def test_provision_user_token_is_short_lived(tracking_transport):
    """The user login request includes a valid_until_ms in the future."""
    transport, requests_seen = tracking_transport
    await provision(make_args(), transport=transport)

    login_as_user_reqs = [
        r
        for r in requests_seen
        if r.url.path.startswith("/_synapse/admin/v1/users/") and r.url.path.endswith("/login")
    ]
    assert len(login_as_user_reqs) == 1
    body = json.loads(login_as_user_reqs[0].content)
    assert "valid_until_ms" in body
    assert body["valid_until_ms"] > 0


@pytest.mark.anyio
async def test_provision_room_has_encryption_and_marker(tracking_transport):
    """The created room includes encryption and m.lotti.sync_room state."""
    transport, requests_seen = tracking_transport
    await provision(make_args(), transport=transport)

    create_room_reqs = [r for r in requests_seen if r.url.path == "/_matrix/client/v3/createRoom"]
    assert len(create_room_reqs) == 1
    body = json.loads(create_room_reqs[0].content)

    state_types = [s["type"] for s in body["initial_state"]]
    assert "m.room.encryption" in state_types
    assert "m.lotti.sync_room" in state_types

    encryption_state = next(s for s in body["initial_state"] if s["type"] == "m.room.encryption")
    assert encryption_state["content"]["algorithm"] == "m.megolm.v1.aes-sha2"

    marker_state = next(s for s in body["initial_state"] if s["type"] == "m.lotti.sync_room")
    assert marker_state["content"]["version"] == 1


@pytest.mark.anyio
async def test_provision_room_no_federation(tracking_transport):
    """The created room disables federation."""
    transport, requests_seen = tracking_transport
    await provision(make_args(), transport=transport)

    create_room_reqs = [r for r in requests_seen if r.url.path == "/_matrix/client/v3/createRoom"]
    body = json.loads(create_room_reqs[0].content)
    assert body["creation_content"]["m.federate"] is False


@pytest.mark.anyio
async def test_provision_room_is_private(tracking_transport):
    """The created room is private with trusted_private_chat preset."""
    transport, requests_seen = tracking_transport
    await provision(make_args(), transport=transport)

    create_room_reqs = [r for r in requests_seen if r.url.path == "/_matrix/client/v3/createRoom"]
    body = json.loads(create_room_reqs[0].content)
    assert body["visibility"] == "private"
    assert body["preset"] == "trusted_private_chat"


# ---------------------------------------------------------------------------
# Error handling tests
# ---------------------------------------------------------------------------


@pytest.mark.anyio
async def test_provision_admin_login_failure():
    """Admin login failure raises HTTPStatusError."""

    def handler(request: httpx.Request) -> httpx.Response:
        if request.url.path == "/_matrix/client/v3/login":
            return httpx.Response(403, json={"errcode": "M_FORBIDDEN"})
        return synapse_handler(request)

    transport = httpx.MockTransport(handler)
    with pytest.raises(httpx.HTTPStatusError):
        await provision(make_args(), transport=transport)


@pytest.mark.anyio
async def test_provision_user_creation_failure():
    """User creation failure raises HTTPStatusError."""

    def handler(request: httpx.Request) -> httpx.Response:
        if request.url.path.startswith("/_synapse/admin/v2/users/"):
            return httpx.Response(
                409,
                json={"errcode": "M_USER_IN_USE", "error": "User already exists"},
            )
        return synapse_handler(request)

    transport = httpx.MockTransport(handler)
    with pytest.raises(httpx.HTTPStatusError):
        await provision(make_args(), transport=transport)


@pytest.mark.anyio
async def test_provision_room_creation_failure():
    """Room creation failure raises HTTPStatusError."""

    def handler(request: httpx.Request) -> httpx.Response:
        if request.url.path == "/_matrix/client/v3/createRoom":
            return httpx.Response(500, json={"errcode": "M_UNKNOWN"})
        return synapse_handler(request)

    transport = httpx.MockTransport(handler)
    with pytest.raises(httpx.HTTPStatusError):
        await provision(make_args(), transport=transport)


# ---------------------------------------------------------------------------
# Bundle encoding tests
# ---------------------------------------------------------------------------


def test_bundle_roundtrip():
    """Base64 encode/decode roundtrip produces identical data."""
    bundle = {
        "v": 1,
        "homeServer": "https://matrix.example.com",
        "user": "@test:example.com",
        "password": "test_password_abc123",
        "roomId": "!room:example.com",
    }

    bundle_json = json.dumps(bundle, separators=(",", ":"))
    encoded = base64.urlsafe_b64encode(bundle_json.encode()).rstrip(b"=").decode()
    decoded = decode_bundle(encoded)

    assert decoded == bundle


def test_bundle_user_is_full_mxid():
    """Bundle user field is a full MXID (@localpart:server)."""
    bundle = {
        "v": 1,
        "homeServer": "https://matrix.example.com",
        "user": "@lotti_user:example.com",
        "password": "pw",
        "roomId": "!room:example.com",
    }

    bundle_json = json.dumps(bundle, separators=(",", ":"))
    encoded = base64.urlsafe_b64encode(bundle_json.encode()).rstrip(b"=").decode()
    decoded = decode_bundle(encoded)

    assert decoded["user"].startswith("@")
    assert ":" in decoded["user"]


def test_bundle_room_id_format():
    """Bundle roomId field starts with '!'."""
    bundle = {
        "v": 1,
        "homeServer": "https://matrix.example.com",
        "user": "@user:example.com",
        "password": "pw",
        "roomId": "!abc123:example.com",
    }

    bundle_json = json.dumps(bundle, separators=(",", ":"))
    encoded = base64.urlsafe_b64encode(bundle_json.encode()).rstrip(b"=").decode()
    decoded = decode_bundle(encoded)

    assert decoded["roomId"].startswith("!")
