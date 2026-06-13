import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/tts/engine/wav_writer.dart';

void main() {
  group('encodeWavBytes', () {
    test('writes a 44-byte header plus 2 bytes per sample', () {
      final bytes = encodeWavBytes([0, 0, 0], 44100);
      expect(bytes.length, 44 + 3 * 2);
    });

    test('emits a valid RIFF/WAVE/fmt/data header for the sample rate', () {
      final bytes = encodeWavBytes([0, 0], 44100);
      final bd = ByteData.sublistView(bytes);

      String tag(int start) =>
          String.fromCharCodes(bytes.sublist(start, start + 4));
      expect(tag(0), 'RIFF');
      expect(bd.getUint32(4, Endian.little), 36 + 4); // chunk size
      expect(tag(8), 'WAVE');
      expect(tag(12), 'fmt ');
      expect(bd.getUint16(20, Endian.little), 1); // PCM
      expect(bd.getUint16(22, Endian.little), 1); // mono
      expect(bd.getUint32(24, Endian.little), 44100); // sample rate
      expect(bd.getUint32(28, Endian.little), 44100 * 2); // byte rate
      expect(bd.getUint16(32, Endian.little), 2); // block align
      expect(bd.getUint16(34, Endian.little), 16); // bits per sample
      expect(tag(36), 'data');
      expect(bd.getUint32(40, Endian.little), 4); // data size
    });

    test('quantizes and clamps samples to signed 16-bit', () {
      final bytes = encodeWavBytes([0, 1, -1, 2, -2], 16000);
      final bd = ByteData.sublistView(bytes);
      int sampleAt(int i) => bd.getInt16(44 + i * 2, Endian.little);

      expect(sampleAt(0), 0);
      expect(sampleAt(1), 32767); // 1.0
      expect(sampleAt(2), -32767); // -1.0
      expect(sampleAt(3), 32767); // clamped from 2.0
      expect(sampleAt(4), -32767); // clamped from -2.0
    });
  });
}
