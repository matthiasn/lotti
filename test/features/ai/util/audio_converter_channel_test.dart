import 'dart:io';

import 'package:audio_decoder/audio_decoder.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/logging_types.dart';
import 'package:lotti/features/ai/util/audio_converter_channel.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/domain_logging.dart';

import '../../../widget_test_utils.dart';

class _FakeDomainLogger extends Fake implements DomainLogger {
  String? lastEvent;

  @override
  void log(
    LogDomain domain,
    String message, {
    String? subDomain,
    InsightLevel level = InsightLevel.info,
  }) {
    lastEvent = message;
  }

  @override
  void error(
    LogDomain domain,
    Object error, {
    StackTrace? stackTrace,
    String? subDomain,
    String? message,
  }) {
    lastEvent = message ?? '$error';
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.matthiasn.lotti/audio_converter');
  const decoderChannel = MethodChannel('audio_decoder');
  late _FakeDomainLogger fakeLogging;

  group('AudioConverterChannel', () {
    setUp(() async {
      fakeLogging = _FakeDomainLogger();
      await setUpTestGetIt(
        additionalSetup: () {
          getIt
            ..unregister<DomainLogger>()
            ..registerSingleton<DomainLogger>(fakeLogging);
        },
      );
    });

    tearDown(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(decoderChannel, null);
      await tearDownTestGetIt();
    });

    test('returns true on successful conversion', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            expect(call.method, 'convertWavToM4a');
            final args = call.arguments as Map<dynamic, dynamic>;
            expect(args['inputPath'], '/tmp/input.wav');
            expect(args['outputPath'], '/tmp/output.m4a');
            return true;
          });

      final result = await AudioConverterChannel.convertWavToM4a(
        inputPath: '/tmp/input.wav',
        outputPath: '/tmp/output.m4a',
      );
      expect(result, isTrue);
    });

    test('converts M4A to WAV through the cross-platform decoder', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(decoderChannel, (call) async {
            expect(call.method, 'convertToWav');
            final args = call.arguments as Map<dynamic, dynamic>;
            expect(args['inputPath'], '/tmp/input.m4a');
            expect(args['outputPath'], '/tmp/output.wav');
            return '/tmp/output.wav';
          });

      await AudioConverterChannel.convertM4aToWav(
        inputPath: '/tmp/input.m4a',
        outputPath: '/tmp/output.wav',
      );
    });

    test('logs and rethrows cross-platform decoder failures', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            decoderChannel,
            (_) async => throw PlatformException(
              code: 'CONVERSION_ERROR',
              message: 'AAC decoder unavailable',
            ),
          );

      await expectLater(
        AudioConverterChannel.convertM4aToWav(
          inputPath: '/tmp/input.m4a',
          outputPath: '/tmp/output.wav',
        ),
        throwsA(
          isA<AudioConversionException>().having(
            (error) => error.message,
            'message',
            'AAC decoder unavailable',
          ),
        ),
      );
      expect(fakeLogging.lastEvent, contains('AAC decoder unavailable'));
    });

    test('temporary conversion uses native defaults and cleans up', () async {
      late String inputPath;
      late String outputPath;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(decoderChannel, (call) async {
            inputPath =
                (call.arguments as Map<dynamic, dynamic>)['inputPath']
                    as String;
            outputPath =
                (call.arguments as Map<dynamic, dynamic>)['outputPath']
                    as String;
            await File(outputPath).writeAsBytes([82, 73, 70, 70]);
            return outputPath;
          });

      final wavBytes = await convertM4aBytesToTemporaryWav(
        Uint8List.fromList([1, 2, 3]),
      );

      expect(wavBytes, [82, 73, 70, 70]);
      expect(File(inputPath).existsSync(), isFalse);
      expect(File(outputPath).existsSync(), isFalse);
    });

    test('temporary M4A conversion always removes scratch files', () async {
      final directory = await Directory.systemTemp.createTemp(
        'lotti_audio_converter_test_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final inputFile = File('${directory.path}/successful.m4a');
      final outputFile = File('${directory.path}/successful.wav');

      final wavBytes = await convertM4aBytesToTemporaryWav(
        Uint8List.fromList([1, 2, 3]),
        temporaryDirectory: directory,
        fileStem: 'successful',
        converter: ({required inputPath, required outputPath}) async {
          expect(File(inputPath).readAsBytesSync(), [1, 2, 3]);
          await File(outputPath).writeAsBytes([82, 73, 70, 70]);
        },
      );

      expect(wavBytes, [82, 73, 70, 70]);
      expect(inputFile.existsSync(), isFalse);
      expect(outputFile.existsSync(), isFalse);
    });

    test('temporary M4A conversion cleans up after failure', () async {
      final directory = await Directory.systemTemp.createTemp(
        'lotti_audio_converter_failure_test_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final inputFile = File('${directory.path}/failed.m4a');
      final outputFile = File('${directory.path}/failed.wav');

      await expectLater(
        convertM4aBytesToTemporaryWav(
          Uint8List.fromList([1, 2, 3]),
          temporaryDirectory: directory,
          fileStem: 'failed',
          converter: ({required inputPath, required outputPath}) async {
            await File(outputPath).writeAsBytes([82, 73, 70, 70]);
            throw AudioConversionException('decode failed');
          },
        ),
        throwsA(isA<AudioConversionException>()),
      );

      expect(inputFile.existsSync(), isFalse);
      expect(outputFile.existsSync(), isFalse);
    });

    test('scratch cleanup continues when one deletion fails', () async {
      final directory = await Directory.systemTemp.createTemp(
        'lotti_audio_converter_cleanup_test_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final attemptedPaths = <String>[];
      final inputFile = File('${directory.path}/cleanup.m4a');
      final outputFile = File('${directory.path}/cleanup.wav');

      final wavBytes = await convertM4aBytesToTemporaryWav(
        Uint8List.fromList([1, 2, 3]),
        temporaryDirectory: directory,
        fileStem: 'cleanup',
        converter: ({required inputPath, required outputPath}) async {
          await File(outputPath).writeAsBytes([82, 73, 70, 70]);
        },
        scratchFileDeleter: (file) {
          attemptedPaths.add(file.path);
          if (file.path.endsWith('.m4a')) {
            throw FileSystemException('simulated cleanup failure', file.path);
          }
          file.deleteSync();
        },
      );

      expect(wavBytes, [82, 73, 70, 70]);
      expect(attemptedPaths, [inputFile.path, outputFile.path]);
      expect(inputFile.existsSync(), isTrue);
      expect(outputFile.existsSync(), isFalse);
    });

    test('temporary M4A conversion rejects a missing output file', () async {
      final directory = await Directory.systemTemp.createTemp(
        'lotti_audio_converter_missing_output_test_',
      );
      addTearDown(() => directory.delete(recursive: true));

      await expectLater(
        convertM4aBytesToTemporaryWav(
          Uint8List.fromList([1, 2, 3]),
          temporaryDirectory: directory,
          fileStem: 'missing',
          converter: ({required inputPath, required outputPath}) async {},
        ),
        throwsA(
          isA<FileSystemException>().having(
            (error) => error.message,
            'message',
            contains('without an output file'),
          ),
        ),
      );

      expect(File('${directory.path}/missing.m4a').existsSync(), isFalse);
    });

    test('returns false on PlatformException and logs error', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            throw PlatformException(
              code: 'CONVERSION_ERROR',
              message: 'Failed',
            );
          });

      final result = await AudioConverterChannel.convertWavToM4a(
        inputPath: '/tmp/input.wav',
        outputPath: '/tmp/output.m4a',
      );
      expect(result, isFalse);
      expect(fakeLogging.lastEvent, contains('Native audio conversion failed'));
    });

    test('returns false on MissingPluginException', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            throw MissingPluginException();
          });

      final result = await AudioConverterChannel.convertWavToM4a(
        inputPath: '/tmp/input.wav',
        outputPath: '/tmp/output.m4a',
      );
      expect(result, isFalse);
    });

    test('returns false when native returns null', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            return null;
          });

      final result = await AudioConverterChannel.convertWavToM4a(
        inputPath: '/tmp/input.wav',
        outputPath: '/tmp/output.m4a',
      );
      expect(result, isFalse);
    });
  });
}
