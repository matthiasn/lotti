import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/config.dart';
import 'package:lotti/features/provenance/crypto/ed25519.dart';
import 'package:lotti/features/sync/state/bundle_attestation.dart';

/// Shared with services/matrix-provisioning-service/tests/test_bundle_signer.py:
/// the Python signer produced this signature from seed bytes 0..31. If either
/// side's canonical bytes drift, both suites fail on the same vector.
const _vectorKid = 'test-2026-10';
const _vectorPublicKey = 'A6EHv_POEL4dcN0Y50vAmWfk1jCbpQ1fHdyGZBJVMbg';
const _vectorPayload =
    '{"exp":1792324800,"homeServer":"https://matrix.example.com",'
    '"iat":1792238400,"kid":"test-2026-10","roomId":"!vector:example.com",'
    '"user":"@sync_vector:example.com","v":3}';
const _vectorAttestation = BundleAttestation(
  kid: _vectorKid,
  iat: 1792238400,
  exp: 1792324800,
  sig:
      'Z2wBDGKnlkDUy8V2UiZwcLnyPZ8XQ_S23F4Q10C98F3D3n8k_QnaJztuNo0qxtWSUsAc6SrgQT7azvEAnfjiCA',
);

const _signedBundle = SyncProvisioningBundle(
  v: 3,
  kind: SyncBundleKind.provisioned,
  homeServer: 'https://matrix.example.com',
  user: '@sync_vector:example.com',
  password: 'bootstrap-password',
  roomId: '!vector:example.com',
  att: _vectorAttestation,
);

const _trust = BundleTrust(
  keys: {_vectorKid: _vectorPublicKey},
  signedHomeservers: {'https://matrix.example.com'},
);

/// Issued 2026-10-17 12:00 UTC, valid for 24 hours.
final _issuedAt = DateTime.utc(2026, 10, 17, 12);

void main() {
  late BundleAttestationVerifier verifier;

  setUpAll(() async {
    verifier = BundleAttestationVerifier(
      ed25519: await SodiumEd25519.bundled(),
      trust: _trust,
    );
  });

  Matcher refusedWith(BundleTrustFailure failure) => throwsA(
    isA<UntrustedBundleException>().having(
      (e) => e.failure,
      'failure',
      failure,
    ),
  );

  test('payload bytes match the Python signer exactly', () {
    final payload = attestationPayload(
      homeServer: _signedBundle.homeServer,
      user: _signedBundle.user,
      roomId: _signedBundle.roomId,
      attestation: _vectorAttestation,
    );

    expect(utf8.decode(payload), _vectorPayload);
  });

  test('the Python-signed vector verifies', () {
    expect(
      verifier.verify(_signedBundle, now: _issuedAt),
      BundleTrustVerdict.verified,
    );
  });

  test('a rotated password and handover kind keep the signature valid', () {
    final handover = _signedBundle.copyWith(
      kind: SyncBundleKind.handover,
      password: 'rotated-live-password',
    );

    // Months after the provisioned bundle expired.
    expect(
      verifier.verify(handover, now: _issuedAt.add(const Duration(days: 90))),
      BundleTrustVerdict.verified,
    );
  });

  group('any change to the signed identity is refused', () {
    final tampered = <String, SyncProvisioningBundle>{
      'user': _signedBundle.copyWith(user: '@attacker:example.com'),
      'room': _signedBundle.copyWith(roomId: '!attacker:example.com'),
      'expiry': _signedBundle.copyWith(
        att: _vectorAttestation.copyWith(exp: 2000000000),
      ),
      'signature': _signedBundle.copyWith(
        att: _vectorAttestation.copyWith(sig: 'not+base64url!!'),
      ),
    };
    for (final MapEntry(key: field, value: bundle) in tampered.entries) {
      test(field, () {
        expect(
          () => verifier.verify(bundle, now: _issuedAt),
          refusedWith(BundleTrustFailure.invalidSignature),
        );
      });
    }
  });

  test('a phishing bundle pointing elsewhere does not verify either', () {
    // Moving the identity to another server breaks the signature even
    // though that server would accept unsigned bundles.
    final redirected = _signedBundle.copyWith(
      homeServer: 'https://evil.example.org',
    );

    expect(
      () => verifier.verify(redirected, now: _issuedAt),
      refusedWith(BundleTrustFailure.invalidSignature),
    );
  });

  test('a provisioned bundle is refused from the second it expires', () {
    final expiry = DateTime.fromMillisecondsSinceEpoch(
      _vectorAttestation.exp * 1000,
      isUtc: true,
    );

    expect(
      verifier.verify(
        _signedBundle,
        now: expiry.subtract(const Duration(seconds: 1)),
      ),
      BundleTrustVerdict.verified,
    );
    expect(
      () => verifier.verify(_signedBundle, now: expiry),
      refusedWith(BundleTrustFailure.expired),
    );
  });

  test('an unknown key id is refused', () {
    final foreign = _signedBundle.copyWith(
      att: _vectorAttestation.copyWith(kid: 'someone-else'),
    );

    expect(
      () => verifier.verify(foreign, now: _issuedAt),
      refusedWith(BundleTrustFailure.unknownKey),
    );
  });

  group('unsigned bundles', () {
    SyncProvisioningBundle unsigned(String homeServer) =>
        SyncProvisioningBundle(
          v: 2,
          kind: SyncBundleKind.provisioned,
          homeServer: homeServer,
          user: '@me:self.example',
          password: 'pw',
          roomId: '!room:self.example',
        );

    for (final homeServer in [
      'https://matrix.example.com',
      'https://MATRIX.example.com/',
      ' https://matrix.example.com ',
    ]) {
      test('are refused for the operator homeserver "$homeServer"', () {
        expect(
          () => verifier.verify(unsigned(homeServer), now: _issuedAt),
          refusedWith(BundleTrustFailure.unsigned),
        );
      });
    }

    test('keep working for a self-hosted homeserver', () {
      expect(
        verifier.verify(unsigned('https://self.example'), now: _issuedAt),
        BundleTrustVerdict.selfHosted,
      );
    });
  });

  test('the shipped trust anchors leave self-hosting unaffected', () {
    expect(
      kLottiSyncBundleTrust.requiresSignature('https://self.example'),
      isFalse,
    );
  });
}
