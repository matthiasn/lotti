import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/ai_chat/services/realtime_audio_writer.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

extension _AnyWavParams on glados.Any {
  glados.Generator<int> get dataSize => intInRange(0, 1 << 20);
  glados.Generator<int> get sampleRate => intInRange(8000, 48001);
  glados.Generator<int> get channels => intInRange(1, 3);
  glados.Generator<int> get bitsPerSample => choose([8, 16, 32]);
}

/// Recording fake for the injected WAV→M4A converter.
class _RecordingConverter {
  _RecordingConverter({this.result = false, this.error});

  final bool result;
  final Exception? error;
  final calls = <({String inputPath, String outputPath})>[];

  Future<bool> call({
    required String inputPath,
    required String outputPath,
  }) async {
    calls.add((inputPath: inputPath, outputPath: outputPath));
    final e = error;
    if (e != null) throw e;
    return result;
  }
}

void main() {
  late MockDomainLogger logger;
  late Directory tempDir;
  late Directory outputDir;

  setUp(() async {
    logger = MockDomainLogger();
    if (getIt.isRegistered<DomainLogger>()) {
      getIt.unregister<DomainLogger>();
    }
    getIt.registerSingleton<DomainLogger>(logger);
    tempDir = await Directory.systemTemp.createTemp('rt_writer_tmp_');
    outputDir = await Directory.systemTemp.createTemp('rt_writer_out_');
  });

  tearDown(() async {
    if (getIt.isRegistered<DomainLogger>()) {
      getIt.unregister<DomainLogger>();
    }
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
    if (outputDir.existsSync()) await outputDir.delete(recursive: true);
  });

  final pcm = Uint8List.fromList(List.generate(3200, (i) => i % 256));

  group('buildWavHeader', () {
    test('encodes the canonical 44-byte PCM 16kHz mono header', () {
      final header = buildWavHeader(dataSize: 3200);

      expect(header, hasLength(44));
      expect(String.fromCharCodes(header.sublist(0, 4)), 'RIFF');
      expect(String.fromCharCodes(header.sublist(8, 12)), 'WAVE');
      expect(String.fromCharCodes(header.sublist(12, 16)), 'fmt ');
      expect(String.fromCharCodes(header.sublist(36, 40)), 'data');

      final view = ByteData.sublistView(header);
      expect(view.getUint32(4, Endian.little), 36 + 3200); // RIFF size
      expect(view.getUint32(16, Endian.little), 16); // fmt chunk size
      expect(view.getUint16(20, Endian.little), 1); // PCM format
      expect(view.getUint16(22, Endian.little), 1); // mono
      expect(view.getUint32(24, Endian.little), 16000); // sample rate
      expect(view.getUint32(28, Endian.little), 32000); // byte rate
      expect(view.getUint16(32, Endian.little), 2); // block align
      expect(view.getUint16(34, Endian.little), 16); // bits per sample
      expect(view.getUint32(40, Endian.little), 3200); // data size
    });

    glados.Glados3<int, ({int channels, int sampleRate}), int>(
      glados.any.dataSize,
      glados.any.combine2(
        glados.any.sampleRate,
        glados.any.channels,
        (int rate, int chans) => (sampleRate: rate, channels: chans),
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
        expect(header, hasLength(44), reason: reason);
        expect(
          view.getUint32(4, Endian.little),
          36 + dataSize,
          reason: reason,
        );
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
        // byteRate = sampleRate * blockAlign; blockAlign = channels * bits/8.
        final blockAlign = view.getUint16(32, Endian.little);
        expect(blockAlign, format.channels * bits ~/ 8, reason: reason);
        expect(
          view.getUint32(28, Endian.little),
          format.sampleRate * blockAlign,
          reason: reason,
        );
      },
      tags: 'glados',
    );
  });

  group('RealtimeAudioWriter.saveAudio', () {
    test('returns null for empty PCM without touching the converter', () async {
      final converter = _RecordingConverter();
      final writer = RealtimeAudioWriter(
        convertWavToM4a: converter.call,
        tempDirectory: tempDir,
      );

      final result = await writer.saveAudio(
        pcm: Uint8List(0),
        outputPath: '${outputDir.path}/capture',
      );

      expect(result, isNull);
      expect(converter.calls, isEmpty);
      expect(tempDir.listSync(), isEmpty);
    });

    test(
      'returns the m4a path and deletes the temp WAV on conversion success',
      () async {
        final converter = _RecordingConverter(result: true);
        final writer = RealtimeAudioWriter(
          convertWavToM4a: converter.call,
          tempDirectory: tempDir,
        );

        final result = await writer.saveAudio(
          pcm: pcm,
          outputPath: '${outputDir.path}/capture',
        );

        expect(result, '${outputDir.path}/capture.m4a');
        expect(converter.calls, hasLength(1));
        expect(converter.calls.single.inputPath, startsWith(tempDir.path));
        expect(converter.calls.single.inputPath, endsWith('.wav'));
        expect(
          converter.calls.single.outputPath,
          '${outputDir.path}/capture.m4a',
        );
        // Temp WAV cleaned up after the successful conversion.
        expect(File(converter.calls.single.inputPath).existsSync(), isFalse);
      },
    );

    test(
      'does not double-append .m4a when outputPath already has it',
      () async {
        final converter = _RecordingConverter(result: true);
        final writer = RealtimeAudioWriter(
          convertWavToM4a: converter.call,
          tempDirectory: tempDir,
        );

        final result = await writer.saveAudio(
          pcm: pcm,
          outputPath: '${outputDir.path}/capture.m4a',
        );

        expect(result, '${outputDir.path}/capture.m4a');
      },
    );

    test(
      'falls back to a WAV file containing header plus PCM when conversion '
      'is unavailable',
      () async {
        final converter = _RecordingConverter();
        final writer = RealtimeAudioWriter(
          convertWavToM4a: converter.call,
          tempDirectory: tempDir,
        );

        final result = await writer.saveAudio(
          pcm: pcm,
          outputPath: '${outputDir.path}/capture',
        );

        expect(result, '${outputDir.path}/capture.wav');
        final written = File(result!).readAsBytesSync();
        expect(written, hasLength(44 + pcm.length));
        expect(written.sublist(0, 44), buildWavHeader(dataSize: pcm.length));
        expect(written.sublist(44), pcm);
        // Temp WAV was moved, not copied.
        expect(File(converter.calls.single.inputPath).existsSync(), isFalse);
      },
    );

    test('keeps the temp WAV and logs when the converter throws', () async {
      final converter = _RecordingConverter(
        error: Exception('native crash'),
      );
      final writer = RealtimeAudioWriter(
        convertWavToM4a: converter.call,
        tempDirectory: tempDir,
      );

      final result = await writer.saveAudio(
        pcm: pcm,
        outputPath: '${outputDir.path}/capture',
      );

      // The already-written temp WAV survives so the recording is not lost.
      expect(result, converter.calls.single.inputPath);
      expect(File(result!).existsSync(), isTrue);
      verify(
        () => logger.error(
          LogDomain.speech,
          any<Object>(),
          subDomain: 'saveAudio',
        ),
      ).called(1);
    });

    test('keeps the temp WAV when moving it to the output fails', () async {
      final converter = _RecordingConverter();
      final writer = RealtimeAudioWriter(
        convertWavToM4a: converter.call,
        tempDirectory: tempDir,
      );

      final result = await writer.saveAudio(
        pcm: pcm,
        outputPath: '${outputDir.path}/missing/nested/capture',
      );

      expect(result, converter.calls.single.inputPath);
      expect(File(result!).existsSync(), isTrue);
      verify(
        () => logger.error(
          LogDomain.speech,
          any<Object>(),
          subDomain: 'saveAudio',
        ),
      ).called(1);
    });

    test(
      'returns null and logs when even the temp WAV cannot be written',
      () async {
        final converter = _RecordingConverter(result: true);
        final writer = RealtimeAudioWriter(
          convertWavToM4a: converter.call,
          tempDirectory: Directory('${tempDir.path}/does_not_exist'),
        );

        final result = await writer.saveAudio(
          pcm: pcm,
          outputPath: '${outputDir.path}/capture',
        );

        expect(result, isNull);
        expect(converter.calls, isEmpty);
        verify(
          () => logger.error(
            LogDomain.speech,
            any<Object>(),
            subDomain: 'saveAudio',
          ),
        ).called(1);
      },
    );
  });
}
