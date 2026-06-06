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
