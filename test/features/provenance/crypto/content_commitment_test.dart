import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/provenance/crypto/content_commitment.dart';
import 'package:lotti/features/provenance/crypto/hex.dart';

void main() {
  final salt = Uint8List.fromList(List<int>.generate(32, (i) => i));

  test('matches the independent reference', () {
    // SHA-256("lotti/content/v1" || 0x00 || salt || "call mum"), from
    // Python's hashlib.
    expect(
      toHex(commitContent(utf8.encode('call mum'), salt)),
      'fbc440ce535ca1fff8f24ab84c7e951cbe4f9ab7e1e56d4ef8e8ba32b78db970',
    );
  });

  test('rejects a salt of the wrong length', () {
    expect(
      () => commitContent([1], Uint8List(16)),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('a new salt is the right length and differs between calls', () {
    final random = Random(1);
    final first = newCommitmentSalt(random);
    final second = newCommitmentSalt(random);
    expect(first, hasLength(commitmentSaltLength));
    expect(first, isNot(second));
  });

  test('without a source, a salt comes from the secure generator', () {
    expect(newCommitmentSalt(), hasLength(commitmentSaltLength));
  });

  test('contentMatchesCommitment accepts the content and nothing else', () {
    final commitment = commitContent(utf8.encode('call mum'), salt);
    expect(
      contentMatchesCommitment(
        plaintext: utf8.encode('call mum'),
        salt: salt,
        commitment: commitment,
      ),
      isTrue,
    );
    expect(
      contentMatchesCommitment(
        plaintext: utf8.encode('call dad'),
        salt: salt,
        commitment: commitment,
      ),
      isFalse,
    );
    expect(
      contentMatchesCommitment(
        plaintext: utf8.encode('call mum'),
        salt: salt,
        commitment: commitment.sublist(1),
      ),
      isFalse,
    );
  });

  glados.Glados2<String, int>(
    glados.any.letterOrDigits,
    glados.any.intInRange(0, 1 << 31),
    glados.ExploreConfig(numRuns: 200),
  ).test(
    'the same content under another salt gives an unrelated commitment',
    (text, seed) {
      final random = Random(seed);
      final plaintext = utf8.encode(text);
      final a = newCommitmentSalt(random);
      final b = newCommitmentSalt(random);
      expect(commitContent(plaintext, a), isNot(commitContent(plaintext, b)));
      expect(
        contentMatchesCommitment(
          plaintext: plaintext,
          salt: b,
          commitment: commitContent(plaintext, a),
        ),
        isFalse,
      );
    },
    tags: 'glados',
  );
}
