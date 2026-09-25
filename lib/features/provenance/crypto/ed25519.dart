import 'dart:typed_data';

import 'package:sodium/sodium.dart';

/// Length of an Ed25519 public key, a seed and a signature, in bytes.
const int ed25519PublicKeyLength = 32;
const int ed25519SeedLength = 32;
const int ed25519SignatureLength = 64;

/// Holds one Ed25519 secret key and signs with it.
///
/// The secret key never leaves the signer as bytes. Call [dispose] once the
/// signer is no longer needed, so the key material is wiped.
abstract interface class Ed25519Signer {
  /// The public key matching the secret key, 32 bytes.
  Uint8List get publicKey;

  /// A detached 64-byte signature over [message].
  Uint8List sign(List<int> message);

  /// Wipes the secret key. The signer must not be used afterwards.
  void dispose();
}

/// Ed25519 (RFC 8032): key creation, signing and verification.
///
/// One interface, so every provenance caller depends on this rather than on a
/// particular library.
abstract interface class Ed25519 {
  /// A signer for a new random key.
  Ed25519Signer generate();

  /// A signer for the key derived from a 32-byte [seed].
  Ed25519Signer fromSeed(Uint8List seed);

  /// Whether [signature] is a valid signature of [message] by [publicKey].
  /// Malformed inputs (wrong lengths) are simply invalid.
  bool verify({
    required List<int> message,
    required List<int> signature,
    required List<int> publicKey,
  });
}

/// [Ed25519] backed by libsodium, which the `sodium` package builds from
/// source and bundles for every platform.
class SodiumEd25519 implements Ed25519 {
  SodiumEd25519(this._sodium);

  /// Uses the libsodium bundled with the app. Asynchronous only because
  /// libsodium loads asynchronously on the web; natively it is immediate.
  static Future<SodiumEd25519> bundled() async =>
      SodiumEd25519(await SodiumInit.init());

  final Sodium _sodium;

  @override
  Ed25519Signer generate() =>
      _SodiumSigner(_sodium, _sodium.crypto.sign.keyPair());

  @override
  Ed25519Signer fromSeed(Uint8List seed) {
    if (seed.length != ed25519SeedLength) {
      throw ArgumentError.value(
        seed.length,
        'seed',
        'must be $ed25519SeedLength bytes',
      );
    }
    final secureSeed = _sodium.secureCopy(seed);
    try {
      return _SodiumSigner(
        _sodium,
        _sodium.crypto.sign.seedKeyPair(secureSeed),
      );
    } finally {
      secureSeed.dispose();
    }
  }

  @override
  bool verify({
    required List<int> message,
    required List<int> signature,
    required List<int> publicKey,
  }) {
    if (signature.length != ed25519SignatureLength ||
        publicKey.length != ed25519PublicKeyLength) {
      return false;
    }
    return _sodium.crypto.sign.verifyDetached(
      message: Uint8List.fromList(message),
      signature: Uint8List.fromList(signature),
      publicKey: Uint8List.fromList(publicKey),
    );
  }
}

class _SodiumSigner implements Ed25519Signer {
  _SodiumSigner(this._sodium, this._keyPair);

  final Sodium _sodium;
  final KeyPair _keyPair;

  @override
  Uint8List get publicKey => Uint8List.fromList(_keyPair.publicKey);

  @override
  Uint8List sign(List<int> message) => _sodium.crypto.sign.detached(
    message: Uint8List.fromList(message),
    secretKey: _keyPair.secretKey,
  );

  @override
  void dispose() => _keyPair.secretKey.dispose();
}
