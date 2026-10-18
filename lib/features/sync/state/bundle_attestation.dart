import 'dart:convert';

import 'package:lotti/classes/config.dart';
import 'package:lotti/features/provenance/crypto/ed25519.dart';

/// Schema version of a bundle carrying a [BundleAttestation].
const int kSignedSyncBundleVersion = 3;

/// Public keys and homeservers of the paid Lotti Sync service.
///
/// A homeserver listed in [signedHomeservers] is only accepted with a valid
/// attestation from one of [keys]; every other homeserver is somebody's own
/// and keeps working with unsigned bundles, so self-hosting is unaffected.
class BundleTrust {
  const BundleTrust({required this.keys, required this.signedHomeservers});

  /// Key id → raw 32-byte Ed25519 public key, unpadded Base64url.
  final Map<String, String> keys;

  /// Homeserver base URLs that must present a signature, without a trailing
  /// slash, e.g. `https://matrix.example.com`.
  final Set<String> signedHomeservers;

  bool requiresSignature(String homeServer) =>
      signedHomeservers.contains(_normalizeHomeServer(homeServer));
}

/// The operator's trust anchors, compiled into every build.
///
/// Filled in when the production signing key is generated: the public half
/// printed by the provisioning service's key tool goes into `keys` under
/// the `BUNDLE_SIGNING_KEY_ID` the service runs with, and the homeserver URL
/// into `signedHomeservers`. Rotating a key means adding the new id here a
/// release before the service switches to it.
const BundleTrust kLottiSyncBundleTrust = BundleTrust(
  keys: {},
  signedHomeservers: {},
);

/// How a bundle passed verification.
enum BundleTrustVerdict {
  /// Signed by a known key, intact and (if provisioned) unexpired.
  verified,

  /// Unsigned, for a homeserver that does not require a signature.
  selfHosted,
}

/// Why a bundle was refused.
enum BundleTrustFailure {
  /// The homeserver requires a signature and the bundle has none.
  unsigned,

  /// Signed with a key this build does not know.
  unknownKey,

  /// The signature does not match the identity it claims to cover.
  invalidSignature,

  /// A `provisioned` bundle used after its attestation expired.
  expired,
}

class UntrustedBundleException implements Exception {
  const UntrustedBundleException(this.failure);

  final BundleTrustFailure failure;

  @override
  String toString() => 'UntrustedBundleException(${failure.name})';
}

/// The exact bytes an attestation signs: canonical JSON of the identity,
/// keys sorted, no whitespace.
///
/// Must stay byte-identical to what the provisioning service signs; a test
/// vector produced by its signer is pinned in this function's test.
List<int> attestationPayload({
  required String homeServer,
  required String user,
  required String roomId,
  required BundleAttestation attestation,
}) => utf8.encode(
  jsonEncode(<String, Object>{
    'exp': attestation.exp,
    'homeServer': homeServer,
    'iat': attestation.iat,
    'kid': attestation.kid,
    'roomId': roomId,
    'user': user,
    'v': kSignedSyncBundleVersion,
  }),
);

/// Checks a bundle's attestation against [trust] before anything signs in.
class BundleAttestationVerifier {
  const BundleAttestationVerifier({
    required this.ed25519,
    required this.trust,
  });

  /// Null when the caller knows the bundle is unsigned and did not load
  /// libsodium; a signed bundle then cannot be verified and is refused.
  final Ed25519? ed25519;
  final BundleTrust trust;

  /// Returns how [bundle] is trusted at [now], or throws
  /// [UntrustedBundleException].
  ///
  /// An attestation that is present is always checked, even for a
  /// homeserver that would accept an unsigned bundle: a bad signature means
  /// the bundle was altered, whoever runs the server.
  BundleTrustVerdict verify(
    SyncProvisioningBundle bundle, {
    required DateTime now,
  }) {
    final attestation = bundle.att;
    if (attestation == null) {
      if (trust.requiresSignature(bundle.homeServer)) {
        throw const UntrustedBundleException(BundleTrustFailure.unsigned);
      }
      return BundleTrustVerdict.selfHosted;
    }
    final key = trust.keys[attestation.kid];
    if (key == null) {
      throw const UntrustedBundleException(BundleTrustFailure.unknownKey);
    }
    final ed25519 = this.ed25519;
    if (ed25519 == null) {
      throw const UntrustedBundleException(BundleTrustFailure.invalidSignature);
    }
    final valid = ed25519.verify(
      message: attestationPayload(
        homeServer: bundle.homeServer,
        user: bundle.user,
        roomId: bundle.roomId,
        attestation: attestation,
      ),
      signature: _decodeBase64Url(attestation.sig),
      publicKey: _decodeBase64Url(key),
    );
    if (!valid) {
      throw const UntrustedBundleException(BundleTrustFailure.invalidSignature);
    }
    // A handover carries the original attestation long after issue; its live
    // password was set by a device that already verified it.
    if (bundle.kind == SyncBundleKind.provisioned &&
        now.millisecondsSinceEpoch ~/ 1000 >= attestation.exp) {
      throw const UntrustedBundleException(BundleTrustFailure.expired);
    }
    return BundleTrustVerdict.verified;
  }
}

List<int> _decodeBase64Url(String value) {
  try {
    return base64Url.decode(base64Url.normalize(value));
  } on FormatException {
    // Malformed signatures are simply invalid; Ed25519.verify rejects an
    // empty list on length.
    return const [];
  }
}

String _normalizeHomeServer(String homeServer) {
  final trimmed = homeServer.trim().toLowerCase();
  return trimmed.endsWith('/')
      ? trimmed.substring(0, trimmed.length - 1)
      : trimmed;
}
