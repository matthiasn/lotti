import 'dart:typed_data';

/// Builds a canonical WAV header for a PCM payload of [dataSize] bytes.
///
/// Defaults match the shared speech capture format: signed 16-bit
/// little-endian PCM at 16 kHz, mono.
Uint8List buildWavHeader({
  required int dataSize,
  int sampleRate = 16000,
  int channels = 1,
  int bitsPerSample = 16,
}) {
  if (dataSize < 0 || dataSize > 0xFFFFFFFF - 36) {
    throw RangeError.range(dataSize, 0, 0xFFFFFFFF - 36, 'dataSize');
  }
  if (sampleRate <= 0 || sampleRate > 0xFFFFFFFF) {
    throw RangeError.range(sampleRate, 1, 0xFFFFFFFF, 'sampleRate');
  }
  if (channels <= 0 || channels > 0xFFFF) {
    throw RangeError.range(channels, 1, 0xFFFF, 'channels');
  }
  if (bitsPerSample <= 0 || bitsPerSample > 0xFFFF || bitsPerSample % 8 != 0) {
    throw ArgumentError.value(
      bitsPerSample,
      'bitsPerSample',
      'Must be a positive whole-byte sample width no larger than 65535',
    );
  }
  final byteRate = sampleRate * channels * bitsPerSample ~/ 8;
  final blockAlign = channels * bitsPerSample ~/ 8;
  if (blockAlign > 0xFFFF) {
    throw RangeError.range(blockAlign, 1, 0xFFFF, 'blockAlign');
  }
  if (byteRate > 0xFFFFFFFF) {
    throw RangeError.range(byteRate, 1, 0xFFFFFFFF, 'byteRate');
  }

  final header = ByteData(44)
    ..setUint32(0, 0x52494646)
    ..setUint32(4, 36 + dataSize, Endian.little)
    ..setUint32(8, 0x57415645)
    ..setUint32(12, 0x666D7420)
    ..setUint32(16, 16, Endian.little)
    ..setUint16(20, 1, Endian.little)
    ..setUint16(22, channels, Endian.little)
    ..setUint32(24, sampleRate, Endian.little)
    ..setUint32(28, byteRate, Endian.little)
    ..setUint16(32, blockAlign, Endian.little)
    ..setUint16(34, bitsPerSample, Endian.little)
    ..setUint32(36, 0x64617461)
    ..setUint32(40, dataSize, Endian.little);

  return header.buffer.asUint8List();
}

/// Whether [header] exactly matches the canonical PCM WAV header for the
/// supplied format and payload size.
bool isCanonicalPcmWavHeader(
  List<int> header, {
  required int dataSize,
  int sampleRate = 16000,
  int channels = 1,
  int bitsPerSample = 16,
}) {
  if (header.length != 44) return false;
  Uint8List expected;
  try {
    expected = buildWavHeader(
      dataSize: dataSize,
      sampleRate: sampleRate,
      channels: channels,
      bitsPerSample: bitsPerSample,
    );
  } catch (_) {
    return false;
  }
  for (var index = 0; index < expected.length; index++) {
    if (header[index] != expected[index]) return false;
  }
  return true;
}
