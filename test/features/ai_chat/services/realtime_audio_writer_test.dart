import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai_chat/services/realtime_audio_writer.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

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
