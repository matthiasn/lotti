import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/companion/animation/wav_pcm.dart';
import 'package:lotti/features/tts/engine/wav_writer.dart';

/// A RIFF/WAVE file from raw chunks, so the reader's edge cases can be built.
Uint8List _riff(List<(String, List<int>)> chunks) {
  final body = BytesBuilder()..add('WAVE'.codeUnits);
  for (final (id, data) in chunks) {
    final size = ByteData(4)..setUint32(0, data.length, Endian.little);
    body
      ..add(id.codeUnits)
      ..add(size.buffer.asUint8List())
      ..add(data);
    if (data.length.isOdd) body.addByte(0);
  }
  final bytes = body.toBytes();
  final size = ByteData(4)..setUint32(0, bytes.length, Endian.little);
  return (BytesBuilder()
        ..add('RIFF'.codeUnits)
        ..add(size.buffer.asUint8List())
        ..add(bytes))
      .toBytes();
}

List<int> _fmt({int format = 1, int channels = 1, int bits = 16}) {
  final d = ByteData(16)
    ..setUint16(0, format, Endian.little)
    ..setUint16(2, channels, Endian.little)
    ..setUint32(4, 16000, Endian.little)
    ..setUint32(8, 16000 * channels * bits ~/ 8, Endian.little)
    ..setUint16(12, channels * bits ~/ 8, Endian.little)
    ..setUint16(14, bits, Endian.little);
  return d.buffer.asUint8List();
}

List<int> _samples(List<int> values) {
  final d = ByteData(values.length * 2);
  for (var i = 0; i < values.length; i++) {
    d.setInt16(i * 2, values[i], Endian.little);
  }
  return d.buffer.asUint8List();
}

void main() {
  group('readPcm16', () {
    test('reads what the voices write: mono samples in -1..1 and the rate', () {
      final pcm = readPcm16(encodeWavBytes(const [0, 0.5, -0.5, 1], 24000));
      expect(pcm.sampleRate, 24000);
      expect(pcm.samples, hasLength(4));
      expect(pcm.samples[1], closeTo(0.5, 1e-3));
      expect(pcm.samples[2], closeTo(-0.5, 1e-3));
    });

    test('averages the channels of a stereo file', () {
      final pcm = readPcm16(
        _riff([
          ('fmt ', _fmt(channels: 2)),
          ('data', _samples([16384, 0, -16384, -16384])),
        ]),
      );
      expect(pcm.samples, [0.25, -0.5]);
    });

    test('skips other chunks, an odd-sized one with its pad byte', () {
      final pcm = readPcm16(
        _riff([
          ('LIST', [1, 2, 3]),
          ('fmt ', _fmt()),
          ('data', _samples([16384])),
        ]),
      );
      expect(pcm.samples, [0.5]);
    });

    test('rejects what is not 16-bit PCM WAV', () {
      expect(
        () => readPcm16(Uint8List.fromList([1, 2, 3])),
        throwsFormatException,
      );
      expect(
        () => readPcm16(_riff([('fmt ', _fmt(format: 3, bits: 32))])),
        throwsFormatException,
      );
      expect(
        () => readPcm16(
          _riff([
            ('data', _samples([1])),
            ('fmt ', _fmt()),
          ]),
        ),
        throwsFormatException,
      );
      expect(() => readPcm16(_riff([('fmt ', _fmt())])), throwsFormatException);
    });
  });
}
