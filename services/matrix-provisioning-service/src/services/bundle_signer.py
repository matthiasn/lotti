"""Ed25519 attestations that make a provisioning bundle verifiably the operator's.

The app compiles in the matching public keys and refuses an unsigned or forged
bundle for the operator's homeserver. That protects users from a phishing
bundle pointing at someone else's server; payment itself is enforced by the
homeserver, which only the provisioning service can create accounts on.
"""

from __future__ import annotations

import base64
import binascii
from dataclasses import replace
from datetime import datetime, timedelta

from cryptography.exceptions import InvalidSignature
from cryptography.hazmat.primitives.asymmetric.ed25519 import (
    Ed25519PrivateKey,
    Ed25519PublicKey,
)
from cryptography.hazmat.primitives.serialization import Encoding, PublicFormat

from shared.matrix import BundleAttestation, BundleKind, SyncBundle, attestation_payload

#: How long a freshly issued ``provisioned`` bundle may wait before import. The
#: client rotates the password on first import, so this only bounds a bundle
#: that leaked before its owner used it.
DEFAULT_ATTESTATION_TTL = timedelta(hours=24)


class BundleVerificationError(ValueError):
    """Raised when a bundle's attestation is absent, unknown, forged or expired."""


def _b64url(raw: bytes) -> str:
    return base64.urlsafe_b64encode(raw).rstrip(b"=").decode()


def _b64url_decode(value: str) -> bytes:
    return base64.urlsafe_b64decode(value + "=" * (-len(value) % 4))


class BundleSigner:
    """Signs bundles with one Ed25519 key identified by ``kid``."""

    def __init__(
        self,
        *,
        seed: bytes,
        kid: str,
        ttl: timedelta = DEFAULT_ATTESTATION_TTL,
    ):
        if len(seed) != 32:
            raise ValueError("BUNDLE_SIGNING_KEY_BASE64 must decode to a 32-byte Ed25519 seed")
        if not kid:
            raise ValueError("BUNDLE_SIGNING_KEY_ID is required")
        if ttl <= timedelta(0):
            raise ValueError("Bundle attestation TTL must be positive")
        self._key = Ed25519PrivateKey.from_private_bytes(seed)
        self._kid = kid
        self._ttl = ttl

    @property
    def kid(self) -> str:
        """The key id clients look the public key up by."""
        return self._kid

    def public_key_base64url(self) -> str:
        """The raw public key, in the form compiled into the app."""
        raw = self._key.public_key().public_bytes(Encoding.Raw, PublicFormat.Raw)
        return _b64url(raw)

    def sign(self, bundle: SyncBundle, *, now: datetime) -> SyncBundle:
        """Return ``bundle`` as v3, attested from ``now`` for the configured TTL."""
        iat = int(now.timestamp())
        exp = int((now + self._ttl).timestamp())
        payload = attestation_payload(
            home_server=bundle.home_server,
            user=bundle.user,
            room_id=bundle.room_id,
            kid=self._kid,
            iat=iat,
            exp=exp,
        )
        signature = _b64url(self._key.sign(payload))
        return replace(
            bundle,
            attestation=BundleAttestation(kid=self._kid, iat=iat, exp=exp, sig=signature),
        )


def verify_bundle(
    bundle: SyncBundle,
    public_keys: dict[str, bytes],
    *,
    now: datetime,
) -> None:
    """Check an attestation the way the app does.

    ``exp`` binds only ``provisioned`` bundles: a ``handover`` bundle carries
    the original attestation long after issue, and its live password was set
    by a device that already verified it.
    """
    attestation = bundle.attestation
    if attestation is None:
        raise BundleVerificationError("Bundle is not signed")
    raw_key = public_keys.get(attestation.kid)
    if raw_key is None:
        raise BundleVerificationError(f"Unknown signing key {attestation.kid!r}")
    payload = attestation_payload(
        home_server=bundle.home_server,
        user=bundle.user,
        room_id=bundle.room_id,
        kid=attestation.kid,
        iat=attestation.iat,
        exp=attestation.exp,
    )
    try:
        Ed25519PublicKey.from_public_bytes(raw_key).verify(_b64url_decode(attestation.sig), payload)
    except (InvalidSignature, ValueError, binascii.Error) as exc:
        raise BundleVerificationError("Bundle signature does not verify") from exc
    if bundle.kind is BundleKind.PROVISIONED and now.timestamp() >= attestation.exp:
        raise BundleVerificationError("Provisioned bundle has expired")


def generate_signing_key() -> tuple[str, str]:
    """A fresh key: (Base64 seed for the server, Base64url public key for the app)."""
    key = Ed25519PrivateKey.generate()
    seed = key.private_bytes_raw()
    public = key.public_key().public_bytes(Encoding.Raw, PublicFormat.Raw)
    return base64.b64encode(seed).decode(), _b64url(public)


if __name__ == "__main__":  # pragma: no cover - operator helper
    server_seed, app_public_key = generate_signing_key()
    print(f"BUNDLE_SIGNING_KEY_BASE64={server_seed}")
    print(f"App public key (base64url): {app_public_key}")
