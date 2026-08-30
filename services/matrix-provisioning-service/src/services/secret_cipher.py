"""Authenticated encryption for purchase tokens and short-lived bundle escrow."""

from __future__ import annotations

import base64
import os
from collections.abc import Mapping

from cryptography.hazmat.primitives.ciphers.aead import AESGCM


class SecretCipher:
    """AES-256-GCM envelope cipher identified by an operator-managed key ID."""

    _NONCE_BYTES = 12

    def __init__(
        self,
        *,
        key_id: str,
        key: bytes,
        decryption_keys: Mapping[str, bytes] | None = None,
    ):
        if not key_id:
            raise ValueError("Encryption key ID must not be empty")
        if len(key) != 32:
            raise ValueError("Encryption key must contain exactly 32 bytes")
        self.key_id = key_id
        configured_keys = dict(decryption_keys or {})
        if key_id in configured_keys and configured_keys[key_id] != key:
            raise ValueError("Active encryption key conflicts with a decryption key")
        configured_keys[key_id] = key
        for configured_id, configured_key in configured_keys.items():
            if not configured_id:
                raise ValueError("Decryption key ID must not be empty")
            if len(configured_key) != 32:
                raise ValueError("Decryption keys must contain exactly 32 bytes")
        self._ciphers = {
            configured_id: AESGCM(configured_key)
            for configured_id, configured_key in configured_keys.items()
        }

    @classmethod
    def from_base64_key(cls, *, key_id: str, encoded_key: str) -> SecretCipher:
        """Build a cipher from a strict Base64-encoded 256-bit key."""
        try:
            key = base64.b64decode(encoded_key, validate=True)
        except (ValueError, base64.binascii.Error) as exc:
            raise ValueError("Encryption key must be valid Base64") from exc
        return cls(key_id=key_id, key=key)

    def encrypt(self, plaintext: bytes, *, purpose: str, record_id: str) -> bytes:
        """Encrypt with context binding so ciphertext cannot move between rows."""
        nonce = os.urandom(self._NONCE_BYTES)
        return nonce + self._ciphers[self.key_id].encrypt(
            nonce,
            plaintext,
            self._associated_data(purpose, record_id),
        )

    def decrypt(
        self,
        ciphertext: bytes,
        *,
        purpose: str,
        record_id: str,
        key_id: str | None = None,
    ) -> bytes:
        """Decrypt and authenticate ciphertext for its original context."""
        if len(ciphertext) <= self._NONCE_BYTES:
            raise ValueError("Ciphertext is too short")
        selected_key_id = key_id or self.key_id
        cipher = self._ciphers.get(selected_key_id)
        if cipher is None:
            raise ValueError(f"Encryption key {selected_key_id!r} is not loaded")
        nonce = ciphertext[: self._NONCE_BYTES]
        encrypted = ciphertext[self._NONCE_BYTES :]
        return cipher.decrypt(
            nonce,
            encrypted,
            self._associated_data(purpose, record_id),
        )

    @staticmethod
    def _associated_data(purpose: str, record_id: str) -> bytes:
        if not purpose or not record_id:
            raise ValueError("Encryption purpose and record ID must not be empty")
        return f"lotti-sync-v1\0{purpose}\0{record_id}".encode()
