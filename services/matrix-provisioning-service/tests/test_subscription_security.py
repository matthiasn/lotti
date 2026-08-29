"""Tests for subscription secret storage and Play Integrity request binding."""

from __future__ import annotations

import pytest
from src.services.subscription_security import (
    SecretHasher,
    canonical_purchase_request_hash,
    derive_obfuscated_account_id,
    fingerprint,
)


def test_secret_hash_round_trip_and_random_salt():
    hasher = SecretHasher()

    first = hasher.hash("high-entropy-secret")
    second = hasher.hash("high-entropy-secret")

    assert first != second
    assert "high-entropy-secret" not in first
    assert hasher.verify("high-entropy-secret", first) is True
    assert hasher.verify("wrong-secret", first) is False


def test_malformed_or_unknown_hash_never_authenticates():
    hasher = SecretHasher()

    assert hasher.verify("secret", "not-a-hash") is False
    assert hasher.verify("secret", "argon2$1$2$3$salt$hash") is False
    assert hasher.verify("secret", "scrypt$bad$2$3$salt$hash") is False


def test_empty_secret_is_never_stored():
    with pytest.raises(ValueError, match="must not be empty"):
        SecretHasher().hash("")


def test_fingerprint_is_deterministic_and_does_not_contain_secret():
    first = fingerprint("purchase-token")

    assert first == fingerprint("purchase-token")
    assert first != fingerprint("other-token")
    assert "purchase-token" not in first
    assert len(first) == 64


def test_obfuscated_account_id_is_stable_per_entitlement_and_key():
    binding_key = bytes(range(32))

    account_id = derive_obfuscated_account_id(binding_key, "entitlement-one")

    assert account_id == derive_obfuscated_account_id(binding_key, "entitlement-one")
    assert account_id != derive_obfuscated_account_id(binding_key, "entitlement-two")
    assert account_id != derive_obfuscated_account_id(bytes(reversed(range(32))), "entitlement-one")
    assert "entitlement-one" not in account_id
    assert len(account_id) == 43


@pytest.mark.parametrize(
    ("key", "entitlement_id", "message"),
    [(b"short", "entitlement", "at least 32 bytes"), (bytes(range(32)), "", "must not")],
)
def test_obfuscated_account_id_requires_strong_explicit_inputs(
    key,
    entitlement_id,
    message,
):
    with pytest.raises(ValueError, match=message):
        derive_obfuscated_account_id(key, entitlement_id)


def _request_hash(**overrides):
    fields = {
        "package_name": "com.matthiasn.lotti",
        "product_id": "lotti_sync",
        "base_plan_id": "monthly",
        "entitlement_id": "entitlement-one",
        "purchase_intent_id": "intent-one",
        "purchase_token": "purchase-token",
        "intent_secret": "intent-secret",
        "claim_secret": "claim-secret",
    }
    fields.update(overrides)
    return canonical_purchase_request_hash(**fields)


def test_canonical_request_hash_is_deterministic_and_contains_no_secret():
    request_hash = _request_hash()

    assert request_hash == _request_hash()
    assert "purchase-token" not in request_hash
    assert "intent-secret" not in request_hash
    assert "claim-secret" not in request_hash


def test_every_submission_field_changes_the_request_hash():
    original = _request_hash()
    changes = {
        "package_name": "other.package",
        "product_id": "other-product",
        "base_plan_id": "annual",
        "entitlement_id": "entitlement-two",
        "purchase_intent_id": "intent-two",
        "purchase_token": "other-purchase-token",
        "intent_secret": "other-intent-secret",
        "claim_secret": "other-claim-secret",
    }

    assert {
        field for field, value in changes.items() if _request_hash(**{field: value}) != original
    } == set(changes)
