"""Hashing and request binding for subscription credentials and proofs."""

from __future__ import annotations

import base64
import hashlib
import hmac
import json
import os


def _base64url(value: bytes) -> str:
    return base64.urlsafe_b64encode(value).rstrip(b"=").decode()


def fingerprint(value: str) -> str:
    """Return a non-reversible SHA-256 correlation value for a bearer secret."""
    return hashlib.sha256(value.encode()).hexdigest()


class SecretHasher:
    """Versioned scrypt hashes with constant-time verification."""

    _N = 2**14
    _R = 8
    _P = 1
    _SALT_BYTES = 16
    _KEY_BYTES = 32

    def hash(self, secret: str) -> str:
        """Hash a high-entropy entitlement, intent, or claim secret."""
        if not secret:
            raise ValueError("Secret must not be empty")
        salt = os.urandom(self._SALT_BYTES)
        derived = hashlib.scrypt(
            secret.encode(),
            salt=salt,
            n=self._N,
            r=self._R,
            p=self._P,
            dklen=self._KEY_BYTES,
        )
        return f"scrypt${self._N}${self._R}${self._P}${_base64url(salt)}${_base64url(derived)}"

    def verify(self, secret: str, encoded_hash: str) -> bool:
        """Verify without leaking whether parsing or comparison failed."""
        try:
            algorithm, n, r, p, salt, expected = encoded_hash.split("$", 5)
            if algorithm != "scrypt":
                return False
            salt_bytes = base64.urlsafe_b64decode(salt + "==")
            expected_bytes = base64.urlsafe_b64decode(expected + "==")
            actual = hashlib.scrypt(
                secret.encode(),
                salt=salt_bytes,
                n=int(n),
                r=int(r),
                p=int(p),
                dklen=len(expected_bytes),
            )
        except (ValueError, TypeError):
            return False
        return hmac.compare_digest(actual, expected_bytes)


def derive_obfuscated_account_id(binding_key: bytes, entitlement_id: str) -> str:
    """Derive the stable Play Billing account identifier known only to the server."""
    if len(binding_key) < 32:
        raise ValueError("Play account binding key must contain at least 32 bytes")
    if not entitlement_id:
        raise ValueError("Entitlement ID must not be empty")
    return _base64url(hmac.new(binding_key, entitlement_id.encode(), hashlib.sha256).digest())


def canonical_purchase_request_hash(
    *,
    package_name: str,
    product_id: str,
    base_plan_id: str,
    entitlement_id: str,
    purchase_intent_id: str,
    purchase_token: str,
    intent_secret: str,
    claim_secret: str,
) -> str:
    """Bind a Play Integrity verdict to every security-relevant submission field."""
    canonical = json.dumps(
        {
            "base_plan_id": base_plan_id,
            "claim_secret_hash": fingerprint(claim_secret),
            "entitlement_id": entitlement_id,
            "intent_secret_hash": fingerprint(intent_secret),
            "package_name": package_name,
            "product_id": product_id,
            "purchase_intent_id": purchase_intent_id,
            "purchase_token_fingerprint": fingerprint(purchase_token),
        },
        sort_keys=True,
        separators=(",", ":"),
    ).encode()
    return _base64url(hashlib.sha256(canonical).digest())
