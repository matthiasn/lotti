"""Tests for bundle attestations, including the vector the Dart client pins."""

# ruff: noqa: S106 - explicit non-production credential fixtures

from __future__ import annotations

import base64
from dataclasses import replace
from datetime import datetime, timedelta, timezone

import pytest
from src.services.bundle_signer import (
    BundleSigner,
    BundleVerificationError,
    generate_signing_key,
    verify_bundle,
)

from shared.matrix import BundleAttestation, BundleKind, SyncBundle, attestation_payload

NOW = datetime(2026, 10, 17, 12, tzinfo=timezone.utc)
SEED = bytes(range(32))
KID = "test-2026-10"

# Shared with test/features/sync/state/bundle_attestation_test.dart. If either
# side's canonical encoding drifts, both suites fail on the same bytes.
VECTOR_PUBLIC_KEY = "A6EHv_POEL4dcN0Y50vAmWfk1jCbpQ1fHdyGZBJVMbg"
VECTOR_SIGNATURE = (
    "Z2wBDGKnlkDUy8V2UiZwcLnyPZ8XQ_S23F4Q10C98F3D3n8k_QnaJztuNo0qxtWSUsAc6SrgQT7azvEAnfjiCA"
)
VECTOR_PAYLOAD = (
    b'{"exp":1792324800,"homeServer":"https://matrix.example.com","iat":1792238400,'
    b'"kid":"test-2026-10","roomId":"!vector:example.com","user":"@sync_vector:example.com",'
    b'"v":3}'
)


def bundle(**overrides) -> SyncBundle:
    values = {
        "home_server": "https://matrix.example.com",
        "user": "@sync_vector:example.com",
        "password": "bootstrap-password",
        "room_id": "!vector:example.com",
        "kind": BundleKind.PROVISIONED,
    }
    values.update(overrides)
    return SyncBundle(**values)


@pytest.fixture
def signer():
    return BundleSigner(seed=SEED, kid=KID)


def keys():
    return {KID: base64.urlsafe_b64decode(VECTOR_PUBLIC_KEY + "=")}


def test_signing_matches_the_cross_language_vector(signer):
    signed = signer.sign(bundle(), now=NOW)

    assert signer.public_key_base64url() == VECTOR_PUBLIC_KEY
    assert signed.version == 3
    assert signed.attestation == BundleAttestation(
        kid=KID,
        iat=int(NOW.timestamp()),
        exp=int((NOW + timedelta(hours=24)).timestamp()),
        sig=VECTOR_SIGNATURE,
    )
    assert (
        attestation_payload(
            home_server=signed.home_server,
            user=signed.user,
            room_id=signed.room_id,
            kid=KID,
            iat=signed.attestation.iat,
            exp=signed.attestation.exp,
        )
        == VECTOR_PAYLOAD
    )


def test_signed_bundle_round_trips_through_the_wire_format(signer):
    signed = signer.sign(bundle(), now=NOW)

    decoded = SyncBundle.decode(signed.encode())

    assert decoded == signed
    verify_bundle(decoded, keys(), now=NOW)


def test_a_rotated_password_keeps_the_attestation_valid(signer):
    signed = signer.sign(bundle(), now=NOW)
    handover = replace(signed, password="rotated-live-password", kind=BundleKind.HANDOVER)

    # Long after the provisioned bundle expired, the handover still verifies.
    verify_bundle(handover, keys(), now=NOW + timedelta(days=90))


@pytest.mark.parametrize(
    "tamper",
    [
        {"user": "@attacker:example.com"},
        {"room_id": "!attacker:example.com"},
        {"home_server": "https://evil.example.org"},
    ],
)
def test_any_identity_change_breaks_the_signature(signer, tamper):
    signed = signer.sign(bundle(), now=NOW)

    with pytest.raises(BundleVerificationError, match="does not verify"):
        verify_bundle(replace(signed, **tamper), keys(), now=NOW)


def test_extending_the_expiry_breaks_the_signature(signer):
    signed = signer.sign(bundle(), now=NOW)
    stretched = replace(signed, attestation=replace(signed.attestation, exp=2_000_000_000))

    with pytest.raises(BundleVerificationError, match="does not verify"):
        verify_bundle(stretched, keys(), now=NOW)


def test_an_expired_provisioned_bundle_is_refused(signer):
    signed = signer.sign(bundle(), now=NOW)

    with pytest.raises(BundleVerificationError, match="expired"):
        verify_bundle(signed, keys(), now=NOW + timedelta(hours=24))


def test_unsigned_and_unknown_key_bundles_are_refused(signer):
    with pytest.raises(BundleVerificationError, match="not signed"):
        verify_bundle(bundle(), keys(), now=NOW)
    with pytest.raises(BundleVerificationError, match="Unknown signing key"):
        verify_bundle(signer.sign(bundle(), now=NOW), {}, now=NOW)


def test_a_garbled_signature_is_refused(signer):
    signed = signer.sign(bundle(), now=NOW)
    garbled = replace(signed, attestation=replace(signed.attestation, sig="!!not-base64!!"))

    with pytest.raises(BundleVerificationError, match="does not verify"):
        verify_bundle(garbled, keys(), now=NOW)


@pytest.mark.parametrize(
    ("values", "message"),
    [
        ({"seed": b"short", "kid": KID}, "32-byte"),
        ({"seed": SEED, "kid": ""}, "BUNDLE_SIGNING_KEY_ID"),
        ({"seed": SEED, "kid": KID, "ttl": timedelta(0)}, "TTL"),
    ],
)
def test_signer_rejects_bad_configuration(values, message):
    with pytest.raises(ValueError, match=message):
        BundleSigner(**values)


def test_generated_keys_sign_and_verify():
    seed, public = generate_signing_key()
    signer = BundleSigner(seed=base64.b64decode(seed), kid="fresh")

    assert signer.public_key_base64url() == public
    verify_bundle(
        signer.sign(bundle(), now=NOW),
        {"fresh": base64.urlsafe_b64decode(public + "=")},
        now=NOW,
    )
