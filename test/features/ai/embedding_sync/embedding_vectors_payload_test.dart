import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/database/embedding_store.dart';
import 'package:lotti/features/ai/embedding_sync/embedding_vectors_payload.dart';

Float32List _ramp(double offset) => Float32List.fromList([
  for (var i = 0; i < kEmbeddingDimensions; i++) offset + i / 1000,
]);

Uint8List _json(Object value) => utf8.encode(jsonEncode(value));

void main() {
  test('round-trips a chunk set exactly, in order', () {
    final chunks = [_ramp(0), _ramp(-1.5), _ramp(42)];

    final decoded = decodeEmbeddingVectors(encodeEmbeddingVectors(chunks));

    expect(decoded, hasLength(3));
    for (var i = 0; i < chunks.length; i++) {
      expect(decoded[i], orderedEquals(chunks[i]));
    }
  });

  test('records the width and stores each value as little-endian float32', () {
    final json =
        jsonDecode(utf8.decode(encodeEmbeddingVectors([_ramp(1)])))
            as Map<String, dynamic>;
    final raw = base64Decode(
      (json['chunks'] as List<dynamic>).single as String,
    );

    expect(json['dims'], kEmbeddingDimensions);
    expect(raw, hasLength(kEmbeddingDimensions * 4));
    expect(
      ByteData.sublistView(raw).getFloat32(4, Endian.little),
      closeTo(1.001, 1e-6),
    );
  });

  group('refuses', () {
    final valid = base64Encode(Uint8List(kEmbeddingDimensions * 4));
    final cases = <String, Uint8List>{
      'non-JSON': utf8.encode('not json'),
      'a JSON array': _json([1, 2]),
      'another width': _json({
        'dims': 1024,
        'chunks': [valid],
      }),
      'no chunks': _json({'dims': kEmbeddingDimensions, 'chunks': <String>[]}),
      'a chunk that is not a string': _json({
        'dims': kEmbeddingDimensions,
        'chunks': [7],
      }),
      'a chunk that is not base64': _json({
        'dims': kEmbeddingDimensions,
        'chunks': ['%%%'],
      }),
      'a short chunk': _json({
        'dims': kEmbeddingDimensions,
        'chunks': [base64Encode(Uint8List(12))],
      }),
      'an infinite value': encodeEmbeddingVectors([
        Float32List(kEmbeddingDimensions)..[3] = double.infinity,
      ]),
    };
    for (final MapEntry(key: name, value: bytes) in cases.entries) {
      test(name, () {
        expect(
          () => decodeEmbeddingVectors(bytes),
          throwsA(isA<InvalidEmbeddingVectorsException>()),
        );
      });
    }
  });

  test('a refusal names its reason', () {
    expect(
      const InvalidEmbeddingVectorsException('dims 4').toString(),
      'InvalidEmbeddingVectorsException: dims 4',
    );
  });
}
