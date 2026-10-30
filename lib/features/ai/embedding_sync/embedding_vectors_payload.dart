import 'dart:convert';
import 'dart:typed_data';

import 'package:lotti/features/ai/database/embedding_store.dart';

/// Why [decodeEmbeddingVectors] refused a payload.
class InvalidEmbeddingVectorsException implements Exception {
  const InvalidEmbeddingVectorsException(this.reason);

  final String reason;

  @override
  String toString() => 'InvalidEmbeddingVectorsException: $reason';
}

/// Encodes an entry's complete chunk set as the attachment of
/// `SyncMessage.embeddingVectors`:
/// `{"dims": 768, "chunks": ["<base64 of little-endian float32[768]>", ...]}`.
///
/// `dims` stays in the payload so a later format (int8, another width) can
/// be told apart.
Uint8List encodeEmbeddingVectors(List<Float32List> chunks) {
  final json = {
    'dims': kEmbeddingDimensions,
    'chunks': [for (final chunk in chunks) base64Encode(_littleEndian(chunk))],
  };
  return utf8.encode(jsonEncode(json));
}

/// Decodes and validates a payload [encodeEmbeddingVectors] wrote.
///
/// Throws [InvalidEmbeddingVectorsException] unless `dims` is
/// [kEmbeddingDimensions], every chunk has exactly that many values, there is
/// at least one chunk, and every value is finite.
List<Float32List> decodeEmbeddingVectors(Uint8List bytes) {
  final Object? decoded;
  try {
    decoded = jsonDecode(utf8.decode(bytes));
  } on FormatException catch (e) {
    throw InvalidEmbeddingVectorsException('not JSON: ${e.message}');
  }
  if (decoded is! Map<String, dynamic>) {
    throw const InvalidEmbeddingVectorsException('not an object');
  }
  final dims = decoded['dims'];
  if (dims != kEmbeddingDimensions) {
    throw InvalidEmbeddingVectorsException('dims $dims');
  }
  final chunks = decoded['chunks'];
  if (chunks is! List<dynamic> || chunks.isEmpty) {
    throw const InvalidEmbeddingVectorsException('no chunks');
  }
  return [
    for (final chunk in chunks) _decodeChunk(chunk),
  ];
}

Float32List _decodeChunk(Object? chunk) {
  if (chunk is! String) {
    throw const InvalidEmbeddingVectorsException('chunk is not a string');
  }
  final Uint8List raw;
  try {
    raw = base64Decode(chunk);
  } on FormatException {
    throw const InvalidEmbeddingVectorsException('chunk is not base64');
  }
  if (raw.length != kEmbeddingDimensions * 4) {
    throw InvalidEmbeddingVectorsException('chunk of ${raw.length} bytes');
  }
  final data = ByteData.sublistView(raw);
  final vector = Float32List(kEmbeddingDimensions);
  for (var i = 0; i < kEmbeddingDimensions; i++) {
    final value = data.getFloat32(i * 4, Endian.little);
    if (!value.isFinite) {
      throw const InvalidEmbeddingVectorsException('non-finite value');
    }
    vector[i] = value;
  }
  return vector;
}

Uint8List _littleEndian(Float32List vector) {
  final data = ByteData(vector.length * 4);
  for (var i = 0; i < vector.length; i++) {
    data.setFloat32(i * 4, vector[i], Endian.little);
  }
  return data.buffer.asUint8List();
}
