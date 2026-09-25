import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/provenance/crypto/ed25519.dart';
import 'package:lotti/features/provenance/crypto/hex.dart';

/// RFC 8032 section 7.1, tests 1 to 3. Inputs from the RFC; the public keys
/// and signatures were checked against Python's `cryptography` package.
const List<({String seed, String message, String publicKey, String signature})>
_vectors = [
  (
    seed: '9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60',
    message: '',
    publicKey:
        'd75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a',
    signature:
        'e5564300c360ac729086e2cc806e828a84877f1eb8e5d974d873e0652249015'
        '55fb8821590a33bacc61e39701cf9b46bd25bf5f0595bbe24655141438e7a100b',
  ),
  (
    seed: '4ccd089b28ff96da9db6c346ec114e0f5b8a319f35aba624da8cf6ed4fb8a6fb',
    message: '72',
    publicKey:
        '3d4017c3e843895a92b70aa74d1b7ebc9c982ccf2ec4968cc0cd55f12af4660c',
    signature:
        '92a009a9f0d4cab8720e820b5f642540a2b27b5416503f8fb3762223ebdb69da'
        '085ac1e43e15996e458f3613d0f11d8c387b2eaeb4302aeeb00d291612bb0c00',
  ),
  (
    seed: 'c5aa8df43f9f837bedb7442f31dcb7b166d38535076f094b85ce3a2e0b4458f7',
    message: 'af82',
    publicKey:
        'fc51cd8e6218a1a38da47ed00230f0580816ed13ba3303ac5deb911548908025',
    signature:
        '6291d657deec24024827e69c3abe01a30ce548a284743a445e3680d7db5ac3ac'
        '18ff9b538d16f290ae67f760984dc6594a7c15e9716ed28dc027beceea1ec40a',
  ),
];

void main() {
  late SodiumEd25519 ed25519;

  setUpAll(() async {
    ed25519 = await SodiumEd25519.bundled();
  });

  for (final (index, vector) in _vectors.indexed) {
    test('RFC 8032 test ${index + 1}: key, signature and verification', () {
      final signer = ed25519.fromSeed(fromHex(vector.seed));
      addTearDown(signer.dispose);
      final message = fromHex(vector.message);

      expect(toHex(signer.publicKey), vector.publicKey);
      expect(toHex(signer.sign(message)), vector.signature);
      expect(
        ed25519.verify(
          message: message,
          signature: fromHex(vector.signature),
          publicKey: fromHex(vector.publicKey),
        ),
        isTrue,
      );
    });
  }

  test('a signature does not verify under another key', () {
    final signer = ed25519.generate();
    final other = ed25519.generate();
    addTearDown(signer.dispose);
    addTearDown(other.dispose);
    final message = Uint8List.fromList([1, 2, 3]);

    expect(
      ed25519.verify(
        message: message,
        signature: signer.sign(message),
        publicKey: other.publicKey,
      ),
      isFalse,
    );
  });

  test('malformed signatures and keys are invalid, not errors', () {
    final signer = ed25519.generate();
    addTearDown(signer.dispose);
    final signature = signer.sign([1]);

    expect(
      ed25519.verify(
        message: [1],
        signature: signature.sublist(1),
        publicKey: signer.publicKey,
      ),
      isFalse,
    );
    expect(
      ed25519.verify(
        message: [1],
        signature: signature,
        publicKey: signer.publicKey.sublist(1),
      ),
      isFalse,
    );
  });

  test('a seed of the wrong length is rejected', () {
    expect(
      () => ed25519.fromSeed(Uint8List(16)),
      throwsA(isA<ArgumentError>()),
    );
  });

  glados.Glados2<List<int>, int>(
    glados.any.listWithLengthInRange(1, 64, glados.any.intInRange(0, 256)),
    glados.any.intInRange(0, 1 << 16),
    glados.ExploreConfig(numRuns: 150),
  ).test(
    'flipping any bit of the message breaks the signature',
    (message, bitSeed) {
      final signer = ed25519.generate();
      final signature = signer.sign(message);
      final bit = bitSeed % (message.length * 8);
      final tampered = [...message];
      tampered[bit ~/ 8] ^= 1 << (bit % 8);

      expect(
        ed25519.verify(
          message: message,
          signature: signature,
          publicKey: signer.publicKey,
        ),
        isTrue,
      );
      expect(
        ed25519.verify(
          message: tampered,
          signature: signature,
          publicKey: signer.publicKey,
        ),
        isFalse,
      );
      signer.dispose();
    },
    tags: 'glados',
  );
}
