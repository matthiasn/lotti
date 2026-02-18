import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/features/ai/util/audio_converter_channel.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';

class _FakeLoggingService extends LoggingService {
  String? lastEvent;

  @override
  void captureEvent(
    dynamic event, {
    required String domain,
    String? subDomain,
    InsightLevel level = InsightLevel.info,
    InsightType type = InsightType.log,
  }) {
    lastEvent = event.toString();
  }

  @override
  void captureException(
    dynamic exception, {
    required String domain,
    String? subDomain,
    dynamic stackTrace,
    InsightLevel level = InsightLevel.error,
    InsightType type = InsightType.exception,
  }) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.matthiasn.lotti/audio_converter');
  late _FakeLoggingService fakeLogging;

  group('AudioConverterChannel', () {
    setUp(() {
      fakeLogging = _FakeLoggingService();
      if (getIt.isRegistered<LoggingService>()) {
        getIt.unregister<LoggingService>();
      }
      getIt.registerSingleton<LoggingService>(fakeLogging);
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      if (getIt.isRegistered<LoggingService>()) {
        getIt.unregister<LoggingService>();
      }
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
