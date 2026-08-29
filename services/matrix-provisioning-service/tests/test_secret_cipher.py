"""Tests for authenticated encryption of paid-subscription secrets."""

from __future__ import annotations

import base64

import pytest
from cryptography.exceptions import InvalidTag
from src.services.secret_cipher import SecretCipher


KEY = bytes(range(32))


def test_round_trip_keeps_plaintext_out_of_ciphertext():
    cipher = SecretCipher(key_id="key-v1", key=KEY)
    plaintext = b"sensitive-purchase-token"

    encrypted = cipher.encrypt(plaintext, purpose="purchase-token", record_id="fingerprint")

    assert plaintext not in encrypted
    assert (
        cipher.decrypt(
            encrypted,
            purpose="purchase-token",
            record_id="fingerprint",
        )
        == plaintext
    )
    assert cipher.key_id == "key-v1"


def test_same_plaintext_uses_a_fresh_nonce_each_time():
    cipher = SecretCipher(key_id="key-v1", key=KEY)

    first = cipher.encrypt(b"same", purpose="bundle", record_id="claim-one")
    second = cipher.encrypt(b"same", purpose="bundle", record_id="claim-one")

    assert first != second


@pytest.mark.parametrize(
    ("purpose", "record_id"),
    [("other-purpose", "fingerprint"), ("purchase-token", "other-row")],
)
def test_ciphertext_is_bound_to_its_purpose_and_row(purpose, record_id):
    cipher = SecretCipher(key_id="key-v1", key=KEY)
    encrypted = cipher.encrypt(
        b"secret",
        purpose="purchase-token",
        record_id="fingerprint",
    )

    with pytest.raises(InvalidTag):
        cipher.decrypt(encrypted, purpose=purpose, record_id=record_id)


def test_tampering_is_detected():
    cipher = SecretCipher(key_id="key-v1", key=KEY)
    encrypted = bytearray(
        cipher.encrypt(b"secret", purpose="purchase-token", record_id="fingerprint")
    )
    encrypted[-1] ^= 1

    with pytest.raises(InvalidTag):
        cipher.decrypt(
            bytes(encrypted),
            purpose="purchase-token",
            record_id="fingerprint",
        )


def test_base64_factory_requires_exactly_256_bits():
    encoded = base64.b64encode(KEY).decode()

    cipher = SecretCipher.from_base64_key(key_id="key-v1", encoded_key=encoded)

    assert (
        cipher.decrypt(
            cipher.encrypt(b"secret", purpose="bundle", record_id="claim"),
            purpose="bundle",
            record_id="claim",
        )
        == b"secret"
    )
    with pytest.raises(ValueError, match="32 bytes"):
        SecretCipher.from_base64_key(
            key_id="key-v1",
            encoded_key=base64.b64encode(b"short").decode(),
        )
    with pytest.raises(ValueError, match="valid Base64"):
        SecretCipher.from_base64_key(key_id="key-v1", encoded_key="not base64!!")


@pytest.mark.parametrize(
    ("key_id", "key", "message"),
    [("", KEY, "key ID"), ("key-v1", b"short", "32 bytes")],
)
def test_constructor_rejects_invalid_key_configuration(key_id, key, message):
    with pytest.raises(ValueError, match=message):
        SecretCipher(key_id=key_id, key=key)


@pytest.mark.parametrize(
    ("purpose", "record_id"),
    [("", "row"), ("bundle", "")],
)
def test_encryption_context_must_be_explicit(purpose, record_id):
    cipher = SecretCipher(key_id="key-v1", key=KEY)

    with pytest.raises(ValueError, match="must not be empty"):
        cipher.encrypt(b"secret", purpose=purpose, record_id=record_id)


def test_truncated_ciphertext_is_rejected_before_decryption():
    cipher = SecretCipher(key_id="key-v1", key=KEY)

    with pytest.raises(ValueError, match="too short"):
        cipher.decrypt(b"short", purpose="bundle", record_id="claim")


def test_legacy_key_can_decrypt_but_new_ciphertext_uses_active_key():
    legacy = SecretCipher(key_id="key-v1", key=KEY)
    encrypted = legacy.encrypt(b"legacy-secret", purpose="bundle", record_id="claim")
    rotated = SecretCipher(
        key_id="key-v2",
        key=bytes(reversed(KEY)),
        decryption_keys={"key-v1": KEY},
    )

    assert (
        rotated.decrypt(
            encrypted,
            purpose="bundle",
            record_id="claim",
            key_id="key-v1",
        )
        == b"legacy-secret"
    )
    new_ciphertext = rotated.encrypt(b"new-secret", purpose="bundle", record_id="claim")
    with pytest.raises(InvalidTag):
        legacy.decrypt(new_ciphertext, purpose="bundle", record_id="claim")


def test_unknown_decryption_key_is_rejected():
    cipher = SecretCipher(key_id="key-v1", key=KEY)
    encrypted = cipher.encrypt(b"secret", purpose="bundle", record_id="claim")

    with pytest.raises(ValueError, match="retired-key"):
        cipher.decrypt(
            encrypted,
            purpose="bundle",
            record_id="claim",
            key_id="retired-key",
        )


@pytest.mark.parametrize(
    ("decryption_keys", "message"),
    [
        ({"key-v1": bytes(reversed(KEY))}, "conflicts"),
        ({"": KEY}, "ID must not be empty"),
        ({"legacy": b"short"}, "exactly 32 bytes"),
    ],
)
def test_constructor_rejects_invalid_decryption_keys(decryption_keys, message):
    with pytest.raises(ValueError, match=message):
        SecretCipher(key_id="key-v1", key=KEY, decryption_keys=decryption_keys)
