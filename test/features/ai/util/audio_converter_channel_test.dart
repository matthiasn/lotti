import 'dart:io';

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

    test('converts M4A to WAV through the native channel', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            expect(call.method, 'convertM4aToWav');
            final args = call.arguments as Map<dynamic, dynamic>;
            expect(args['inputPath'], '/tmp/input.m4a');
            expect(args['outputPath'], '/tmp/output.wav');
            return true;
          });

      final result = await AudioConverterChannel.convertM4aToWav(
        inputPath: '/tmp/input.m4a',
        outputPath: '/tmp/output.wav',
      );
      expect(result, isTrue);
    });

    final m4aFailureCases =
        <
          ({
            String description,
            Future<Object?> Function(MethodCall call) handler,
            bool expectsLog,
          })
        >[
          (
            description: 'returns false and logs M4A platform failures',
            handler: (_) async => throw PlatformException(
              code: 'CONVERSION_ERROR',
              message: 'Failed',
            ),
            expectsLog: true,
          ),
          (
            description: 'returns false when the M4A plugin is unavailable',
            handler: (_) async => throw MissingPluginException(),
            expectsLog: false,
          ),
          (
            description: 'returns false when M4A conversion returns null',
            handler: (_) async => null,
            expectsLog: false,
          ),
        ];
    for (final testCase in m4aFailureCases) {
      test(testCase.description, () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, testCase.handler);

        final result = await AudioConverterChannel.convertM4aToWav(
          inputPath: '/tmp/input.m4a',
          outputPath: '/tmp/output.wav',
        );

        expect(result, isFalse);
        if (testCase.expectsLog) {
          expect(fakeLogging.lastEvent, contains('M4A-to-WAV'));
        }
      });
    }

    test('temporary conversion uses native defaults and cleans up', () async {
      late String inputPath;
      late String outputPath;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            inputPath =
                (call.arguments as Map<dynamic, dynamic>)['inputPath']
                    as String;
            outputPath =
                (call.arguments as Map<dynamic, dynamic>)['outputPath']
                    as String;
            await File(outputPath).writeAsBytes([82, 73, 70, 70]);
            return true;
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
          return true;
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

      final wavBytes = await convertM4aBytesToTemporaryWav(
        Uint8List.fromList([1, 2, 3]),
        temporaryDirectory: directory,
        fileStem: 'failed',
        converter: ({required inputPath, required outputPath}) async {
          await File(outputPath).writeAsBytes([82, 73, 70, 70]);
          return false;
        },
      );

      expect(wavBytes, isNull);
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
          return true;
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

      final wavBytes = await convertM4aBytesToTemporaryWav(
        Uint8List.fromList([1, 2, 3]),
        temporaryDirectory: directory,
        fileStem: 'missing',
        converter: ({required inputPath, required outputPath}) async => true,
      );

      expect(wavBytes, isNull);
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
