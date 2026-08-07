"""Tests for the provisioning bundle codec.

The bundle schema is a contract with the shipped Dart client, so these tests
pin the exact wire format rather than merely round-tripping.
"""

from __future__ import annotations

import base64
import json

import pytest

from shared.matrix.bundle import (
    BUNDLE_SCHEMA_VERSION,
    BundleDecodeError,
    BundleKind,
    SyncBundle,
)


def _bundle(**overrides) -> SyncBundle:
    defaults = {
        "home_server": "https://matrix.example.com",
        "user": "@lotti_user:example.com",
        "password": "s3cret-password",
        "room_id": "!room:example.com",
    }
    defaults.update(overrides)
    return SyncBundle(**defaults)


def _decode_raw(encoded: str) -> dict:
    padded = encoded + "=" * (-len(encoded) % 4)
    return json.loads(base64.urlsafe_b64decode(padded))


def test_encoded_payload_matches_client_contract():
    """The decoded bundle carries exactly the fields the Dart client reads."""
    payload = _decode_raw(_bundle().encode())

    assert payload == {
        "v": 2,
        "kind": "provisioned",
        "homeServer": "https://matrix.example.com",
        "user": "@lotti_user:example.com",
        "password": "s3cret-password",
        "roomId": "!room:example.com",
    }


def test_encoding_is_base64url_without_padding():
    """Padding would break the client's decoder, and '+'/'/' are not base64url."""
    encoded = _bundle(room_id="!aaaa????:example.com").encode()

    assert not encoded.endswith("=")
    assert "+" not in encoded
    assert "/" not in encoded


def test_round_trip_preserves_every_field():
    original = _bundle(kind=BundleKind.HANDOVER)

    restored = SyncBundle.decode(original.encode())

    assert restored == original


def test_decode_accepts_surrounding_whitespace():
    """Admins paste bundles out of chat clients, which add whitespace."""
    encoded = _bundle().encode()

    assert SyncBundle.decode(f"  {encoded}\n ") == _bundle()


def test_redacted_dict_masks_only_the_password():
    redacted = _bundle().redacted_dict()

    assert redacted["password"] == "<redacted>"
    assert redacted["user"] == "@lotti_user:example.com"
    assert redacted["roomId"] == "!room:example.com"


def test_default_kind_is_provisioned():
    """A CLI/web bundle must tell the client to rotate the password."""
    assert _bundle().kind is BundleKind.PROVISIONED
    assert _bundle().version == BUNDLE_SCHEMA_VERSION


@pytest.mark.parametrize(
    ("payload", "expected_message"),
    [
        ({"v": 1, "kind": "provisioned"}, "Unsupported bundle schema version"),
        ({"v": 2}, "Unknown bundle kind"),
        ({"v": 2, "kind": "nonsense"}, "Unknown bundle kind"),
    ],
)
def test_decode_rejects_incompatible_schemas(payload, expected_message):
    """v1 bundles predate the discriminator and must not be silently accepted."""
    encoded = base64.urlsafe_b64encode(json.dumps(payload).encode()).rstrip(b"=").decode()

    with pytest.raises(BundleDecodeError, match=expected_message):
        SyncBundle.decode(encoded)


def test_decode_reports_every_missing_field_at_once():
    payload = {"v": 2, "kind": "provisioned", "user": "@a:b"}
    encoded = base64.urlsafe_b64encode(json.dumps(payload).encode()).rstrip(b"=").decode()

    with pytest.raises(BundleDecodeError) as exc:
        SyncBundle.decode(encoded)

    message = str(exc.value)
    assert "homeServer" in message
    assert "password" in message
    assert "roomId" in message


def test_decode_rejects_empty_string():
    with pytest.raises(BundleDecodeError, match="empty"):
        SyncBundle.decode("   ")


def test_decode_rejects_non_base64():
    with pytest.raises(BundleDecodeError, match="Base64url"):
        SyncBundle.decode("not!valid!base64!!")


def test_decode_rejects_json_that_is_not_an_object():
    encoded = base64.urlsafe_b64encode(b"[1, 2, 3]").rstrip(b"=").decode()

    with pytest.raises(BundleDecodeError, match="must be an object"):
        SyncBundle.decode(encoded)


def test_decode_rejects_valid_base64_that_is_not_json():
    encoded = base64.urlsafe_b64encode(b"\xff\xfe not json").rstrip(b"=").decode()

    with pytest.raises(BundleDecodeError):
        SyncBundle.decode(encoded)
