import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart'
    show
        Any,
        CombinableAny,
        ExploreConfig,
        Generator,
        Glados,
        IntAnys,
        ListAnys,
        any;
import 'package:lotti/features/ai/util/pcm_amplitude.dart';

class _GeneratedPcmScenario {
  const _GeneratedPcmScenario({
    required this.samples,
    required this.floorDbfsTenths,
    required this.trailingByte,
  });

  final List<int> samples;
  final int floorDbfsTenths;
  final int trailingByte;

  double get floorDbfs => floorDbfsTenths / 10;

  Uint8List get pcmBytes {
    final byteData = ByteData(samples.length * 2);
    for (final (index, sample) in samples.indexed) {
      byteData.setInt16(index * 2, sample, Endian.little);
    }
    return byteData.buffer.asUint8List();
  }

  Uint8List get pcmBytesWithTrailingByte {
    final base = pcmBytes;
    return Uint8List.fromList([...base, trailingByte]);
  }

  double get expectedDbfs {
    if (samples.isEmpty) return floorDbfs;

    final sumSquares = samples.fold<double>(
      0,
      (sum, sample) => sum + sample * sample,
    );
    final rms = sqrt(sumSquares / samples.length);
    if (rms == 0) return floorDbfs;

    final dbfs = 20 * log(rms / 32768) / ln10;
    return dbfs.clamp(floorDbfs, 0);
  }

  @override
  String toString() {
    return '_GeneratedPcmScenario('
        'samples: $samples, '
        'floorDbfs: $floorDbfs, '
        'trailingByte: $trailingByte)';
  }
}

extension _AnyPcmAmplitudeScenario on Any {
  Generator<_GeneratedPcmScenario> get pcmScenario => combine3(
    listWithLengthInRange(0, 64, intInRange(-32768, 32767)),
    intInRange(-1200, -1),
    intInRange(0, 255),
    (
      List<int> samples,
      int floorDbfsTenths,
      int trailingByte,
    ) => _GeneratedPcmScenario(
      samples: samples,
      floorDbfsTenths: floorDbfsTenths,
      trailingByte: trailingByte,
    ),
  );
}

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

    test('reports peak, RMS, and non-zero sample diagnostics', () {
      final byteData = ByteData(8)
        ..setInt16(0, 0, Endian.little)
        ..setInt16(2, 1000, Endian.little)
        ..setInt16(4, -3000, Endian.little)
        ..setInt16(6, 0, Endian.little);

      final stats = measurePcm16Amplitude(byteData.buffer.asUint8List());

      expect(stats.sampleCount, 4);
      expect(stats.nonZeroSampleCount, 2);
      expect(stats.peakSample, 3000);
      expect(stats.rmsSample, closeTo(sqrt(2500000), 0.001));
      expect(stats.isSilent, isFalse);
      expect(stats.dbfs, closeTo(-26.33, 0.01));
    });

    Glados(any.pcmScenario, ExploreConfig(numRuns: 200)).test(
      'matches the generated RMS dBFS model',
      (scenario) {
        final dbfs = computeDbfsFromPcm16(
          scenario.pcmBytes,
          floorDbfs: scenario.floorDbfs,
        );

        expect(
          dbfs,
          closeTo(scenario.expectedDbfs, 1e-9),
          reason: 'dBFS should match the RMS model for $scenario',
        );
        expect(dbfs, greaterThanOrEqualTo(scenario.floorDbfs));
        expect(dbfs, lessThanOrEqualTo(0));
      },
      tags: 'glados',
    );

    Glados(any.pcmScenario, ExploreConfig(numRuns: 200)).test(
      'ignores generated odd trailing bytes',
      (scenario) {
        expect(
          computeDbfsFromPcm16(
            scenario.pcmBytesWithTrailingByte,
            floorDbfs: scenario.floorDbfs,
          ),
          computeDbfsFromPcm16(
            scenario.pcmBytes,
            floorDbfs: scenario.floorDbfs,
          ),
        );
      },
      tags: 'glados',
    );
  });
}
