import 'dart:math';
import 'dart:typed_data';

import 'package:lotti/features/provenance/crypto/domain_hash.dart';

/// Length of a commitment salt in bytes.
const int commitmentSaltLength = 32;

/// A fresh random salt from a cryptographically secure source.
Uint8List newCommitmentSalt([Random? random]) {
  final source = random ?? Random.secure();
  return Uint8List.fromList(
    List<int>.generate(commitmentSaltLength, (_) => source.nextInt(256)),
  );
}

/// A salted commitment to [plaintext]: `SHA-256(content tag ‖ 0x00 ‖ salt ‖
/// plaintext)`.
///
/// The envelope carries only this hash; the salt lives with the content and
/// is deleted with it. Without the salt the commitment cannot be matched
/// against a guess, which is what keeps a short deleted entry ("call mum")
/// from being confirmed by trying candidates.
Uint8List commitContent(List<int> plaintext, Uint8List salt) {
  if (salt.length != commitmentSaltLength) {
    throw ArgumentError.value(
      salt.length,
      'salt',
      'must be $commitmentSaltLength bytes',
    );
  }
  return domainHash(
    ProvenanceDomain.content,
    Uint8List(salt.length + plaintext.length)
      ..setRange(0, salt.length, salt)
      ..setRange(salt.length, salt.length + plaintext.length, plaintext),
  );
}

/// Whether [commitment] commits to [plaintext] under [salt].
bool contentMatchesCommitment({
  required List<int> plaintext,
  required Uint8List salt,
  required List<int> commitment,
}) {
  final expected = commitContent(plaintext, salt);
  if (expected.length != commitment.length) return false;
  var difference = 0;
  for (var i = 0; i < expected.length; i++) {
    difference |= expected[i] ^ commitment[i];
  }
  return difference == 0;
}
