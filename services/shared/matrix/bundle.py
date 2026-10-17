"""Provisioning bundle encoding and decoding.

The bundle is the Base64url-encoded (no padding) JSON payload that an admin
hands to a new user and the Lotti client imports. Its schema is a contract with
the shipped Dart client (``lib/features/sync/state/provisioning_controller.dart``)
— the client rejects ``v:1`` bundles and dispatches on ``kind``, so neither
field may change shape without a coordinated client release.

Schema v3 adds ``att``, an Ed25519 attestation by the operator's provisioning
service. It signs the account identity — never the password — so a device that
rotated the password can hand the same attestation on in a ``handover`` bundle.
This module only carries the attestation; signing lives in the service, which
holds the key, so the CLI keeps working without the crypto dependency.
"""

from __future__ import annotations

import base64
import binascii
import json
from dataclasses import dataclass
from enum import Enum

#: Unsigned schema, understood by every released client. The client rejects
#: v:1 bundles, which predate the ``kind`` discriminator.
BUNDLE_SCHEMA_VERSION = 2

#: Schema carrying an operator attestation (``att``).
SIGNED_BUNDLE_SCHEMA_VERSION = 3


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
class BundleAttestation:
    """The operator's signature over a bundle's identity fields.

    ``iat``/``exp`` are Unix seconds; ``sig`` is the Base64url (no padding)
    Ed25519 signature over :func:`attestation_payload`.
    """

    kid: str
    iat: int
    exp: int
    sig: str

    def to_dict(self) -> dict:
        """Return the wire-format ``att`` object."""
        return {"kid": self.kid, "iat": self.iat, "exp": self.exp, "sig": self.sig}


def attestation_payload(
    *,
    home_server: str,
    user: str,
    room_id: str,
    kid: str,
    iat: int,
    exp: int,
) -> bytes:
    """The exact bytes an attestation signs.

    Canonical JSON: keys sorted, no whitespace, UTF-8 without escaping — the
    same bytes Dart's ``jsonEncode`` produces for the same sorted map, which is
    what the client verifies against. The password and ``kind`` are excluded
    on purpose: both change on handover while the identity does not.
    """
    return json.dumps(
        {
            "exp": exp,
            "homeServer": home_server,
            "iat": iat,
            "kid": kid,
            "roomId": room_id,
            "user": user,
            "v": SIGNED_BUNDLE_SCHEMA_VERSION,
        },
        sort_keys=True,
        separators=(",", ":"),
        ensure_ascii=False,
    ).encode()


@dataclass(frozen=True)
class SyncBundle:
    """A decoded provisioning bundle."""

    home_server: str
    user: str
    password: str
    room_id: str
    kind: BundleKind = BundleKind.PROVISIONED
    attestation: BundleAttestation | None = None

    @property
    def version(self) -> int:
        """v3 exactly when the bundle carries an attestation."""
        return SIGNED_BUNDLE_SCHEMA_VERSION if self.attestation else BUNDLE_SCHEMA_VERSION

    def to_dict(self) -> dict:
        """Return the wire-format dict, with keys in the client's field order."""
        wire = {
            "v": self.version,
            "kind": self.kind.value,
            "homeServer": self.home_server,
            "user": self.user,
            "password": self.password,
            "roomId": self.room_id,
        }
        if self.attestation is not None:
            wire["att"] = self.attestation.to_dict()
        return wire

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
        if version not in (BUNDLE_SCHEMA_VERSION, SIGNED_BUNDLE_SCHEMA_VERSION):
            raise BundleDecodeError(
                f"Unsupported bundle schema version {version!r} "
                f"(expected {BUNDLE_SCHEMA_VERSION} or {SIGNED_BUNDLE_SCHEMA_VERSION})"
            )

        try:
            kind = BundleKind(data.get("kind"))
        except ValueError as exc:
            raise BundleDecodeError(f"Unknown bundle kind {data.get('kind')!r}") from exc

        missing = [key for key in ("homeServer", "user", "password", "roomId") if not data.get(key)]
        if missing:
            raise BundleDecodeError(f"Bundle is missing required field(s): {', '.join(missing)}")

        attestation = None
        if version == SIGNED_BUNDLE_SCHEMA_VERSION:
            attestation = _decode_attestation(data.get("att"))

        return cls(
            home_server=data["homeServer"],
            user=data["user"],
            password=data["password"],
            room_id=data["roomId"],
            kind=kind,
            attestation=attestation,
        )


def _decode_attestation(att: object) -> BundleAttestation:
    if not isinstance(att, dict):
        raise BundleDecodeError("A v3 bundle must carry an attestation object")
    kid, iat, exp, sig = att.get("kid"), att.get("iat"), att.get("exp"), att.get("sig")
    if not (isinstance(kid, str) and kid and isinstance(sig, str) and sig):
        raise BundleDecodeError("Bundle attestation is missing its key id or signature")
    # bool is an int subclass; a JSON true is not a timestamp.
    if not all(isinstance(t, int) and not isinstance(t, bool) for t in (iat, exp)):
        raise BundleDecodeError("Bundle attestation timestamps must be integers")
    return BundleAttestation(kid=kid, iat=iat, exp=exp, sig=sig)
