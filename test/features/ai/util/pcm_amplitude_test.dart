import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/util/pcm_amplitude.dart';

void main() {
  group('computeDbfsFromPcm16', () {
    test('returns floor for empty input', () {
      expect(computeDbfsFromPcm16(Uint8List(0)), -80);
    });

    test('returns floor for silence (all zeros)', () {
      // 10 samples of silence
      final pcm = Uint8List(20);
      expect(computeDbfsFromPcm16(pcm), -80);
    });

    test('returns ~0 for max amplitude', () {
      // All samples at max positive value (32767)
      final byteData = ByteData(20);
      for (var i = 0; i < 10; i++) {
        byteData.setInt16(i * 2, 32767, Endian.little);
      }
      final pcm = byteData.buffer.asUint8List();

      final dbfs = computeDbfsFromPcm16(pcm);
      // 20 * log10(32767 / 32768) ≈ -0.000265 dB, effectively 0
      expect(dbfs, closeTo(0, 0.01));
    });

    test('returns expected dBFS for known sine wave', () {
      // Generate a full-cycle sine wave at half amplitude (16384)
      const numSamples = 1000;
      const amplitude = 16384;
      final byteData = ByteData(numSamples * 2);
      for (var i = 0; i < numSamples; i++) {
        final sample = (amplitude * sin(2 * pi * i / numSamples)).round();
        byteData.setInt16(i * 2, sample, Endian.little);
      }
      final pcm = byteData.buffer.asUint8List();

      final dbfs = computeDbfsFromPcm16(pcm);
      // RMS of sine = amplitude / sqrt(2)
      // dBFS = 20 * log10((16384 / sqrt(2)) / 32768) ≈ -9.03 dB
      expect(dbfs, closeTo(-9.03, 0.1));
    });

    test('handles odd byte count by ignoring trailing byte', () {
      // 5 bytes = 2 full samples + 1 trailing byte
      final byteData = ByteData(4)
        ..setInt16(0, 1000, Endian.little)
        ..setInt16(2, -1000, Endian.little);

      // Create 5-byte list (extra trailing byte)
      final pcm = Uint8List(5);
      for (var i = 0; i < 4; i++) {
        pcm[i] = byteData.buffer.asUint8List()[i];
      }
      pcm[4] = 0xFF; // trailing garbage byte

      final dbfs = computeDbfsFromPcm16(pcm);
      // Should process only 2 samples, ignore the trailing byte
      // RMS = sqrt((1000^2 + 1000^2) / 2) = 1000
      // dBFS = 20 * log10(1000 / 32768) ≈ -30.3 dB
      expect(dbfs, closeTo(-30.3, 0.1));
    });

    test('returns floor for single zero byte', () {
      // 1 byte = 0 full samples
      expect(computeDbfsFromPcm16(Uint8List(1)), -80);
    });

    test('respects custom floor value', () {
      expect(
        computeDbfsFromPcm16(Uint8List(0), floorDbfs: -60),
        -60,
      );
    });

    test('clamps result to floor for very quiet signal', () {
      // Very quiet signal: sample value of 1
      final byteData = ByteData(2)..setInt16(0, 1, Endian.little);
      final pcm = byteData.buffer.asUint8List();

      final dbfs = computeDbfsFromPcm16(pcm);
      // 20 * log10(1 / 32768) ≈ -90.3 dB, clamped to -80
      expect(dbfs, -80);
    });

    test('handles negative samples correctly', () {
      // All samples at min negative value (-32768)
      final byteData = ByteData(20);
      for (var i = 0; i < 10; i++) {
        byteData.setInt16(i * 2, -32768, Endian.little);
      }
      final pcm = byteData.buffer.asUint8List();

      final dbfs = computeDbfsFromPcm16(pcm);
      // RMS = 32768, dBFS = 20 * log10(32768 / 32768) = 0
      expect(dbfs, closeTo(0, 0.01));
    });
  });
}
