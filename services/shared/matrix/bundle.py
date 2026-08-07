"""Provisioning bundle encoding and decoding.

The bundle is the Base64url-encoded (no padding) JSON payload that an admin
hands to a new user and the Lotti client imports. Its schema is a contract with
the shipped Dart client (``lib/features/sync/state/provisioning_controller.dart``)
— the client rejects ``v:1`` bundles and dispatches on ``kind``, so neither
field may change shape without a coordinated client release.
"""

from __future__ import annotations

import base64
import binascii
import json
from dataclasses import dataclass
from enum import Enum

#: Schema version understood by the current Lotti client. The client rejects
#: v:1 bundles, which predate the ``kind`` discriminator.
BUNDLE_SCHEMA_VERSION = 2


class BundleKind(str, Enum):
    """Import discriminator telling the client how to treat the password.

    ``PROVISIONED`` bundles carry a throwaway password the client MUST rotate on
    first import. ``HANDOVER`` bundles are emitted peer-to-peer by an already
    configured desktop and carry the live credential, which must NOT be rotated
    or every other device would be locked out.
    """

    PROVISIONED = "provisioned"
    HANDOVER = "handover"


class BundleDecodeError(ValueError):
    """Raised when a string is not a well-formed provisioning bundle."""


@dataclass(frozen=True)
class SyncBundle:
    """A decoded provisioning bundle."""

    home_server: str
    user: str
    password: str
    room_id: str
    kind: BundleKind = BundleKind.PROVISIONED
    version: int = BUNDLE_SCHEMA_VERSION

    def to_dict(self) -> dict:
        """Return the wire-format dict, with keys in the client's field order."""
        return {
            "v": self.version,
            "kind": self.kind.value,
            "homeServer": self.home_server,
            "user": self.user,
            "password": self.password,
            "roomId": self.room_id,
        }

    def encode(self) -> str:
        """Encode to the Base64url (no padding) string the client imports."""
        payload = json.dumps(self.to_dict(), separators=(",", ":"))
        return base64.urlsafe_b64encode(payload.encode()).rstrip(b"=").decode()

    def redacted_dict(self) -> dict:
        """Return the wire-format dict with the password masked, for logging."""
        return {**self.to_dict(), "password": "<redacted>"}

    @classmethod
    def decode(cls, encoded: str) -> "SyncBundle":
        """Decode a Base64url (no padding) bundle string.

        Args:
            encoded: The bundle string as handed to a user.

        Returns:
            The parsed bundle.

        Raises:
            BundleDecodeError: If the string is not valid Base64url, not JSON,
                carries an unsupported schema version, uses an unknown ``kind``,
                or is missing a required field.
        """
        # Bundles get pasted out of chat clients and emails, which wrap lines,
        # so all whitespace is discarded before validation rather than only the
        # ends.
        stripped = "".join(encoded.split())
        if not stripped:
            raise BundleDecodeError("Bundle string is empty")

        # Base64url without padding: restore it before decoding. `validate=True`
        # with explicit altchars is required — urlsafe_b64decode silently drops
        # characters outside the alphabet, which turns obvious garbage into a
        # confusing JSON error instead of a clear rejection.
        padding = "=" * (-len(stripped) % 4)
        try:
            raw = base64.b64decode(stripped + padding, altchars=b"-_", validate=True)
        except (binascii.Error, ValueError) as exc:
            raise BundleDecodeError(f"Bundle is not valid Base64url: {exc}") from exc

        try:
            data = json.loads(raw)
        except (UnicodeDecodeError, json.JSONDecodeError) as exc:
            raise BundleDecodeError(f"Bundle does not contain valid JSON: {exc}") from exc

        if not isinstance(data, dict):
            raise BundleDecodeError("Bundle JSON must be an object")

        version = data.get("v")
        if version != BUNDLE_SCHEMA_VERSION:
            raise BundleDecodeError(
                f"Unsupported bundle schema version {version!r} "
                f"(expected {BUNDLE_SCHEMA_VERSION})"
            )

        try:
            kind = BundleKind(data.get("kind"))
        except ValueError as exc:
            raise BundleDecodeError(f"Unknown bundle kind {data.get('kind')!r}") from exc

        missing = [
            key for key in ("homeServer", "user", "password", "roomId") if not data.get(key)
        ]
        if missing:
            raise BundleDecodeError(f"Bundle is missing required field(s): {', '.join(missing)}")

        return cls(
            home_server=data["homeServer"],
            user=data["user"],
            password=data["password"],
            room_id=data["roomId"],
            kind=kind,
            version=version,
        )
