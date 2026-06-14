// WAV encoding for the Supertonic TTS engine.
//
// Ported from Supertone's open-source Supertonic Flutter example
// (github.com/supertone-inc/supertonic — MIT-licensed sample code). Split into
// a pure [encodeWavBytes] (testable without a filesystem) plus a thin file
// writer.

import 'dart:io';
import 'dart:typed_data';

const int _wavHeaderBytes = 44;
const int _bitsPerSample = 16;
const int _numChannels = 1; // Supertonic emits mono.

/// Encodes mono float PCM [samples] (each in `[-1, 1]`) as a 16-bit PCM WAV
/// byte buffer at [sampleRate] Hz. Samples are clamped before quantization.
Uint8List encodeWavBytes(List<double> samples, int sampleRate) {
  final dataSize = samples.length * 2;
  final buffer = ByteData(_wavHeaderBytes + dataSize);
  var offset = 0;

  void writeAscii(String tag) {
    for (final code in tag.codeUnits) {
      buffer.setUint8(offset++, code);
    }
  }

  // RIFF header.
  writeAscii('RIFF');
  buffer.setUint32(offset, 36 + dataSize, Endian.little);
  offset += 4;
  writeAscii('WAVE');

  // fmt chunk.
  writeAscii('fmt ');
  buffer.setUint32(offset, 16, Endian.little); // PCM fmt chunk size.
  offset += 4;
  buffer.setUint16(offset, 1, Endian.little); // PCM format.
  offset += 2;
  buffer.setUint16(offset, _numChannels, Endian.little);
  offset += 2;
  buffer.setUint32(offset, sampleRate, Endian.little);
  offset += 4;
  buffer.setUint32(
    offset,
    sampleRate * _numChannels * (_bitsPerSample ~/ 8),
    Endian.little,
  ); // Byte rate.
  offset += 4;
  buffer.setUint16(
    offset,
    _numChannels * (_bitsPerSample ~/ 8),
    Endian.little,
  ); // Block align.
  offset += 2;
  buffer.setUint16(offset, _bitsPerSample, Endian.little);
  offset += 2;

  // data chunk.
  writeAscii('data');
  buffer.setUint32(offset, dataSize, Endian.little);
  offset += 4;

  for (var i = 0; i < samples.length; i++) {
    final sample = (samples[i].clamp(-1.0, 1.0) * 32767).round();
    buffer.setInt16(offset + i * 2, sample, Endian.little);
  }

  return buffer.buffer.asUint8List();
}

/// Encodes [samples] and writes the WAV to [path].
Future<void> writeWavFile(
  String path,
  List<double> samples,
  int sampleRate,
) async {
  await File(path).writeAsBytes(encodeWavBytes(samples, sampleRate));
}
