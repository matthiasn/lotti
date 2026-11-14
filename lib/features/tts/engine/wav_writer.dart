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

/// The 44-byte header of a 16-bit mono PCM WAV at [sampleRate] Hz holding
/// [dataBytes] of samples.
///
/// A `null` [dataBytes] is a stream whose length is not known yet: both
/// length fields say `0xFFFFFFFF`, as a streamed WAV's header does, for the
/// writer to fill in once it is whole.
Uint8List wavHeader(int sampleRate, {int? dataBytes}) {
  const unknown = 0xFFFFFFFF;
  final buffer = ByteData(_wavHeaderBytes);
  var offset = 0;

  void writeAscii(String tag) {
    for (final code in tag.codeUnits) {
      buffer.setUint8(offset++, code);
    }
  }

  void writeUint32(int value) {
    buffer.setUint32(offset, value, Endian.little);
    offset += 4;
  }

  void writeUint16(int value) {
    buffer.setUint16(offset, value, Endian.little);
    offset += 2;
  }

  writeAscii('RIFF');
  writeUint32(dataBytes == null ? unknown : 36 + dataBytes);
  writeAscii('WAVE');
  writeAscii('fmt ');
  writeUint32(16); // PCM fmt chunk size.
  writeUint16(1); // PCM format.
  writeUint16(_numChannels);
  writeUint32(sampleRate);
  writeUint32(sampleRate * _numChannels * (_bitsPerSample ~/ 8)); // Byte rate.
  writeUint16(_numChannels * (_bitsPerSample ~/ 8)); // Block align.
  writeUint16(_bitsPerSample);
  writeAscii('data');
  writeUint32(dataBytes ?? unknown);
  return buffer.buffer.asUint8List();
}

/// Encodes mono float PCM [samples] (each in `[-1, 1]`) as a 16-bit PCM WAV
/// byte buffer at [sampleRate] Hz. Samples are clamped before quantization.
Uint8List encodeWavBytes(List<double> samples, int sampleRate) {
  final dataSize = samples.length * 2;
  final bytes = Uint8List(_wavHeaderBytes + dataSize)
    ..setAll(0, wavHeader(sampleRate, dataBytes: dataSize));
  final buffer = ByteData.sublistView(bytes);
  for (var i = 0; i < samples.length; i++) {
    final sample = (samples[i].clamp(-1.0, 1.0) * 32767).round();
    buffer.setInt16(_wavHeaderBytes + i * 2, sample, Endian.little);
  }
  return bytes;
}

/// Encodes [samples] and writes the WAV to [path].
Future<void> writeWavFile(
  String path,
  List<double> samples,
  int sampleRate,
) async {
  await File(path).writeAsBytes(encodeWavBytes(samples, sampleRate));
}
