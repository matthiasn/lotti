import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/speech/services/pcm_wav.dart';

extension _AnyWavParams on glados.Any {
  glados.Generator<int> get dataSize => intInRange(0, 1 << 20);
  glados.Generator<int> get sampleRate => intInRange(8000, 48001);
  glados.Generator<int> get channels => intInRange(1, 3);
  glados.Generator<int> get bitsPerSample => choose([8, 16, 32]);
}

void main() {
  test('encodes the canonical 44-byte PCM 16kHz mono header', () {
    final header = buildWavHeader(dataSize: 3200);

    expect(header, hasLength(44));
    expect(String.fromCharCodes(header.sublist(0, 4)), 'RIFF');
    expect(String.fromCharCodes(header.sublist(8, 12)), 'WAVE');
    expect(String.fromCharCodes(header.sublist(12, 16)), 'fmt ');
    expect(String.fromCharCodes(header.sublist(36, 40)), 'data');

    final view = ByteData.sublistView(header);
    expect(view.getUint32(4, Endian.little), 36 + 3200);
    expect(view.getUint32(16, Endian.little), 16);
    expect(view.getUint16(20, Endian.little), 1);
    expect(view.getUint16(22, Endian.little), 1);
    expect(view.getUint32(24, Endian.little), 16000);
    expect(view.getUint32(28, Endian.little), 32000);
    expect(view.getUint16(32, Endian.little), 2);
    expect(view.getUint16(34, Endian.little), 16);
    expect(view.getUint32(40, Endian.little), 3200);
    expect(isCanonicalPcmWavHeader(header, dataSize: 3200), isTrue);
  });

  test('rejects invalid or overflowing WAV format parameters', () {
    expect(() => buildWavHeader(dataSize: -1), throwsRangeError);
    expect(() => buildWavHeader(dataSize: 0xFFFFFFFF), throwsRangeError);
    expect(
      () => buildWavHeader(dataSize: 0, sampleRate: 0),
      throwsRangeError,
    );
    expect(
      () => buildWavHeader(dataSize: 0, channels: 0),
      throwsRangeError,
    );
    expect(
      () => buildWavHeader(dataSize: 0, bitsPerSample: 12),
      throwsArgumentError,
    );
  });

  test('detects a noncanonical or truncated WAV header', () {
    final damaged = buildWavHeader(dataSize: 4)..[0] = 0;

    expect(isCanonicalPcmWavHeader(damaged, dataSize: 4), isFalse);
    expect(
      isCanonicalPcmWavHeader(damaged.sublist(0, 40), dataSize: 4),
      isFalse,
    );
  });

  glados.Glados3<int, ({int channels, int sampleRate}), int>(
    glados.any.dataSize,
    glados.any.combine2(
      glados.any.sampleRate,
      glados.any.channels,
      (rate, chans) => (sampleRate: rate, channels: chans),
    ),
    glados.any.bitsPerSample,
    glados.ExploreConfig(numRuns: 120),
  ).test(
    'derived fields stay consistent for any format parameters',
    (dataSize, format, bits) {
      final header = buildWavHeader(
        dataSize: dataSize,
        sampleRate: format.sampleRate,
        channels: format.channels,
        bitsPerSample: bits,
      );
      final reason = 'dataSize=$dataSize format=$format bits=$bits';

      final view = ByteData.sublistView(header);
      final blockAlign = view.getUint16(32, Endian.little);
      expect(header, hasLength(44), reason: reason);
      expect(view.getUint32(4, Endian.little), 36 + dataSize, reason: reason);
      expect(view.getUint32(40, Endian.little), dataSize, reason: reason);
      expect(
        view.getUint32(24, Endian.little),
        format.sampleRate,
        reason: reason,
      );
      expect(
        view.getUint16(22, Endian.little),
        format.channels,
        reason: reason,
      );
      expect(view.getUint16(34, Endian.little), bits, reason: reason);
      expect(blockAlign, format.channels * bits ~/ 8, reason: reason);
      expect(
        view.getUint32(28, Endian.little),
        format.sampleRate * blockAlign,
        reason: reason,
      );
    },
    tags: 'glados',
  );
}
