import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/provenance/crypto/canonical_json.dart';
import 'package:lotti/features/provenance/crypto/ed25519.dart';
import 'package:lotti/features/provenance/crypto/hex.dart';
import 'package:lotti/features/provenance/envelope_crypto.dart';
import 'package:lotti/features/provenance/model/envelope.dart';

import 'envelope_fixtures.dart';

/// A generated envelope's variable parts.
typedef _Variant = ({
  int seq,
  EnvelopeKind kind,
  AuthorType authorType,
  List<MapEntry<String, int>> clock,
  List<MapEntry<String, int>> refs,
});

extension on glados.Any {
  glados.Generator<_Variant> get envelopeVariant => combine5(
    intInRange(0, 1 << 20),
    choose(EnvelopeKind.values),
    choose(AuthorType.values),
    list(mapEntry(nonEmptyLetterOrDigits, intInRange(0, 1 << 30))),
    list(mapEntry(letterOrDigits, int32)),
    (seq, kind, authorType, clock, refs) => (
      seq: seq,
      kind: kind,
      authorType: authorType,
      clock: clock,
      refs: refs,
    ),
  );
}

void main() {
  late SodiumEd25519 ed25519;
  late Ed25519Signer signer;

  setUpAll(() async {
    ed25519 = await SodiumEd25519.bundled();
    signer = ed25519.fromSeed(fromHex(EnvelopeReference.seed));
  });

  tearDownAll(() => signer.dispose());

  Envelope signedReference() => signEnvelope(referenceEnvelope(), signer);

  group('reproduces the independent reference byte for byte', () {
    test('device id', () {
      expect(toHex(signer.publicKey), EnvelopeReference.publicKey);
      expect(deviceIdFor(signer.publicKey), EnvelopeReference.deviceId);
    });

    test('a device id needs a whole public key', () {
      expect(() => deviceIdFor(Uint8List(31)), throwsA(isA<ArgumentError>()));
    });

    test('signature, wire bytes and hash', () {
      final signed = signedReference();

      expect(signed.signature, EnvelopeReference.signature);
      expect(utf8.decode(encodeEnvelope(signed)), EnvelopeReference.wireJson);
      expect(envelopeHash(signed), EnvelopeReference.hash);
    });

    test('the signing bytes are the signature domain framing', () {
      expect(
        envelopeSigningBytes(referenceEnvelope()),
        [
          ...ascii.encode('lotti/envelope-signature/v1'),
          0,
          ...utf8.encode(EnvelopeReference.signingJson),
        ],
      );
    });
  });

  group('signEnvelope', () {
    test('refuses an envelope naming another device', () {
      final other = ed25519.generate();
      addTearDown(other.dispose);
      expect(
        () => signEnvelope(referenceEnvelope(), other),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('refuses an envelope that is already signed', () {
      expect(
        () => signEnvelope(signedReference(), signer),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('verifyEnvelopeSignature', () {
    test('accepts the signer, and only for the key its device id names', () {
      final signed = signedReference();
      final other = ed25519.generate();
      addTearDown(other.dispose);

      expect(
        verifyEnvelopeSignature(signed, signer.publicKey, ed25519),
        isTrue,
      );
      expect(
        verifyEnvelopeSignature(signed, other.publicKey, ed25519),
        isFalse,
      );
    });

    test('an unsigned envelope does not verify', () {
      expect(
        verifyEnvelopeSignature(referenceEnvelope(), signer.publicKey, ed25519),
        isFalse,
      );
    });

    test('a field changed after signing breaks the signature', () {
      final signed = signedReference();
      final moved = referenceEnvelope(seq: 2, signature: signed.signature);
      expect(
        verifyEnvelopeSignature(moved, signer.publicKey, ed25519),
        isFalse,
      );
    });

    test(
      'changing the inputs after signing changes nothing that was signed',
      () {
        final refs = <String>[...EnvelopeReference.causalRefs];
        final clock = <String, int>{'host-a': 3, 'host-b': 1};
        final nested = <String, Object?>{
          'targets': <Object?>['a'],
        };
        final signed = signEnvelope(
          referenceEnvelope(
            causalRefs: refs,
            vectorClock: clock,
            refs: {'supersedes': EnvelopeReference.prev, 'nested': nested},
          ),
          signer,
        );
        final bytes = encodeEnvelope(signed);

        refs.add('f' * 64);
        clock['host-a'] = 99;
        (nested['targets']! as List<Object?>).add('b');
        nested['extra'] = 1;

        expect(encodeEnvelope(signed), bytes);
        expect(
          verifyEnvelopeSignature(signed, signer.publicKey, ed25519),
          isTrue,
        );
        expect(() => signed.causalRefs.add('x'), throwsUnsupportedError);
        expect(() => signed.refs['x'] = 1, throwsUnsupportedError);
      },
    );

    test("another device's signature cannot be re-attributed", () {
      final other = ed25519.generate();
      addTearDown(other.dispose);
      final otherId = deviceIdFor(other.publicKey);
      final signedByOther = signEnvelope(
        referenceEnvelope(deviceId: otherId),
        other,
      );
      final relabelled = referenceEnvelope(signature: signedByOther.signature);

      expect(
        verifyEnvelopeSignature(relabelled, signer.publicKey, ed25519),
        isFalse,
      );
    });
  });

  group('decodeEnvelope', () {
    test('decodes the canonical wire bytes', () {
      expect(
        decodeEnvelope(utf8.encode(EnvelopeReference.wireJson)),
        signedReference(),
      );
    });

    test('rejects a re-spelled encoding of the same envelope', () {
      final pretty = const JsonEncoder.withIndent(' ').convert(
        jsonDecode(EnvelopeReference.wireJson),
      );
      expect(
        () => decodeEnvelope(utf8.encode(pretty)),
        throwsA(isA<CanonicalJsonException>()),
      );
    });
  });

  // Spec §13.2: any single-byte mutation of any envelope is detected. A
  // mutated wire form either no longer decodes, or decodes to an envelope
  // whose signature no longer verifies.
  glados.Glados2<int, int>(
    glados.any.intInRange(0, 1 << 20),
    glados.any.intInRange(1, 256),
    glados.ExploreConfig(numRuns: 400),
  ).test(
    'any single-byte mutation of a signed envelope is detected',
    (positionSeed, delta) {
      final wire = encodeEnvelope(signedReference());
      final position = positionSeed % wire.length;
      final mutated = Uint8List.fromList(wire)
        ..[position] = (wire[position] + delta) % 256;

      Envelope? decoded;
      try {
        decoded = decodeEnvelope(mutated);
      } on Object {
        decoded = null;
      }
      if (decoded != null) {
        expect(
          verifyEnvelopeSignature(decoded, signer.publicKey, ed25519),
          isFalse,
          reason: 'byte $position +$delta decoded and still verified',
        );
      }
    },
    tags: 'glados',
  );

  glados.Glados<_Variant>(
    glados.any.envelopeVariant,
    glados.ExploreConfig(numRuns: 200),
  ).test(
    'a signed envelope round-trips through its wire form and verifies',
    (variant) {
      final envelope = referenceEnvelope(
        kind: variant.kind,
        seq: variant.seq,
        prev: variant.seq == 0 ? null : EnvelopeReference.prev,
        vectorClock: Map.fromEntries(variant.clock),
        author: EnvelopeAuthor(
          type: variant.authorType,
          id: variant.authorType.wireName,
        ),
        refs: Map<String, Object?>.fromEntries(variant.refs),
      );
      final signed = signEnvelope(envelope, signer);
      final decoded = decodeEnvelope(encodeEnvelope(signed));

      expect(decoded, signed);
      expect(
        verifyEnvelopeSignature(decoded, signer.publicKey, ed25519),
        isTrue,
      );
      expect(envelopeHash(decoded), envelopeHash(signed));
    },
    tags: 'glados',
  );
}
